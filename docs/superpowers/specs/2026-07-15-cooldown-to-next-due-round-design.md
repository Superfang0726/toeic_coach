# Design: `cooldown` countdown → `nextDueRound` due-round scheduling

**Date:** 2026-07-15
**Status:** Approved

## Problem

Each `Vocab` carried a `cooldown` counter: after every answered question, **all**
words were decremented (`VocabDomain.decreaseCooldown`), used words were reset to
`inferCooldown(memoryState)`, and `QuestionVocabSelector.filter` picked words with
`cooldown == 0`. This loses "how overdue is this word" the moment cooldown hits 0
and mutates every word on every question.

## Goal

Replace the global countdown with a due-date mechanism:

- A persisted global round counter `currentRound` (+1 per answered question).
- Per-word `nextDueRound`: the absolute round at which the word becomes eligible.
- Eligibility: `nextDueRound <= currentRound`.

**Behavior-equivalent refactor** — question selection results are identical before
and after. It paves the way for a future scheduler ("pick the most overdue word as
the answer", overdueness = `currentRound - nextDueRound`), which is explicitly out
of scope here.

## Decisions

1. **Scheme: global round + absolute due round.** `currentRound` lives in
   `SharedPreferencesRepository` (key `'round'`, default 0) and is hydrated into
   `Store` (`_currentRound` + `updateRoundStore`) during the synchronous bootstrap
   in `main.dart`. Per-word `nextDueRound` replaces the `cooldown` column in
   Excel.
   *Rejected alternative:* a per-word relative counter (+1 for every word each
   round, eligible at >= 0, migrate as `-cooldown`). Zero new wiring, but it keeps
   the O(N) all-words mutation per question — the mechanism this refactor removes.
2. **Excel migration is numerically a no-op.** Legacy files (header `'cooldown'`,
   value C) are exact under the new reading: they predate round persistence, so
   `currentRound` starts at 0 and `nextDueRound = 0 + C = C`. Read code is
   uniform (no header branch); `writeExcel` writes the new header
   `'nextDueRound'`, upgrading files on their first write.
3. **Wiring.** `VocabularyViewmodel` gains a third constructor dependency,
   `SharedPreferencesRepository`; `incrementRound()` updates the `Store` then
   fire-and-forgets `writeRound`.
4. **Renames.** `inferCooldown` → `inferInterval`, `applyCooldownForUsedWords` →
   `applyDueForUsedWords` (domain + viewmodel), `VocabularyViewmodel.decreaseCooldown`
   → `incrementRound`, `VocabDomain.decreaseCooldown` deleted.
5. **Ordering (equivalence proof).** In `ChatViewModel._userResponse`, the round
   is incremented **before** used words are scheduled: old behavior gave a used
   word `cooldown = I`, eligible after I more answered questions; new behavior
   gives `nextDueRound = (R+1) + I`, eligible once the round has advanced I more
   times. Identical. Scheduling before incrementing would be off by one.

Interval values are unchanged: redLow=2, redMedium=3, redHigh=5,
yellowLow/High=7, green=2.

## Overflow

Not a practical concern: Dart ints are 64-bit on desktop; +1 per answered
question can't approach the limit on human timescales, and both SharedPreferences
(`setInt`) and Excel (`IntCellValue`, 15 significant digits) hold the values
comfortably. No rebasing needed.
