# Design: Program-driven question-word scheduler with novel-word expansion

**Date:** 2026-07-15
**Status:** Approved

## Problem

After the `nextDueRound` refactor, `QuestionVocabSelector.filter(vocabulary, currentRound)`
returns *all* due words and shuffles them; `PromptSetter.questionPrompt` hands Gemini a
`word | mean | level` table and lets **Gemini decide everything** — which red/yellow words
become the four choices, which one is correct, its A/B/C/D position, and how the sentence is
built from green words. The program exerts no control over *which* word gets tested.

In spaced-repetition terms the **correct-answer word** is the one actually reviewed: only it
receives an upgrade/downgrade from correctness; the distractors are merely rescheduled. So the
program should decide the correct-answer word — the most overdue one — rather than leaving it
to the model.

## Goal

Make the program choose the correct-answer word deterministically from overdueness
(`currentRound - nextDueRound`), while keeping Gemini responsible for what it is good at:
building a natural sentence with exactly one fitting choice, inventing confusable distractors,
and randomizing positions. When nothing is due, fall through to a **novel-word expansion mode**
that grows the vocabulary instead of stalling.

## Selection state machine (at question generation)

Compute the **due red/yellow** set: words whose `level` is red or yellow **and**
`nextDueRound <= currentRound`.

- **Non-empty → normal mode.** Answer word = the one maximizing `currentRound - nextDueRound`
  (most overdue); ties broken by a random pick among the tied maximum. The program passes the
  answer word plus candidate pools to Gemini (Approach A below).
- **Empty → novel mode.** No red/yellow word is due (small pool all resting, only green words,
  or an empty database). Gemini generates a fresh TOEIC Part 5 question from new vocabulary,
  unconstrained by the database. Words the user gets wrong or flags as unfamiliar enter the
  database as red words through the existing adjustment flow.

The due gate is retained **not** as a blocker but as the switch between the two modes.

### Why novel mode resolves the small-pool problem

A novel question still increments `currentRound` when answered, so resting red/yellow words
eventually reach their due round and re-enter normal review — no deadlock, no forced immediate
repetition of a single word. A brand-new or tiny database bootstraps itself: wrong/unfamiliar
novel words are added as red, giving future rounds real words to schedule. An empty database
also lands here, giving a new user real questions from the first tap.

## Approach A — program fixes the answer, Gemini assembles

Considered and rejected: **Approach B**, where the program also picks the three distractors and
assigns positions, leaving Gemini only to write the sentence. B risks invalid questions — the
program cannot judge whether a distractor also fits the blank, and TOEIC's "exactly one choice
fits" rule requires understanding the sentence, which only the model has. A keeps that judgment
with the model.

Under A:

- **Prompt (`PromptSetter.questionPrompt(answer, distractorPool, greenPool)`):** state that the
  correct answer **must** be `answer.word` (with its meaning); ask Gemini to build a sentence
  only that word fits, choose three distractors (preferring the distractor pool, inventing
  plausible TOEIC-level ones only if the pool is short), place the four options in a random
  A/B/C/D order, and set `answer` to the key holding the correct word.
- **Candidate pools (no due gate, full database):** distractor pool = all red/yellow words
  except the answer; green pool = all green words. Each is shuffled before being written into
  the prompt to avoid positional bias.
- **Response schema is unchanged** (`options{A,B,C,D}, answer, sentence, usedGreenWords`).
- **Deriving the verdict:** `ChatViewModel` locates the answer word among the returned options
  (case-insensitive) via a pure helper `resolveAnswerLabel(options, answerWord)` and uses that
  key as `_correctLabel` — it does **not** trust Gemini's `answer` field in normal mode. If the
  answer word is absent from the options (Gemini disobeyed), throw to trigger the existing
  `RetryHandler` retry.

## Novel mode

- **Prompt (`PromptSetter.novelQuestionPrompt()`):** ask Gemini to generate one TOEIC Part 5
  question from common TOEIC vocabulary not tied to any provided list, with four confusable
  choices, one correct, random positions, and an empty `usedGreenWords`. (No attempt is made to
  exclude words already in the database; incidental overlap is harmless.)
- **Deriving the verdict:** the program has no pre-chosen word, so `_correctLabel` comes from
  Gemini's `answer` field (today's behavior).
- **Words entering the database:** handled by the existing review → `handleVocabAdjustment`
  path. See the adjustment change below.

## Adjustment change — do not add correctly-answered novel words

`VocabularyViewmodel.handleVocabAdjustment` (`lib/vocabulary/vocabulary_viewmodel.dart:106`)
adds *any* unknown word as red without checking the adjustment direction — its `else` branch
has a standing `//TODO: filter those upgrade adjustment not to add in database`. This is a
latent bug: **today** the only unknown words that reach the `else` branch are unfamiliar-flagged
words, which are always downgrades (the correct-answer word is always a database word, so it
takes the `if` branch), so in practice only downgrades ever add a word. Novel mode changes that
— a correctly-answered novel word is unknown *and* an upgrade, and would be wrongly added as
red. Implement the TODO now: an unknown word is added as a red word **only on downgrade**
(answered wrong or flagged unfamiliar); an unknown word with an upgrade adjustment is ignored.
Normal mode is unaffected (its answer word already exists in the database). This keeps the
database from filling with words the user already knows.

## Components (isolation)

- `QuestionVocabSelector`
  - `pickAnswerWord(vocabulary, currentRound, {Random?}) -> Vocab?` — most overdue due
    red/yellow word, random tiebreak; `null` signals novel mode. Pure.
  - `distractorPool(vocabulary, answer) -> List<Vocab>` and `greenPool(vocabulary) -> List<Vocab>`.
    Pure. `shuffle` (existing) orders the pools.
  - `resolveAnswerLabel(options, answerWord) -> String?` — case-insensitive lookup of the
    option key holding the answer word. Pure.
  - The old `filter(vocabulary, currentRound)` (all due words) is superseded and removed with its
    tests; the due check now lives inside `pickAnswerWord`.
- `PromptSetter` — `questionPrompt(answer, distractorPool, greenPool)` and
  `novelQuestionPrompt()`. Both emit the same schema.
- `ChatViewModel._generateQuestion` — branch on `pickAnswerWord`; remember the chosen word for
  normal-mode label resolution; fall back to Gemini's `answer` in novel mode.
- `VocabularyViewmodel.handleVocabAdjustment` — add-on-downgrade-only.
- `GeminiRepository` — unchanged.

## Testing (TDD; Fake pattern, no mocking library)

- `pickAnswerWord`: picks max overdueness among due red/yellow; ignores green; random tiebreak
  (seeded `Random`); a strictly-maximum word is always chosen; **all red/yellow resting
  (`nextDueRound > currentRound`) → returns `null`** even though red/yellow words exist; empty
  db → `null`; overdueness may be negative but such words are excluded by the due gate.
- `distractorPool` / `greenPool`: correct level partitioning; distractor pool excludes the
  answer; no due-gate applied.
- `resolveAnswerLabel`: finds the key at any position, case-insensitively; `null` when the word
  is absent.
- `handleVocabAdjustment`: existing word upgrades/downgrades via `applyVocabAdjustment`; unknown
  word + downgrade adds a red word; **unknown word + upgrade adds nothing** (new behavior).
- End-to-end (verify skill, Windows): with a database that has a clearly-most-overdue red word,
  confirm the generated question's correct answer is exactly that word and that answering it
  upgrades/downgrades it. Drain the due set (or start from a green-only/empty db) to confirm
  novel mode produces a question and that a wrong novel answer enters the database as red while a
  correct one does not.

## Out of scope

Excluding existing database words from novel questions; changing distractor rescheduling
(`applyDueForUsedWords` still reschedules all option words); any change to the review or
function-calling models.
