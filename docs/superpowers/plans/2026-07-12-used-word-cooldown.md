# Used-Word Cooldown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a question is generated, every database word it used — all 4 option words plus the green sentence-construction words — enters cooldown, without changing those words' mastery level.

**Architecture:** Add a cooldown-on-use path decoupled from mastery adjustment: a pure `VocabDomain` function sets `cooldown = inferCooldown(currentMemoryState)` for used words (leaving `memoryState`/`level` untouched), and a thin `VocabularyViewmodel` method writes it through to `Store` + Excel. "Used words" are detected via a hybrid: the 4 option words are matched locally (already canonicalized), while green sentence words are reported by the LLM in a new `usedGreenWords` schema field and validated against the DB. `ChatViewModel` captures the green words at question time and applies cooldown during review, after the existing global decay and before mastery adjustment.

**Tech Stack:** Flutter / Dart, `google_generative_ai` SDK (Gemini), `flutter_test`.

## Global Constraints

- Do NOT change mastery adjustment logic (`upgrade`/`downgrade`/`inferLevel`), the review model, or the `updateMemoryState` function-calling model.
- Do NOT change the Excel schema — the `cooldown` column already exists (`id, word, mean, level, state, cooldown`).
- Do NOT introduce an English stemmer/lemmatizer.
- Word matching against the DB is case-insensitive (consistent with `VocabDomain.checkVocabExist` / `canonicalizeWord`).
- Branch: `feat/used-word-cooldown`. Do not commit to `main`.
- `Vocab` is immutable-by-convention with a `copyWith`; construct updated copies, never mutate fields in place.

---

### Task 1: Pure domain function `applyCooldownForUsedWords`

Adds the core, fully-testable logic: given the vocab list and a set of used words, return a new list where each used word's `cooldown` is reset to its band value and nothing else changes.

**Files:**
- Modify: `lib/vocabulary/vocab_domain.dart` (add one static method next to `decreaseCooldown`, ~line 81)
- Test: `test/vocab_domain_test.dart` (new file)

**Interfaces:**
- Consumes: existing `VocabDomain.inferCooldown(MemoryState)` → `int`; `Vocab.copyWith`.
- Produces: `static List<Vocab> VocabDomain.applyCooldownForUsedWords(List<Vocab> vocabs, Set<String> usedWords)` → new list; each vocab whose `word` (case-insensitive) is in `usedWords` gets `cooldown: inferCooldown(vocab.memoryState)`, all other fields and all non-used vocabs unchanged; unknown words in `usedWords` are ignored.

- [ ] **Step 1: Write the failing test**

Create `test/vocab_domain_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/vocab_domain.dart';

Vocab vocab({
  required String word,
  required MemoryState memoryState,
  required Level level,
  int cooldown = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: memoryState,
      cooldown: cooldown,
    );

void main() {
  group('applyCooldownForUsedWords', () {
    test('sets cooldown to the band value for a used word', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      // inferCooldown(green) == 2
      expect(result.single.cooldown, 2);
    });

    test('uses the current memoryState band (redHigh -> 5)', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'audit', memoryState: MemoryState.redHigh, level: Level.red)],
        {'audit'},
      );
      expect(result.single.cooldown, 5);
    });

    test('matches case-insensitively', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'Apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      expect(result.single.cooldown, 2);
    });

    test('ignores words not present in the vocab list', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green),
      ];
      final result = VocabDomain.applyCooldownForUsedWords(input, {'banana'});
      expect(result.single.cooldown, 0);
    });

    test('leaves memoryState and level untouched', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      expect(result.single.memoryState, MemoryState.green);
      expect(result.single.level, Level.green);
    });

    test('leaves non-used vocabs completely unchanged', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green, cooldown: 0),
        vocab(word: 'banana', memoryState: MemoryState.redLow, level: Level.red, cooldown: 4),
      ];
      final result = VocabDomain.applyCooldownForUsedWords(input, {'apple'});
      expect(result[1].cooldown, 4);
      expect(result[1].memoryState, MemoryState.redLow);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/vocab_domain_test.dart`
Expected: FAIL — compile error, `The method 'applyCooldownForUsedWords' isn't defined for the type 'VocabDomain'`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/vocabulary/vocab_domain.dart`, add this static method immediately after `decreaseCooldown` (before `inferLevel`):

```dart
  static List<Vocab> applyCooldownForUsedWords(
    List<Vocab> currentVocabs,
    Set<String> usedWords,
  ) {
    final lowered = usedWords.map((w) => w.toLowerCase()).toSet();
    return currentVocabs
        .map(
          (vocab) => lowered.contains(vocab.word.toLowerCase())
              ? vocab.copyWith(cooldown: inferCooldown(vocab.memoryState))
              : vocab,
        )
        .toList();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/vocab_domain_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/vocabulary/vocab_domain.dart test/vocab_domain_test.dart
git commit -m "feat: add VocabDomain.applyCooldownForUsedWords"
```

---

### Task 2: ViewModel write-through method

Wraps the pure function with persistence, matching the existing `decreaseCooldown` VM method (store update + Excel write).

**Files:**
- Modify: `lib/vocabulary/vocabulary_viewmodel.dart` (add method after `decreaseCooldown`, ~line 118)
- Test: `test/vocabulary_viewmodel_test.dart` (new file)

**Interfaces:**
- Consumes: `VocabDomain.applyCooldownForUsedWords` (Task 1); `store.vocabulary`, `store.updateVocabularyStore(List<Vocab>)`, `excelRepository.writeExcel(List<Vocab>)`.
- Produces: `void VocabularyViewmodel.applyCooldownForUsedWords(List<String> words)` — resets cooldown for the named words in the store and persists the whole list to Excel. No-op-safe for empty input and unknown words.

- [ ] **Step 1: Write the failing test**

Create `test/vocabulary_viewmodel_test.dart`. `ExcelRepository.writeExcel` is a plain `void` method, so a subclass can capture writes without touching the filesystem:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/excel_repository.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class FakeExcelRepository extends ExcelRepository {
  FakeExcelRepository() : super('unused.xlsx');
  List<Vocab>? lastWritten;
  @override
  void writeExcel(List<Vocab> vocabs) {
    lastWritten = vocabs;
  }
}

Vocab vocab(String word, MemoryState state, Level level, {int cooldown = 0}) =>
    Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: state,
      cooldown: cooldown,
    );

void main() {
  test('applyCooldownForUsedWords updates store and persists to Excel', () {
    final store = Store();
    store.updateVocabularyStore([
      vocab('apple', MemoryState.green, Level.green),
      vocab('banana', MemoryState.redLow, Level.red, cooldown: 4),
    ]);
    final excel = FakeExcelRepository();
    final vm = VocabularyViewmodel(store: store, excelRepository: excel);

    vm.applyCooldownForUsedWords(['apple']);

    // Store updated: apple cooled to its band (green -> 2), banana untouched.
    expect(store.vocabulary.firstWhere((v) => v.word == 'apple').cooldown, 2);
    expect(store.vocabulary.firstWhere((v) => v.word == 'banana').cooldown, 4);
    // Persisted the same list.
    expect(excel.lastWritten, isNotNull);
    expect(excel.lastWritten!.firstWhere((v) => v.word == 'apple').cooldown, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/vocabulary_viewmodel_test.dart`
Expected: FAIL — `The method 'applyCooldownForUsedWords' isn't defined for the type 'VocabularyViewmodel'`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/vocabulary/vocabulary_viewmodel.dart`, add after `decreaseCooldown` (end of class):

```dart
  void applyCooldownForUsedWords(List<String> words) {
    List<Vocab> updatedVocab = VocabDomain.applyCooldownForUsedWords(
      store.vocabulary,
      words.toSet(),
    );

    //write in
    store.updateVocabularyStore(updatedVocab);
    excelRepository.writeExcel(updatedVocab);
  }
```

`VocabDomain` and `Vocab` are already imported in this file — no new imports needed.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/vocabulary_viewmodel_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/vocabulary/vocabulary_viewmodel.dart test/vocabulary_viewmodel_test.dart
git commit -m "feat: add VocabularyViewmodel.applyCooldownForUsedWords write-through"
```

---

### Task 3: Question schema + prompt report green words

Teach the question model to report which green table-words it used, so the app can cool them without guessing at inflected forms.

**Files:**
- Modify: `lib/chat/gemini_repository.dart` (question schema, ~lines 59-65)
- Modify: `lib/chat/prompt_setter.dart` (`questionPrompt`, ~lines 13-22)

**Interfaces:**
- Produces: question JSON responses now include `usedGreenWords`: a `List<String>` of green words used to build the sentence, spelled as in the provided table (may be empty). Added to the schema's `requiredProperties`.

This task has no unit test (it changes a prompt string and an SDK schema object, which are exercised in Task 4's parsing and verified manually against the live model). Verify by `flutter analyze`.

- [ ] **Step 1: Add the schema field**

In `lib/chat/gemini_repository.dart`, inside the `_generateQuestionModel` `Schema.object` `properties` map, add a `usedGreenWords` entry after the `sentence` property (after line 63, before the closing `},` of `properties` at line 64):

```dart
            'usedGreenWords': Schema.array(
              items: Schema.string(
                description:
                    'A green word taken from the provided vocabulary table that '
                    'was used to construct the sentence, spelled exactly as it '
                    'appears in the table. Just the word.',
                nullable: false,
              ),
            ),
```

Then update that schema's `requiredProperties` (currently line 65) to include the new field:

```dart
          requiredProperties: ['options', 'answer', 'sentence', 'usedGreenWords'],
```

- [ ] **Step 2: Add the prompt instruction**

In `lib/chat/prompt_setter.dart`, in `questionPrompt`, extend the workflow block. Change the end of rule 5 to add a rule 6 — replace the final line of the here-string (currently ending at rule 5) so the block reads:

```dart
5. Exactly one choice may fit the blank: the other three choices must be clearly wrong in this sentence, either by meaning or by usage.
6. List in "usedGreenWords" every green word from the table above that you actually used to construct the sentence, spelled exactly as it appears in the table. If you used no green words, return an empty array.""",
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: No new errors or warnings from `gemini_repository.dart` or `prompt_setter.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/chat/gemini_repository.dart lib/chat/prompt_setter.dart
git commit -m "feat: report used green words in question schema and prompt"
```

---

### Task 4: Capture green words and apply cooldown during review

Wire it together: parse `usedGreenWords` when the question is generated, then cool every used word (options + green words) during review, after global decay and before mastery adjustment.

**Files:**
- Modify: `lib/chat/chat_viewmodel.dart` (new field ~line 36; parse in `startQuestion` ~line 153; apply in `_userResponse` ~line 100)

**Interfaces:**
- Consumes: `VocabularyViewmodel.applyCooldownForUsedWords(List<String>)` (Task 2); question JSON `usedGreenWords` (Task 3); existing `_options` (`List<Option>` with `.word`).
- Produces: no new public interface; behavior change only.

- [ ] **Step 1: Add the field to hold parsed green words**

In `lib/chat/chat_viewmodel.dart`, next to the other llm-response fields (after `List<String> _unfamiliarWords = [];` at line 22, or beside `_reviewItems`), add:

```dart
  List<String> _usedGreenWords = [];
```

- [ ] **Step 2: Parse `usedGreenWords` in `startQuestion`**

In `startQuestion`, right after the `_correctLabel = map['answer'] as String;` line (line 153), add:

```dart
        _usedGreenWords = ((map['usedGreenWords'] as List?) ?? const [])
            .map((e) => e as String)
            .toList();
```

- [ ] **Step 3: Apply cooldown for used words in `_userResponse`**

In `_userResponse`, the existing call `_vocabularyViewModel.decreaseCooldown();` is at line 100. Immediately AFTER it (and before the `updateMemoryState` call), insert:

```dart
    final List<String> usedWords = [
      ..._options.map((option) => option.word),
      ..._usedGreenWords,
    ];
    _vocabularyViewModel.applyCooldownForUsedWords(usedWords);
```

Order matters: decay (`decreaseCooldown`) runs first, then used-word cooldown, then `updateMemoryState`'s adjustment overwrites the answer/unfamiliar words with their new-state cooldown.

- [ ] **Step 4: Verify it compiles and existing tests still pass**

Run: `flutter analyze`
Expected: no new errors.

Run: `flutter test`
Expected: PASS (all existing tests plus Tasks 1–2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/chat/chat_viewmodel.dart
git commit -m "feat: cool down option and green words during review"
```

---

### Task 5: Manual end-to-end verification

Confirm the behavior against the running app, since the LLM-reported green words can only be exercised live.

**Files:** none (verification only).

- [ ] **Step 1: Run the app**

Run: `flutter run -d windows` (requires a valid Gemini API key configured in Settings).

- [ ] **Step 2: Drive one full question cycle**

Generate a question, answer it, and reach the review screen.

- [ ] **Step 3: Inspect the vocabulary panel**

Expected: after review, the words shown as the 4 options AND the green words used in the sentence now have `cooldown > 0` (visible via the vocabulary database pane / `vocabulary.xlsx`). Their `level` for non-answered words is unchanged. The correct-answer word's cooldown reflects its post-adjustment state.

- [ ] **Step 4: Confirm rotation**

Generate several more questions. Expected: recently-used option/green words do not immediately reappear (they are filtered out by `QuestionVocabFilter` while `cooldown > 0`).

---

## Self-Review Notes

- **Spec coverage:** cooldown-on-use decoupled from adjustment (Tasks 1–2); hybrid detection — options local + green LLM-reported+validated (Tasks 3–4, validation is the DB-membership check inside `applyCooldownForUsedWords`); timing after decay / before adjustment (Task 4 Step 3); tests (Tasks 1–2) and manual E2E (Task 5). All spec sections mapped.
- **Type consistency:** `applyCooldownForUsedWords(List<Vocab>, Set<String>)` in domain vs `applyCooldownForUsedWords(List<String>)` in VM — deliberately different signatures (VM converts `List`→`Set` via `.toSet()`); names intentionally shared across layers as with `decreaseCooldown`. `Option.word` and `Vocab.copyWith(cooldown:)` match the model definitions.
- **Placeholders:** none; every code step shows complete code.
