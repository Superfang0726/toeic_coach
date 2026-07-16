# Question-Word Scheduler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the program pick the most overdue red/yellow word as each question's correct answer, and fall through to a novel-word expansion mode when nothing is due.

**Architecture:** A pure selector (`QuestionVocabSelector`) decides the answer word from overdueness; `PromptSetter` gets a normal prompt (answer fixed, Gemini assembles distractors/sentence/positions) and a novel prompt (Gemini invents everything). `ChatViewModel._generateQuestion` branches on the selector, moves response parsing into the retried unit, and resolves the correct label by locating the scheduled word among the options. `VocabularyViewmodel.handleVocabAdjustment` only captures unknown words on downgrade.

**Tech Stack:** Flutter/Dart, `flutter test` (hand-written Fakes, no mocking library), google_generative_ai.

## Global Constraints

- Already on branch `feat/question-word-scheduler` (never commit meaningful work to `main`).
- TDD: write the failing test, watch it fail, minimal implementation, watch it pass, commit.
- Tests use Fakes that subclass the real repository; no mocking library.
- Interval bands are unchanged: redLow=2, redMedium=3, redHigh=5, yellowLow/High=7, green=2.
- `flutter analyze` must introduce no new issues (4 pre-existing infos are the baseline); `flutter test` must stay green at each task boundary.
- Response schema in `gemini_repository.dart` is unchanged.

---

## File Structure

- `lib/chat/question_vocab_selector.dart` — gains `pickAnswerWord`, `distractorPool`, `greenPool`, `resolveAnswerLabel`; keeps `shuffle`; loses `filter` (Task 5). Pure.
- `lib/chat/prompt_setter.dart` — `questionPrompt` changes signature; new `novelQuestionPrompt` (Task 5).
- `lib/chat/chat_viewmodel.dart` — `_generateQuestion` rewired, new `_parseQuestion`, new `_scheduledAnswerWord` field (Task 5).
- `lib/vocabulary/vocabulary_viewmodel.dart` — `handleVocabAdjustment` add-on-downgrade-only (Task 4).
- Tests: `test/question_vocab_selector_test.dart` (extend, then drop filter group), `test/vocabulary_viewmodel_test.dart` (extend), `test/prompt_setter_test.dart` (new).

---

## Task 1: `pickAnswerWord` selector

**Files:**
- Modify: `lib/chat/question_vocab_selector.dart`
- Test: `test/question_vocab_selector_test.dart`

**Interfaces:**
- Produces: `static Vocab? QuestionVocabSelector.pickAnswerWord(List<Vocab> vocabulary, int currentRound, {Random? random})` — the due red/yellow word maximizing `currentRound - nextDueRound`, random tiebreak; `null` when no red/yellow word is due (novel-mode signal).

- [ ] **Step 1: Write the failing tests**

Add this group to `test/question_vocab_selector_test.dart` (the file already imports `dart:math`, `flutter_test`, `QuestionVocabSelector`, `Vocab`, and has a `vocab({required String word, int nextDueRound})` helper that builds a **red/redLow** vocab). Add a second helper for level/state control at the top of the file:

```dart
Vocab leveled({
  required String word,
  required Level level,
  required MemoryState memoryState,
  int nextDueRound = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: memoryState,
      nextDueRound: nextDueRound,
    );
```

```dart
group('QuestionVocabSelector.pickAnswerWord', () {
  test('picks the most overdue due red/yellow word', () {
    final result = QuestionVocabSelector.pickAnswerWord([
      leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 8),
      leveled(word: 'b', level: Level.yellow, memoryState: MemoryState.yellowLow, nextDueRound: 2),
      leveled(word: 'c', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 5),
    ], 10);
    // overdue: a=2, b=8, c=5 -> b is most overdue
    expect(result?.word, 'b');
  });

  test('ignores green words even when they are more overdue', () {
    final result = QuestionVocabSelector.pickAnswerWord([
      leveled(word: 'known', level: Level.green, memoryState: MemoryState.green, nextDueRound: 0),
      leveled(word: 'learning', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 9),
    ], 10);
    expect(result?.word, 'learning');
  });

  test('returns null when every red/yellow word is resting (not due)', () {
    final result = QuestionVocabSelector.pickAnswerWord([
      leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 12),
      leveled(word: 'b', level: Level.yellow, memoryState: MemoryState.yellowLow, nextDueRound: 20),
      leveled(word: 'g', level: Level.green, memoryState: MemoryState.green, nextDueRound: 0),
    ], 10);
    expect(result, isNull);
  });

  test('returns null for an empty vocabulary', () {
    expect(QuestionVocabSelector.pickAnswerWord([], 10), isNull);
  });

  test('random tiebreak returns one of the tied maxima', () {
    final input = [
      leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
      leveled(word: 'b', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
      leveled(word: 'c', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
    ];
    final result = QuestionVocabSelector.pickAnswerWord(input, 5, random: Random(1));
    expect(['a', 'b', 'c'].contains(result?.word), isTrue);
  });

  test('a strictly-maximum word is always chosen regardless of random', () {
    final input = [
      leveled(word: 'tie1', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 3),
      leveled(word: 'winner', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
      leveled(word: 'tie2', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 3),
    ];
    for (var seed = 0; seed < 5; seed++) {
      final result = QuestionVocabSelector.pickAnswerWord(input, 10, random: Random(seed));
      expect(result?.word, 'winner');
    }
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: FAIL — `pickAnswerWord` is not defined.

- [ ] **Step 3: Implement `pickAnswerWord`**

In `lib/chat/question_vocab_selector.dart`, add this method inside the class (leave `filter` and `shuffle` untouched for now):

```dart
  static Vocab? pickAnswerWord(
    List<Vocab> vocabulary,
    int currentRound, {
    Random? random,
  }) {
    final due = vocabulary
        .where(
          (v) =>
              (v.level == Level.red || v.level == Level.yellow) &&
              v.nextDueRound <= currentRound,
        )
        .toList();
    if (due.isEmpty) return null;

    final maxOverdue = due
        .map((v) => currentRound - v.nextDueRound)
        .reduce((a, b) => a > b ? a : b);
    final tied = due
        .where((v) => currentRound - v.nextDueRound == maxOverdue)
        .toList();
    tied.shuffle(random);
    return tied.first;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add lib/chat/question_vocab_selector.dart test/question_vocab_selector_test.dart
git commit -m "Add pickAnswerWord selector for the question scheduler"
```

---

## Task 2: `distractorPool` and `greenPool` selectors

**Files:**
- Modify: `lib/chat/question_vocab_selector.dart`
- Test: `test/question_vocab_selector_test.dart`

**Interfaces:**
- Produces: `static List<Vocab> QuestionVocabSelector.distractorPool(List<Vocab> vocabulary, Vocab answer)` — all red/yellow words except the answer. `static List<Vocab> QuestionVocabSelector.greenPool(List<Vocab> vocabulary)` — all green words.

- [ ] **Step 1: Write the failing tests**

Add to `test/question_vocab_selector_test.dart` (uses the `leveled` helper from Task 1):

```dart
group('QuestionVocabSelector.distractorPool', () {
  test('keeps red/yellow words and excludes the answer', () {
    final answer = leveled(word: 'answer', level: Level.red, memoryState: MemoryState.redLow);
    final result = QuestionVocabSelector.distractorPool([
      answer,
      leveled(word: 'red2', level: Level.red, memoryState: MemoryState.redLow),
      leveled(word: 'yellow1', level: Level.yellow, memoryState: MemoryState.yellowLow),
      leveled(word: 'green1', level: Level.green, memoryState: MemoryState.green),
    ], answer);
    expect(result.map((v) => v.word).toList(), ['red2', 'yellow1']);
  });

  test('matches the answer case-insensitively when excluding it', () {
    final answer = leveled(word: 'Answer', level: Level.red, memoryState: MemoryState.redLow);
    final result = QuestionVocabSelector.distractorPool([
      leveled(word: 'answer', level: Level.red, memoryState: MemoryState.redLow),
      leveled(word: 'other', level: Level.red, memoryState: MemoryState.redLow),
    ], answer);
    expect(result.map((v) => v.word).toList(), ['other']);
  });
});

group('QuestionVocabSelector.greenPool', () {
  test('keeps only green words', () {
    final result = QuestionVocabSelector.greenPool([
      leveled(word: 'g1', level: Level.green, memoryState: MemoryState.green),
      leveled(word: 'r1', level: Level.red, memoryState: MemoryState.redLow),
      leveled(word: 'g2', level: Level.green, memoryState: MemoryState.green),
    ]);
    expect(result.map((v) => v.word).toList(), ['g1', 'g2']);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: FAIL — `distractorPool` / `greenPool` not defined.

- [ ] **Step 3: Implement the pools**

Add to `lib/chat/question_vocab_selector.dart`:

```dart
  static List<Vocab> distractorPool(List<Vocab> vocabulary, Vocab answer) =>
      vocabulary
          .where(
            (v) =>
                (v.level == Level.red || v.level == Level.yellow) &&
                v.word.toLowerCase() != answer.word.toLowerCase(),
          )
          .toList();

  static List<Vocab> greenPool(List<Vocab> vocabulary) =>
      vocabulary.where((v) => v.level == Level.green).toList();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/chat/question_vocab_selector.dart test/question_vocab_selector_test.dart
git commit -m "Add distractor and green candidate pools to the selector"
```

---

## Task 3: `resolveAnswerLabel` selector

**Files:**
- Modify: `lib/chat/question_vocab_selector.dart` (add `import 'package:toeic_coach/models/option.dart';`)
- Test: `test/question_vocab_selector_test.dart` (add `import 'package:toeic_coach/models/option.dart';`)

**Interfaces:**
- Produces: `static String? QuestionVocabSelector.resolveAnswerLabel(List<Option> options, String answerWord)` — the label (`'A'`..`'D'`) of the option whose word matches `answerWord` case-insensitively, or `null` if none matches.

- [ ] **Step 1: Write the failing tests**

Add the import at the top of `test/question_vocab_selector_test.dart`:

```dart
import 'package:toeic_coach/models/option.dart';
```

Add this group:

```dart
group('QuestionVocabSelector.resolveAnswerLabel', () {
  final options = [
    Option(label: 'A', word: 'alpha'),
    Option(label: 'B', word: 'bravo'),
    Option(label: 'C', word: 'charlie'),
    Option(label: 'D', word: 'delta'),
  ];

  test('returns the label whose word matches', () {
    expect(QuestionVocabSelector.resolveAnswerLabel(options, 'charlie'), 'C');
  });

  test('matches case-insensitively', () {
    expect(QuestionVocabSelector.resolveAnswerLabel(options, 'BRAVO'), 'B');
  });

  test('returns null when no option holds the word', () {
    expect(QuestionVocabSelector.resolveAnswerLabel(options, 'echo'), isNull);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: FAIL — `resolveAnswerLabel` not defined.

- [ ] **Step 3: Implement `resolveAnswerLabel`**

Add the import at the top of `lib/chat/question_vocab_selector.dart`:

```dart
import 'package:toeic_coach/models/option.dart';
```

Add the method:

```dart
  static String? resolveAnswerLabel(List<Option> options, String answerWord) {
    for (final option in options) {
      if (option.word.toLowerCase() == answerWord.toLowerCase()) {
        return option.label;
      }
    }
    return null;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/question_vocab_selector_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/chat/question_vocab_selector.dart test/question_vocab_selector_test.dart
git commit -m "Add resolveAnswerLabel to locate the scheduled answer in options"
```

---

## Task 4: `handleVocabAdjustment` add-on-downgrade-only

**Files:**
- Modify: `lib/vocabulary/vocabulary_viewmodel.dart:106-117`
- Test: `test/vocabulary_viewmodel_test.dart`

**Interfaces:**
- Consumes: `VocabAdjustment(word:, mean:, adjustment:)`, `Adjustment.{upgrade,downgrade}` (from `models/vocab_adjustment.dart`), the `FakeExcelRepository` / `FakeSharedPreferencesRepository` and `makeViewmodel` helper already in the test file.
- Produces (behavior): an unknown word is added as red only when the adjustment is `downgrade`; an unknown word with `upgrade` is ignored; an existing word still routes to `applyVocabAdjustment`.

- [ ] **Step 1: Write the failing tests**

Add to `test/vocabulary_viewmodel_test.dart` (import `vocab_adjustment.dart` is already present):

```dart
test('handleVocabAdjustment adds an unknown word as red on downgrade', () {
  final store = Store();
  store.updateVocabularyStore([]);
  final excel = FakeExcelRepository();
  final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

  vm.handleVocabAdjustment(
    VocabAdjustment(word: 'novel', mean: '新字', adjustment: Adjustment.downgrade),
  );

  final added = store.vocabulary.single;
  expect(added.word, 'novel');
  expect(added.level, Level.red);
});

test('handleVocabAdjustment ignores an unknown word answered correctly (upgrade)', () {
  final store = Store();
  store.updateVocabularyStore([]);
  final excel = FakeExcelRepository();
  final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

  vm.handleVocabAdjustment(
    VocabAdjustment(word: 'known', mean: '會的字', adjustment: Adjustment.upgrade),
  );

  expect(store.vocabulary, isEmpty);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vocabulary_viewmodel_test.dart`
Expected: FAIL on the second test — the current code adds the unknown `upgrade` word, so `store.vocabulary` is not empty.

- [ ] **Step 3: Implement the filter**

Replace `lib/vocabulary/vocabulary_viewmodel.dart:106-117` with:

```dart
  void handleVocabAdjustment(VocabAdjustment vocabAdjustment) {
    if (VocabDomain.checkVocabExist(store.vocabulary, vocabAdjustment.word)) {
      applyVocabAdjustment(vocabAdjustment);
    } else if (vocabAdjustment.adjustment == Adjustment.downgrade) {
      addVocab(
        word: vocabAdjustment.word,
        mean: vocabAdjustment.mean,
        level: Level.red,
      );
    }
    // An unknown word answered correctly (upgrade) is intentionally not added:
    // novel-mode questions should only capture words the user got wrong or
    // flagged as unfamiliar, not ones they already know.
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/vocabulary_viewmodel_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/vocabulary/vocabulary_viewmodel.dart test/vocabulary_viewmodel_test.dart
git commit -m "Only capture unknown words on downgrade, not upgrade"
```

---

## Task 5: Wire the scheduler into question generation

This task changes `PromptSetter.questionPrompt`'s signature, adds `novelQuestionPrompt`, rewires `ChatViewModel._generateQuestion`, and removes the now-unused `filter`. The repository does not fully compile between Step 3 and Step 8; the task's deliverable (Step 9) is green.

**Files:**
- Modify: `lib/chat/prompt_setter.dart`
- Modify: `lib/chat/chat_viewmodel.dart`
- Modify: `lib/chat/question_vocab_selector.dart` (remove `filter`)
- Modify: `test/question_vocab_selector_test.dart` (remove the `filter` group)
- Test: `test/prompt_setter_test.dart` (new)

**Interfaces:**
- Consumes: `QuestionVocabSelector.pickAnswerWord`, `.distractorPool`, `.greenPool`, `.shuffle`, `.resolveAnswerLabel`; `PromptSetter.questionPrompt`, `.novelQuestionPrompt`.
- Produces: `static String PromptSetter.questionPrompt(Vocab answer, List<Vocab> distractorPool, List<Vocab> greenPool)` and `static String PromptSetter.novelQuestionPrompt()`.

- [ ] **Step 1: Write the failing PromptSetter tests**

Create `test/prompt_setter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/models/vocab.dart';

Vocab v(String word, String mean, Level level, MemoryState state) => Vocab(
      id: word,
      word: word,
      mean: mean,
      level: level,
      memoryState: state,
      nextDueRound: 0,
    );

void main() {
  group('PromptSetter.questionPrompt', () {
    final answer = v('orientation', '新人訓練', Level.yellow, MemoryState.yellowLow);
    final distractors = [v('analyze', '分析', Level.red, MemoryState.redLow)];
    final greens = [v('attend', '參加', Level.green, MemoryState.green)];

    test('names the fixed correct answer word', () {
      final prompt = PromptSetter.questionPrompt(answer, distractors, greens);
      expect(prompt.contains('orientation'), isTrue);
      expect(prompt.contains('MUST'), isTrue);
    });

    test('includes distractor and green candidate words', () {
      final prompt = PromptSetter.questionPrompt(answer, distractors, greens);
      expect(prompt.contains('analyze'), isTrue);
      expect(prompt.contains('attend'), isTrue);
    });
  });

  group('PromptSetter.novelQuestionPrompt', () {
    test('asks for a fresh question and an empty usedGreenWords', () {
      final prompt = PromptSetter.novelQuestionPrompt();
      expect(prompt.contains('TOEIC Part 5'), isTrue);
      expect(prompt.contains('usedGreenWords'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/prompt_setter_test.dart`
Expected: FAIL — `questionPrompt` signature mismatch / `novelQuestionPrompt` not defined.

- [ ] **Step 3: Rewrite `PromptSetter.questionPrompt` and add `novelQuestionPrompt`**

In `lib/chat/prompt_setter.dart`, replace the whole `questionPrompt` method (currently `questionPrompt(List<Vocab> filteredVocabulary)`) with these two methods (leave `reviewPrompt` untouched):

```dart
  static String questionPrompt(
    Vocab answer,
    List<Vocab> distractorPool,
    List<Vocab> greenPool,
  ) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Correct answer word: ${answer.word} (meaning: ${answer.mean}).',
    );
    buffer.writeln();
    buffer.writeln('Distractor candidates (red/yellow words):');
    buffer.writeln('| word | mean | level |');
    buffer.writeln('|---|---|---|');
    for (Vocab vocab in distractorPool) {
      buffer.writeln('| ${vocab.word} | ${vocab.mean} | ${vocab.level.name} |');
    }
    buffer.writeln();
    buffer.writeln('Green words available for the sentence:');
    buffer.writeln('| word | mean |');
    buffer.writeln('|---|---|');
    for (Vocab vocab in greenPool) {
      buffer.writeln('| ${vocab.word} | ${vocab.mean} |');
    }
    buffer.writeln(
      """
Goal: Generate one TOEIC Part 5 question whose correct answer is EXACTLY "${answer.word}".
Workflow:
1. The correct answer for the blank MUST be "${answer.word}". Never substitute another word.
2. Choose three distractors for the other choices. Prefer words from the distractor candidates above; if there are fewer than three, fill the rest with plausible TOEIC-level distractors that are not in any table. The three distractors must be clearly wrong in this sentence, either by meaning or by usage.
3. Place the four choices (the correct answer plus the three distractors) at randomly chosen positions among A, B, C and D, and set "answer" to the key holding "${answer.word}".
4. Construct the question sentence using as many relevant green words as possible. It must contain exactly one blank written as "___", and only "${answer.word}" may fit it naturally and grammatically.
5. List in "usedGreenWords" every green word from the table above that you actually used, reported using the EXACT form written in the table. If the sentence inflects a word, still report the table's original form: e.g. if the table lists "announce" but the sentence uses "announced", report "announce"; if the table lists "meeting", report "meeting", never "meet". If you used no green words, return an empty array.""",
    );
    return buffer.toString();
  }

  static String novelQuestionPrompt() {
    return """
Goal: Generate one fresh TOEIC Part 5 vocabulary question from common TOEIC vocabulary. You are not given a word list; choose all words yourself.
Workflow:
1. Choose one correct answer word and three distractors that are grammatically plausible but clearly wrong in the sentence, either by meaning or by usage.
2. Place the four choices at randomly chosen positions among A, B, C and D, and set "answer" to the key holding the correct word.
3. Construct the question sentence: it must contain exactly one blank written as "___", and only the correct choice may fit it naturally and grammatically.
4. Return an empty array for "usedGreenWords".""";
  }
```

- [ ] **Step 4: Run the PromptSetter tests to verify they pass**

Run: `flutter test test/prompt_setter_test.dart`
Expected: PASS. (The full suite does not compile yet — `chat_viewmodel.dart` still calls the old signature. That is fixed in Step 5.)

- [ ] **Step 5: Rewire `ChatViewModel`**

In `lib/chat/chat_viewmodel.dart`:

(a) Add a field next to the other llm-response fields (after `String _correctLabel = '';` near line 30):

```dart
  String? _scheduledAnswerWord;
```

(b) Replace `_generateQuestion` (currently lines 69-83) with:

```dart
  Future<String> _generateQuestion() async {
    final Vocab? answer = QuestionVocabSelector.pickAnswerWord(
      _store.vocabulary,
      _store.currentRound,
    );
    _scheduledAnswerWord = answer?.word;

    final String prompt;
    if (answer != null) {
      final distractors = QuestionVocabSelector.shuffle(
        QuestionVocabSelector.distractorPool(_store.vocabulary, answer),
      );
      final greens = QuestionVocabSelector.shuffle(
        QuestionVocabSelector.greenPool(_store.vocabulary),
      );
      prompt = PromptSetter.questionPrompt(answer, distractors, greens);
    } else {
      prompt = PromptSetter.novelQuestionPrompt();
    }

    final (response, history) = await _geminiRepository.generateQuestion(prompt);
    _history = history;

    final text = response.text ?? 'No response got';
    _parseQuestion(text);
    return text;
  }

  void _parseQuestion(String modelResponse) {
    final cleanedText = modelResponse.trim().replaceAll('```', '');
    final map = jsonDecode(cleanedText);
    _sentence = map['sentence'];
    final opts = map['options'] as Map<String, dynamic>;
    _options = ['A', 'B', 'C', 'D'].map((k) {
      final word = VocabDomain.canonicalizeWord(
        _store.vocabulary,
        opts[k] as String,
      );
      return Option(label: k, word: word);
    }).toList();

    if (_scheduledAnswerWord != null) {
      final label = QuestionVocabSelector.resolveAnswerLabel(
        _options,
        _scheduledAnswerWord!,
      );
      if (label == null) {
        // Gemini did not place the scheduled word among the options; throw so
        // RetryHandler regenerates instead of showing a wrong question.
        throw StateError(
          'Scheduled answer "$_scheduledAnswerWord" missing from options',
        );
      }
      _correctLabel = label;
    } else {
      _correctLabel = map['answer'] as String;
    }

    _usedGreenWords = ((map['usedGreenWords'] as List?) ?? const [])
        .map((e) => e as String)
        .toList();
  }
```

(c) In `startQuestion`, replace the parsing block inside `if (modelResponse != null) { ... }` (currently lines 150-168, from `final cleanedText = ...` through the `notifyListeners();` that follows `chatState = ChatState.displayingQuestion;`) with just:

```dart
      if (modelResponse != null) {
        chatState = ChatState.displayingQuestion;
        notifyListeners();
      } else {
        chatState = ChatState.failToGenerateQuestion;
        notifyListeners();
      }
```

Leave the surrounding `try { modelResponse = await RetryHandler.retryHandler(...); ... } catch (error) { _handlePermanentError(error); }` structure intact.

- [ ] **Step 6: Remove the superseded `filter`**

In `lib/chat/question_vocab_selector.dart`, delete the `filter` method:

```dart
  static List<Vocab> filter(List<Vocab> vocabulary, int currentRound) =>
      vocabulary.where((vocab) => vocab.nextDueRound <= currentRound).toList();
```

In `test/question_vocab_selector_test.dart`, delete the entire `group('QuestionVocabSelector.filter', () { ... });` block (the boundary/exclusion tests for the old due filter). Keep the `shuffle`, `pickAnswerWord`, `distractorPool`, `greenPool`, and `resolveAnswerLabel` groups.

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: no new issues beyond the 4 pre-existing infos (`prefer_initializing_formals` x2 in chat_viewmodel, `avoid_print` x2). If a new error appears (e.g. unused import), fix it.

- [ ] **Step 8: Run the full test suite**

Run: `flutter test`
Expected: PASS (all files).

- [ ] **Step 9: Commit**

```bash
git add lib/chat/prompt_setter.dart lib/chat/chat_viewmodel.dart lib/chat/question_vocab_selector.dart test/prompt_setter_test.dart test/question_vocab_selector_test.dart
git commit -m "Drive question generation from the overdue-word scheduler"
```

---

## Task 6: End-to-end verification and PR

**Files:** none (verification + integration).

- [ ] **Step 1: Update project docs**

In `CLAUDE.md`, update the `QuestionVocabSelector` description (in the "Vocabulary mastery model" section) to reflect that the program now picks the most overdue red/yellow word as the answer and falls back to a novel-word mode when none is due. Keep it to one or two sentences. Commit:

```bash
git add CLAUDE.md
git commit -m "Document the question-word scheduler in CLAUDE.md"
```

- [ ] **Step 2: Drive the app end-to-end (verify skill)**

Use the `verify` project skill (`.claude/skills/verify/SKILL.md`) to build and launch on Windows. Back up `Documents/vocabulary.xlsx` first. Confirm:
1. Normal mode: with a database that has a clearly-most-overdue red/yellow word, the generated question's correct answer is exactly that word, and answering it upgrades/downgrades that word (check the row in the rewritten xlsx).
2. Novel mode: drain the due set (or temporarily point at a green-only / empty database), confirm a question is still generated; answer it wrong and confirm the novel word is added as a red word; answer another correctly and confirm that word is NOT added.
Capture screenshots via `PrintWindow` (no focus stealing). Close the app when done.

- [ ] **Step 3: Push and open the PR**

```bash
git push -u origin feat/question-word-scheduler
gh pr create --title "Program-driven question-word scheduler with novel-word expansion" --body "<summary of the two modes, the add-on-downgrade-only change, tests, and the e2e verification results>"
```

---

## Self-Review

**Spec coverage:**
- Selection state machine (due red/yellow → normal; empty → novel) → Task 1 (`pickAnswerWord` returns null to signal novel) + Task 5 (branch in `_generateQuestion`). ✓
- Approach A prompt (answer fixed, Gemini assembles; pools no gate) → Task 2 (pools) + Task 5 (`questionPrompt`). ✓
- Local label resolution / retry on missing word → Task 3 (`resolveAnswerLabel`) + Task 5 (`_parseQuestion` throw). ✓
- Novel mode prompt + trust Gemini's `answer` → Task 5. ✓
- Green words never chosen as answers (green fallback dropped) → Task 1 (only red/yellow considered). ✓
- Add-on-downgrade-only TODO → Task 4. ✓
- Remove old `filter` + tests → Task 5. ✓
- `GeminiRepository` schema unchanged → no task touches it. ✓
- Testing coverage (pickAnswerWord resting→null, tiebreak, pools, resolveAnswerLabel, handleVocabAdjustment upgrade-ignored, e2e both modes) → Tasks 1-5 + Task 6. ✓

**Placeholder scan:** none — every code step shows full code; the only `<...>` is the PR body summary in Task 6 Step 3, which is author-supplied prose.

**Type consistency:** `pickAnswerWord -> Vocab?`, `distractorPool/greenPool -> List<Vocab>`, `resolveAnswerLabel(List<Option>, String) -> String?`, `questionPrompt(Vocab, List<Vocab>, List<Vocab>) -> String`, `novelQuestionPrompt() -> String`, `_scheduledAnswerWord` (String?) — consistent across Tasks 1-5.
