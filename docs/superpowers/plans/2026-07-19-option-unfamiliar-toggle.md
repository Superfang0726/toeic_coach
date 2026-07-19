# Per-Option Unfamiliar Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user right-click an answer option to flag it "unfamiliar" independently of selecting it, so that on submit every flagged option is downgraded — even if it's the correct answer and even if it wasn't the one submitted.

**Architecture:** Add a second per-question list (`_unfamiliarOptionWords`) alongside the existing `_unfamiliarWords` in `ChatViewModel`, toggled by right-click instead of left-click. Extend `PromptSetter.reviewPrompt` to resolve the upgrade/downgrade conflict deterministically in Dart (mirroring how `isCorrect` is already precomputed and stated as fact) and emit an explicit, unambiguous instruction to the review model — no new models, no changes to `GeminiRepository` or the function-calling model.

**Tech Stack:** Flutter/Dart, `flutter_test` (no mocking library — hand-written Fakes only), existing `google_generative_ai` chat models untouched.

## Global Constraints

- No mocking library — any new Fakes must subclass the real class and override only the I/O method, per this repo's testing convention.
- `PromptSetter.reviewPrompt` must state resolved facts to the model, never ask it to judge/re-derive correctness or priority between rules (matches "Correctness is already determined above, do not re-judge it").
- Every option flagged unfamiliar is downgraded on submit, unconditionally — not just the selected one (per the approved design).
- The correct-answer override must be stated explicitly in the prompt when it fires (flagged-but-correct), not left implicit.
- UI targets desktop (per CLAUDE.md) — right-click (`onSecondaryTap`) is an acceptable input, no touch equivalent needed.
- Follow the existing Fake-subclass testing pattern; do not add a mocking dependency.

---

## File Structure

- Modify `lib/chat/prompt_setter.dart` — `reviewPrompt` gains a new parameter and resolves the correct-answer adjustment + a new option-unfamiliar instruction block.
- Modify `test/prompt_setter_test.dart` — new `PromptSetter.reviewPrompt` test group.
- Modify `lib/chat/chat_viewmodel.dart` — new state field, getter, toggle method, reset, and threading through `submitAnswer`/`_userResponse`.
- Modify `lib/chat/chat_ui.dart` — `_buildOptionCard` gains a right-click handler, a warning badge, and a tooltip.
- Modify `CLAUDE.md` — document the new option-unfamiliar behavior in the existing "Gemini conversation" section.

---

### Task 1: Extend `PromptSetter.reviewPrompt` with option-level unfamiliar handling

**Files:**
- Modify: `lib/chat/prompt_setter.dart:52-93` (the `reviewPrompt` method)
- Test: `test/prompt_setter_test.dart`

**Interfaces:**
- Consumes: `Option` (`lib/models/option.dart` — has `label`, `word`, both `String`).
- Produces: `PromptSetter.reviewPrompt(Option userAnswer, Option correctAnswer, bool isCorrect, List<String> unfamiliarWords, List<String> unfamiliarOptionWords) -> String`. Task 2 calls this with the new 5th argument.

- [ ] **Step 1: Write the failing tests**

Add this group to `test/prompt_setter_test.dart`, right after the existing `PromptSetter.novelQuestionPrompt` group (before the closing `}` of `main()`). This file doesn't import `Option` yet — add that import too.

```dart
import 'package:toeic_coach/models/option.dart';
```

```dart
  group('PromptSetter.reviewPrompt', () {
    final correct = Option(label: 'A', word: 'orientation');
    final wrongOption = Option(label: 'B', word: 'analyze');

    test('correct, no flags: records upgrade, no option block', () {
      final prompt =
          PromptSetter.reviewPrompt(correct, correct, true, [], []);
      expect(
        prompt.contains('adjustment "upgrade" in "memoryStateUpdateResult"'),
        isTrue,
      );
      expect(prompt.contains('unfamiliar'), isFalse);
    });

    test('wrong, no flags: records downgrade for correct answer', () {
      final prompt =
          PromptSetter.reviewPrompt(wrongOption, correct, false, [], []);
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
    });

    test('correct answer flagged unfamiliar overrides upgrade to downgrade',
        () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        [],
        ['orientation'],
      );
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
      expect(prompt.contains('adjustment "upgrade"'), isFalse);
      expect(prompt.contains('marked it unfamiliar'), isTrue);
    });

    test(
        'correct answer flagged unfamiliar but already wrong stays '
        'downgrade without override note', () {
      final prompt = PromptSetter.reviewPrompt(
        wrongOption,
        correct,
        false,
        [],
        ['orientation'],
      );
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
      expect(prompt.contains('marked it unfamiliar'), isFalse);
    });

    test('non-correct option flagged unfamiliar adds its own downgrade block',
        () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        [],
        ['analyze'],
      );
      expect(
        prompt.contains(
          'User also marked these answer options as unfamiliar',
        ),
        isTrue,
      );
      expect(prompt.contains('analyze'), isTrue);
      expect(
        prompt.contains('adjustment "upgrade" in "memoryStateUpdateResult"'),
        isTrue,
      );
    });

    test(
        'sentence-unfamiliar and option-unfamiliar blocks both appear '
        'independently', () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        ['bystander'],
        ['analyze'],
      );
      expect(
        prompt.contains('unfamiliar vocabulary provided by user'),
        isTrue,
      );
      expect(prompt.contains('bystander'), isTrue);
      expect(
        prompt.contains(
          'User also marked these answer options as unfamiliar',
        ),
        isTrue,
      );
      expect(prompt.contains('analyze'), isTrue);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/prompt_setter_test.dart`
Expected: FAIL — compile error, since `reviewPrompt` doesn't accept a 5th argument yet.

- [ ] **Step 3: Implement `reviewPrompt`**

Replace the entire existing `reviewPrompt` method (`lib/chat/prompt_setter.dart:52-93`) with:

```dart
  static String reviewPrompt(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
    List<String> unfamiliarOptionWords,
  ) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'The correct answer is (${correctAnswer.label}) ${correctAnswer.word}.',
    );
    buffer.writeln(
      "User's answer is (${userAnswer.label}) ${userAnswer.word}, "
      'which is ${isCorrect ? 'correct' : 'wrong'}.',
    );

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln(
        'And here are some unfamiliar vocabulary provided by user:',
      );
      for (String word in unfamiliarWords) {
        buffer.writeln('$word,');
      }
    }

    final List<String> optionWordsToDowngrade = unfamiliarOptionWords
        .where((word) => word != correctAnswer.word)
        .toList();
    if (optionWordsToDowngrade.isNotEmpty) {
      buffer.writeln('User also marked these answer options as unfamiliar:');
      for (String word in optionWordsToDowngrade) {
        buffer.writeln('$word,');
      }
    }

    final bool correctFlaggedUnfamiliar =
        unfamiliarOptionWords.contains(correctAnswer.word);
    final String correctAdjustment =
        (isCorrect && !correctFlaggedUnfamiliar) ? 'upgrade' : 'downgrade';

    buffer.writeln(
      'Goal: Explain the result above to user in traditional chinese, and '
      'record memoryState adjustments in the "memoryStateUpdateResult" '
      'field. Correctness is already determined above, do not re-judge it.',
    );
    buffer.writeln('Workflow:');

    int step = 1;
    buffer.writeln(
      '$step. In "result", tell user in one short sentence whether the '
      'answer is correct, and if wrong, which option is correct. Do not '
      'explain why there.',
    );
    step++;
    buffer.writeln(
      '$step. If the answer is wrong, explain in "review" why the correct '
      "option fits the blank and why user's choice does not.",
    );
    step++;

    final String correctStep =
        '$step. Record an entry with word "${correctAnswer.word}" and '
        'adjustment "$correctAdjustment" in "memoryStateUpdateResult".';
    buffer.writeln(
      (correctFlaggedUnfamiliar && isCorrect)
          ? '$correctStep Even though this answer is correct, the user '
              'marked it unfamiliar, so it must be downgraded, not upgraded.'
          : correctStep,
    );
    step++;

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln(
        '$step. Explain in "review" the meaning of each unfamiliar '
        'vocabulary from the first unfamiliar list as it is used in the '
        'sentence.',
      );
      step++;
      buffer.writeln(
        '$step. Record an entry with adjustment "downgrade" in '
        '"memoryStateUpdateResult" for every unfamiliar vocabulary in that '
        'first list.',
      );
      step++;
    }

    if (optionWordsToDowngrade.isNotEmpty) {
      buffer.writeln(
        '$step. Explain in "review" what each unfamiliar answer option '
        'word above means.',
      );
      step++;
      buffer.writeln(
        '$step. Record an entry with adjustment "downgrade" in '
        '"memoryStateUpdateResult" for every word in that answer-option '
        'list, even if it is also the correct or user-selected option.',
      );
      step++;
    }

    return buffer.toString();
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/prompt_setter_test.dart`
Expected: PASS — all tests including the pre-existing `questionPrompt`/`novelQuestionPrompt` groups.

- [ ] **Step 5: Commit**

```bash
git add lib/chat/prompt_setter.dart test/prompt_setter_test.dart
git commit -m "Add option-level unfamiliar handling to reviewPrompt"
```

---

### Task 2: Thread option-unfamiliar state through `ChatViewModel`

**Files:**
- Modify: `lib/chat/chat_viewmodel.dart:20-38` (fields), `:40-51` (getters), `:133-172` (`_userResponse`), `:177-227` (`startQuestion` reset), `:229-280` (`submitAnswer`), `:296-309` (toggle methods)

**Interfaces:**
- Consumes: `PromptSetter.reviewPrompt(Option, Option, bool, List<String>, List<String>)` from Task 1.
- Produces: `ChatViewModel.unfamiliarOptionWords -> List<String>` and `ChatViewModel.toggleOptionUnfamiliar(Option option) -> void`. Task 3 (`chat_ui.dart`) calls both.

- [ ] **Step 1: Add the new field and getter**

In `lib/chat/chat_viewmodel.dart`, find this line (line 22):

```dart
  List<String> _unfamiliarWords = [];
```

Add immediately after it:

```dart
  List<String> _unfamiliarOptionWords = [];
```

Find this line (line 40):

```dart
  List<String> get unfamiliarWords => _unfamiliarWords;
```

Add immediately after it:

```dart
  List<String> get unfamiliarOptionWords => _unfamiliarOptionWords;
```

- [ ] **Step 2: Reset the new field in `startQuestion`**

Find (inside `startQuestion`, currently lines 180-184):

```dart
    //init member variables
    _retryTimes = 0;
    _unfamiliarWords = [];
    _selectedOption = null;
    _errorMessage = null;
```

Replace with:

```dart
    //init member variables
    _retryTimes = 0;
    _unfamiliarWords = [];
    _unfamiliarOptionWords = [];
    _selectedOption = null;
    _errorMessage = null;
```

- [ ] **Step 3: Thread the new list through `_userResponse`**

Find the `_userResponse` signature and its call to `PromptSetter.reviewPrompt` (currently lines 133-144):

```dart
  Future<String> _userResponse(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
  ) async {
    String prompt = PromptSetter.reviewPrompt(
      userAnswer,
      correctAnswer,
      isCorrect,
      unfamiliarWords,
    );
```

Replace with:

```dart
  Future<String> _userResponse(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
    List<String> unfamiliarOptionWords,
  ) async {
    String prompt = PromptSetter.reviewPrompt(
      userAnswer,
      correctAnswer,
      isCorrect,
      unfamiliarWords,
      unfamiliarOptionWords,
    );
```

- [ ] **Step 4: Pass the field at the `submitAnswer` call site**

Find (currently lines 242-249):

```dart
      final String? modelResponse = await RetryHandler.retryHandler(
        () => _userResponse(
          selectedOption!,
          correctOption,
          _isCorrect!,
          unfamiliarWords,
        ),
```

Replace with:

```dart
      final String? modelResponse = await RetryHandler.retryHandler(
        () => _userResponse(
          selectedOption!,
          correctOption,
          _isCorrect!,
          unfamiliarWords,
          _unfamiliarOptionWords,
        ),
```

- [ ] **Step 5: Add `toggleOptionUnfamiliar`**

Find the existing `toggleOption` method (currently lines 305-308):

```dart
  void toggleOption(Option option) {
    _selectedOption = option;
    notifyListeners();
  }
}
```

Replace with (adds a new method, keeps `toggleOption` as-is):

```dart
  void toggleOption(Option option) {
    _selectedOption = option;
    notifyListeners();
  }

  void toggleOptionUnfamiliar(Option option) {
    if (_unfamiliarOptionWords.contains(option.word)) {
      _unfamiliarOptionWords.remove(option.word);
    } else {
      _unfamiliarOptionWords.add(option.word);
    }
    notifyListeners();
  }
}
```

- [ ] **Step 6: Verify the whole suite still compiles and passes**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: All tests pass (existing suite + Task 1's new `reviewPrompt` tests).

- [ ] **Step 7: Commit**

```bash
git add lib/chat/chat_viewmodel.dart
git commit -m "Add per-option unfamiliar toggle state to ChatViewModel"
```

---

### Task 3: Right-click toggle and visual badge in `chat_ui.dart`

**Files:**
- Modify: `lib/chat/chat_ui.dart:168-176` (option card call site), `:441-464` (`_buildOptionCard`)

**Interfaces:**
- Consumes: `ChatViewModel.unfamiliarOptionWords -> List<String>`, `ChatViewModel.toggleOptionUnfamiliar(Option) -> void` from Task 2; `kWarning` color from `lib/theme/app_theme.dart`.
- Produces: no new public interface — this is the leaf UI change.

- [ ] **Step 1: Pass the unfamiliar flag at the call site**

Find (currently lines 168-176):

```dart
                    ..._chatViewModel.options.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOptionCard(
                          option,
                          _chatViewModel.selectedOption == option,
                        ),
                      ),
                    ),
```

Replace with:

```dart
                    ..._chatViewModel.options.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOptionCard(
                          option,
                          _chatViewModel.selectedOption == option,
                          _chatViewModel.unfamiliarOptionWords.contains(
                            option.word,
                          ),
                        ),
                      ),
                    ),
```

- [ ] **Step 2: Rewrite `_buildOptionCard`**

Find the existing method (currently lines 441-464):

```dart
  // A single answer option rendered as a card with an A/B/C/D badge.
  Widget _buildOptionCard(Option option, bool selected) {
    return GestureDetector(
      onTap: () => _chatViewModel.toggleOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: selected ? kPrimaryLight : kSurface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: selected ? kPrimary : kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: _buildOptionShell(
          option: option,
          badgeColor: selected ? kSurface : kPrimaryLight,
          trailing: selected
              ? const Icon(Icons.check_circle, color: kPrimary)
              : null,
        ),
      ),
    );
  }
```

Replace with:

```dart
  // A single answer option rendered as a card with an A/B/C/D badge.
  // Left click selects it as the answer; right click flags it unfamiliar.
  // The two states are independent and rendered independently: selection
  // controls the card's background/border/checkmark, unfamiliar adds a
  // warning badge in the corner regardless of selection.
  Widget _buildOptionCard(Option option, bool selected, bool unfamiliar) {
    return GestureDetector(
      onTap: () => _chatViewModel.toggleOption(option),
      onSecondaryTap: () => _chatViewModel.toggleOptionUnfamiliar(option),
      child: Tooltip(
        message: '右鍵標記為不熟悉單字',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: selected ? kPrimaryLight : kSurface,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: selected ? kPrimary : kBorder,
                  width: selected ? 2 : 1,
                ),
              ),
              child: _buildOptionShell(
                option: option,
                badgeColor: selected ? kSurface : kPrimaryLight,
                trailing: selected
                    ? const Icon(Icons.check_circle, color: kPrimary)
                    : null,
              ),
            ),
            if (unfamiliar)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: kWarning,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/chat/chat_ui.dart
git commit -m "Add right-click unfamiliar toggle and badge to option cards"
```

---

### Task 4: Manual end-to-end verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: the running app (via the `verify` skill), Tasks 1–3's combined behavior.
- Produces: nothing — this task confirms the feature works before documenting it.

- [ ] **Step 1: Launch the app**

Use the `verify` skill to build and launch TOEIC Coach on Windows (`flutter run -d windows`, or whatever the skill's standard launch sequence is), with a database that has at least one word due for a question.

- [ ] **Step 2: Verify independence of the two toggles**

On the question view, left-click one option (confirm it shows selected — tinted background, checkmark) and right-click a *different* option (confirm it shows the warning badge, and that neither click affected the other option's state). Right-click the same option that's selected; confirm both the selection styling and the warning badge show simultaneously.

- [ ] **Step 3: Verify the correct-but-flagged override**

Answer a question by selecting the correct option, right-click it to flag it unfamiliar, and submit. In the review view's "記憶狀態調整" section, confirm the entry for that word shows a downgrade (down arrow, `kError`-colored), not an upgrade.

- [ ] **Step 4: Verify a flagged-but-unselected distractor is also downgraded**

Answer a different question: select the correct option (leave it unflagged), right-click a *different* (incorrect) option to flag it unfamiliar, and submit. Confirm the review's adjustment list includes a downgrade entry for that flagged distractor's word, in addition to the correct answer's own (upgrade) entry.

- [ ] **Step 5: Verify the flags reset between questions**

After completing a review, tap "下一題" and confirm the new question's options all render unflagged (no leftover warning badges from the previous question).

---

### Task 5: Document the new behavior in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (the "The Gemini conversation: three models, one shared history" section)

**Interfaces:** none — documentation only.

- [ ] **Step 1: Add a sentence to the `reviewUserAnswerModel` bullet**

Find this bullet in `CLAUDE.md` (under "The Gemini conversation: three models, one shared history"):

```
2. **reviewUserAnswerModel** — JSON schema output: `{result, review[], memoryStateUpdateResult[{word, adjustment}]}`. Correctness is **not** judged by this model: `ChatViewModel` computes `isCorrect` locally (`selectedOption.label == _correctLabel`, where `_correctLabel` is set at parse time — via `resolveAnswerLabel` in normal mode, or Gemini's `answer` key in novel mode); the prompt then states the verdict as fact and the model only phrases it. `result` is the human-readable verdict (incl. the correct answer, in Traditional Chinese), `review` holds the explanations, and `memoryStateUpdateResult` lists structured `{word, adjustment}` entries.
```

Replace with (appends one sentence):

```
2. **reviewUserAnswerModel** — JSON schema output: `{result, review[], memoryStateUpdateResult[{word, adjustment}]}`. Correctness is **not** judged by this model: `ChatViewModel` computes `isCorrect` locally (`selectedOption.label == _correctLabel`, where `_correctLabel` is set at parse time — via `resolveAnswerLabel` in normal mode, or Gemini's `answer` key in novel mode); the prompt then states the verdict as fact and the model only phrases it. `result` is the human-readable verdict (incl. the correct answer, in Traditional Chinese), `review` holds the explanations, and `memoryStateUpdateResult` lists structured `{word, adjustment}` entries. The user can also right-click any answer option to flag it unfamiliar (`ChatViewModel.toggleOptionUnfamiliar`, independent of which option is selected); `PromptSetter.reviewPrompt` resolves in Dart whether a flagged option overrides the normal correctness-based upgrade — a flagged option is always downgraded, even if it is the correct answer — and states that resolved outcome to the model rather than asking it to judge the conflict.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document the option-level unfamiliar toggle in CLAUDE.md"
```
