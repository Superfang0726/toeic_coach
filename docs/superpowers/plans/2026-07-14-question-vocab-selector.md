# Question Vocab Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shuffle the cooldown-filtered vocabulary list before it's used to build the question-generation prompt, and consolidate the pure `filter`/`shuffle` helpers into a renamed `QuestionVocabSelector`.

**Architecture:** `lib/chat/question_vocab_filter.dart` (class `QuestionVocabFilter`, one static `filter` method) is replaced by `lib/chat/question_vocab_selector.dart` (class `QuestionVocabSelector`, static `filter` + `shuffle` methods). `ChatViewModel._generateQuestion` calls `filter` then `shuffle` before handing the list to `PromptSetter.questionPrompt`. No other layer changes — see `docs/superpowers/specs/2026-07-14-question-vocab-selector-design.md` for the rationale on keeping this in `lib/chat/` rather than merging into `VocabDomain`.

**Tech Stack:** Flutter/Dart, `flutter_test`, no mocking library (hand-written fakes only, not needed here since these are pure functions).

## Global Constraints

- `shuffle` must return a new `List<Vocab>` and must not mutate the list passed in (matches the immutable style of `lib/vocabulary/vocab_domain.dart`).
- `shuffle`'s `Random` parameter is optional (`{Random? random}`), mirroring Dart's own `List.shuffle(Random?)` signature, so tests can inject a seeded `Random` for determinism while production call sites pass nothing.
- Follow the existing pure-function test style from `test/vocab_domain_test.dart`: a local `vocab({...})` helper, `group`/`test`, direct static-method calls, no mocking.
- After Task 2, no file in the repo may reference `QuestionVocabFilter` or `question_vocab_filter.dart` (grep must return nothing outside `docs/superpowers/plans/2026-07-12-used-word-cooldown.md` and `docs/superpowers/specs/2026-07-12-used-word-cooldown-design.md`, which are historical records and must NOT be edited).

---

### Task 1: Create `QuestionVocabSelector` with `filter` + `shuffle`

**Files:**
- Create: `test/question_vocab_selector_test.dart`
- Create: `lib/chat/question_vocab_selector.dart`

**Interfaces:**
- Produces: `QuestionVocabSelector.filter(List<Vocab> vocabulary) -> List<Vocab>` — keeps only `vocab.cooldown == 0`, preserves relative order.
- Produces: `QuestionVocabSelector.shuffle(List<Vocab> vocabulary, {Random? random}) -> List<Vocab>` — returns a new shuffled list, does not mutate the input.

This task does not touch `lib/chat/chat_viewmodel.dart` or delete the old `question_vocab_filter.dart` yet — the old file keeps the app compiling until Task 2 wires the new class in.

- [ ] **Step 1: Write the failing test file**

Create `test/question_vocab_selector_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/question_vocab_selector.dart';
import 'package:toeic_coach/models/vocab.dart';

Vocab vocab({
  required String word,
  int cooldown = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: Level.red,
      memoryState: MemoryState.redLow,
      cooldown: cooldown,
    );

void main() {
  group('QuestionVocabSelector.filter', () {
    test('keeps only words with cooldown == 0', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', cooldown: 0),
        vocab(word: 'banana', cooldown: 2),
        vocab(word: 'cherry', cooldown: 0),
      ]);

      expect(result.map((v) => v.word).toList(), ['apple', 'cherry']);
    });

    test('returns an empty list when all words are on cooldown', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', cooldown: 1),
      ]);

      expect(result, isEmpty);
    });
  });

  group('QuestionVocabSelector.shuffle', () {
    test('returns a list with the same words as the input', () {
      final input = [
        vocab(word: 'apple'),
        vocab(word: 'banana'),
        vocab(word: 'cherry'),
        vocab(word: 'date'),
      ];

      final result = QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(
        result.map((v) => v.word).toSet(),
        {'apple', 'banana', 'cherry', 'date'},
      );
      expect(result.length, input.length);
    });

    test('does not mutate the input list', () {
      final input = [
        vocab(word: 'apple'),
        vocab(word: 'banana'),
        vocab(word: 'cherry'),
        vocab(word: 'date'),
      ];
      final originalOrder = input.map((v) => v.word).toList();

      QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(input.map((v) => v.word).toList(), originalOrder);
    });

    test('returns a different list instance than the input', () {
      final input = [vocab(word: 'apple'), vocab(word: 'banana')];

      final result = QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(identical(result, input), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: FAIL — compile error, `Target of URI doesn't exist: 'package:toeic_coach/chat/question_vocab_selector.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/chat/question_vocab_selector.dart`:

```dart
import 'dart:math';

import 'package:toeic_coach/models/vocab.dart';

class QuestionVocabSelector {
  static List<Vocab> filter(List<Vocab> vocabulary) =>
      vocabulary.where((vocab) => vocab.cooldown == 0).toList();

  static List<Vocab> shuffle(List<Vocab> vocabulary, {Random? random}) {
    final shuffled = List<Vocab>.of(vocabulary);
    shuffled.shuffle(random);
    return shuffled;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: PASS — `00:0X +5: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add test/question_vocab_selector_test.dart lib/chat/question_vocab_selector.dart
git commit -m "feat: add QuestionVocabSelector with filter and shuffle"
```

---

### Task 2: Wire shuffle into `ChatViewModel`, remove the old filter file, update docs

**Files:**
- Modify: `lib/chat/chat_viewmodel.dart:6` (import), `lib/chat/chat_viewmodel.dart:69-73` (`_generateQuestion`)
- Delete: `lib/chat/question_vocab_filter.dart`
- Modify: `CLAUDE.md:66`

**Interfaces:**
- Consumes: `QuestionVocabSelector.filter(List<Vocab>) -> List<Vocab>` and `QuestionVocabSelector.shuffle(List<Vocab>, {Random? random}) -> List<Vocab>` from Task 1.

- [ ] **Step 1: Update the import in `chat_viewmodel.dart`**

In `lib/chat/chat_viewmodel.dart`, change line 6 from:

```dart
import 'package:toeic_coach/chat/question_vocab_filter.dart';
```

to:

```dart
import 'package:toeic_coach/chat/question_vocab_selector.dart';
```

- [ ] **Step 2: Call filter then shuffle in `_generateQuestion`**

In `lib/chat/chat_viewmodel.dart`, change:

```dart
  Future<String> _generateQuestion() async {
    List<Vocab> filteredVocabulary = QuestionVocabFilter.filter(
      _store.vocabulary,
    );
    String prompt = PromptSetter.questionPrompt(filteredVocabulary);
```

to:

```dart
  Future<String> _generateQuestion() async {
    List<Vocab> filteredVocabulary = QuestionVocabSelector.filter(
      _store.vocabulary,
    );
    filteredVocabulary = QuestionVocabSelector.shuffle(filteredVocabulary);
    String prompt = PromptSetter.questionPrompt(filteredVocabulary);
```

- [ ] **Step 3: Delete the old filter file**

```bash
git rm lib/chat/question_vocab_filter.dart
```

- [ ] **Step 4: Update `CLAUDE.md`**

In `CLAUDE.md`, change the line (around line 66):

```markdown
- `PromptSetter.questionPrompt` (in `lib/chat/`) tells Gemini to use **red/yellow** words as the answer choices and **green** (known) words to build the sentence. `QuestionVocabFilter.filter` (also in `lib/chat/`) selects only words with `cooldown == 0` before passing them into the prompt.
```

to:

```markdown
- `PromptSetter.questionPrompt` (in `lib/chat/`) tells Gemini to use **red/yellow** words as the answer choices and **green** (known) words to build the sentence. `QuestionVocabSelector` (also in `lib/chat/`) selects only words with `cooldown == 0` and shuffles them before passing them into the prompt.
```

- [ ] **Step 5: Verify no remaining references to the old name**

Run: `grep -rn "QuestionVocabFilter\|question_vocab_filter" --include="*.dart" .`
Expected: no output (empty).

Run: `grep -rn "QuestionVocabFilter\|question_vocab_filter" CLAUDE.md`
Expected: no output (empty).

- [ ] **Step 6: Run static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: all tests pass, including the new `test/question_vocab_selector_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add lib/chat/chat_viewmodel.dart CLAUDE.md
git commit -m "feat: shuffle filtered vocab before building question prompt"
```

---

## Self-Review Notes

- **Spec coverage:** Spec's "Design" section (rename, `shuffle` signature, wiring into `_generateQuestion`, `CLAUDE.md` update, new test file) is covered by Task 1 (new class + tests) and Task 2 (wiring, deletion, docs, verification). Spec's "Out of scope" items (no `PromptSetter` change, no green-word selection change, no `VocabDomain`/cooldown-semantics change) are respected — no task touches those files.
- **Placeholder scan:** no TBD/TODO, all steps have literal code/commands with expected output.
- **Type consistency:** `QuestionVocabSelector.filter`/`shuffle` signatures match between Task 1's production code and Task 2's call sites.
