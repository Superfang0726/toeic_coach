# Cool down every word used in a question

**Date:** 2026-07-12
**Status:** Approved, ready for implementation plan

## Problem

The app intends that once a vocabulary word is *used* in a generated question, it
enters a cooldown period in the database so it is not immediately reused, letting
the drill rotate across the whole vocabulary.

Today that only partially happens. Cooldown is set **only as a side-effect** of
`VocabularyViewmodel.applyVocabAdjustment` → `VocabDomain.inferCooldown(newMemoryState)`,
which runs only for words present in the review model's `memoryStateUpdateResult`
— i.e. the **correct answer word** and any **unfamiliar words** the user flagged.

Everything else that a question consumes never cools down and can reappear
immediately:

- the **wrong distractor options** (including the user's wrong pick),
- the **green words** used to construct the sentence.

There is also no mechanism to cool a word down *without* also changing its
`memoryState`/`level`, which is required for distractors and green words.

## Goal

When a question is produced, **every database word it used** — all 4 option words
plus the green sentence-construction words — enters cooldown, without altering the
mastery (`memoryState`/`level`) of words that were merely used rather than answered.

## Non-goals

- No change to mastery adjustment logic (upgrade/downgrade, `inferLevel`).
- No change to the review model or the function-calling (`updateMemoryState`) model.
- No change to the Excel schema — the `cooldown` column already exists.
- No English lemmatizer / stemmer is introduced.

## Approach: hybrid detection

"Used words" come from two sources with different reliability, handled accordingly:

- **Option words — reliable, matched locally.** The 4 parsed `_options` are already
  canonicalized to DB spelling (`VocabDomain.canonicalizeWord`). LLM-invented
  distractors (used when fewer than 4 red/yellow words exist) simply won't match the
  DB and are skipped.
- **Green sentence words — LLM-reported, validated locally.** The LLM constructs the
  sentence freely and may inflect words (tense/plural), so local text matching is
  unreliable. Instead the question schema gains a `usedGreenWords: string[]` field in
  which the LLM reports, in the table's canonical spelling, which green words it used.
  The app validates each entry against the DB before cooling, so hallucinated or
  misspelled entries are dropped.

This keeps the deterministic part (options) off the LLM and asks the LLM only for the
part it alone knows (which green lemma it chose), while validation guards against
instability. Because cooldown is a soft rotation mechanism, an occasional missed green
word only means that word reappears slightly sooner — acceptable.

## Design

### 1. Cooldown-on-use, decoupled from adjustment

A new cooldown path rests a word *because it was used*, reusing the existing
`inferCooldown(currentMemoryState)` so a word rests proportionally to its current
mastery band (green → 2, redHigh → 5, etc.). It does **not** touch `memoryState` or
`level`. This mirrors the existing pure-domain / VM-I/O split, with the pure function
as a sibling to the existing `VocabDomain.decreaseCooldown`.

- **`VocabDomain.applyCooldownForUsedWords(List<Vocab> vocabs, Set<String> usedWords)`**
  — pure static. Returns a new list where every vocab whose word (case-insensitive)
  is in `usedWords` has `cooldown = inferCooldown(vocab.memoryState)`; all other
  fields and all other vocabs are unchanged. Words in `usedWords` that are not in the
  DB are ignored.

- **`VocabularyViewmodel.applyCooldownForUsedWords(List<String> words)`**
  — calls the domain function, then writes the result to `Store` + Excel once
  (same pattern as `decreaseCooldown`).

### 2. Schema + prompt

In `lib/chat/gemini_repository.dart`, add to the **question** model's response schema:

```
'usedGreenWords': Schema.array(
  items: Schema.string(
    description: 'A green word from the provided table that was used to build the '
        'sentence, spelled exactly as it appears in the table.',
    nullable: false,
  ),
)
```

Add `'usedGreenWords'` to that schema's `requiredProperties` (empty array is valid
when no green words were used).

In `lib/chat/prompt_setter.dart`, `questionPrompt` gains one workflow step, e.g.:

> 6. List in `usedGreenWords` every green word from the table you used to construct
>    the sentence, spelled exactly as it appears in the table. If you used none,
>    return an empty array.

### 3. Data flow & timing

`ChatViewModel`:

- `startQuestion()` parses `map['usedGreenWords']` into a new field
  `List<String> _usedGreenWords` alongside `_sentence` / `_options`
  (default to `[]` if missing).
- `_userResponse()` applies cooldown-on-use in the existing sequence, ordered so the
  fresh cooldown is not immediately decremented and so adjustment wins for answered
  words:

  1. review call
  2. `decreaseCooldown()` — existing global decay (unchanged)
  3. **NEW:** `applyCooldownForUsedWords(optionWords + _usedGreenWords)`
  4. `updateMemoryState` → `handleVocabAdjustment` — overwrites cooldown for the
     answer / unfamiliar words based on their *new* mastery state

`optionWords` = the `word` of all 4 `_options`. The correct-answer and unfamiliar
words may be set twice (step 3 then step 4); step 4 wins, which is correct. Used words
always had `cooldown == 0` at generation time (the `QuestionVocabFilter` only feeds
`cooldown == 0` words), so there is no double-counting against the decay in step 2.

Applying at submit time (rather than at question generation) keeps every cooldown
mutation in one place and after the global decay.

## Testing

- **Pure domain** — `VocabDomain.applyCooldownForUsedWords`:
  - sets `cooldown` to the band value per `inferCooldown(memoryState)`,
  - matches case-insensitively,
  - ignores words not in the DB,
  - leaves `memoryState` and `level` untouched,
  - leaves non-used vocabs untouched.
- **ViewModel (optional)** — `VocabularyViewmodel.applyCooldownForUsedWords` writes
  the updated list through to the store and Excel repository. Note: no VM test fakes
  for `Store` / `ExcelRepository` exist yet (current tests are all pure-function
  style), so this requires introducing lightweight fakes. Since all real logic lives
  in the pure domain function, this VM test is thin and can be deferred if fakes are
  not worth the cost — the domain test is the primary coverage.
- **Parsing** — a question response containing `usedGreenWords` populates
  `_usedGreenWords`, and an empty / missing array yields `[]`.

## Files touched

- `lib/vocabulary/vocab_domain.dart` — new pure static.
- `lib/vocabulary/vocabulary_viewmodel.dart` — new VM method.
- `lib/chat/gemini_repository.dart` — question schema field.
- `lib/chat/prompt_setter.dart` — one prompt step.
- `lib/chat/chat_viewmodel.dart` — parse `_usedGreenWords`, apply cooldown in `_userResponse`.
- `test/...` — new tests per above.
