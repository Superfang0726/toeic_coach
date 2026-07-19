# Design: Per-option "unfamiliar" toggle with forced downgrade

**Date:** 2026-07-19
**Status:** Approved

## Problem

The chat feature already lets the user flag individual *sentence* words as unfamiliar
(`ChatViewModel.toggleUnfamiliarWord`, driven by tapping a `_WordToken`). There is no equivalent
for the four answer **options** (A/B/C/D) themselves. A user who is genuinely unsure about an
option's word today has no way to record that uncertainty — if they guess it and happen to be
right, the word gets upgraded as if they actually knew it, silently corrupting the mastery
tracking.

## Goal

Let the user mark any option as "unfamiliar" (guessing), independent of which option they
select as their final answer. On submit, every option flagged unfamiliar is downgraded — even
if it is the correct answer and even if it is not the one submitted. Marking the correct answer
unfamiliar must override the normal "correct → upgrade" outcome.

## Interaction model

Each option card carries two independent boolean states:

- **Selected** (existing) — left click / `toggleOption`. Exactly one option can be selected;
  determines what gets submitted and scored.
- **Unfamiliar** (new) — right click / `toggleOptionUnfamiliar`. Any number of options can be
  flagged, independent of selection. An option can be selected, flagged, both, or neither.

These are orthogonal on purpose: flagging is about *word familiarity*, selection is about *what
you're answering*. Fusing them (e.g. "flagging also selects") would prevent the exact scenario
that motivated this feature — guessing an option you don't actually know.

## Downgrade rule

On submit, **every** option flagged unfamiliar is downgraded, regardless of whether it was
selected and regardless of correctness. This matches the existing sentence-unfamiliar-word rule
(`PromptSetter.reviewPrompt` already downgrades every flagged sentence word unconditionally) —
one consistent rule, no special-casing based on selection.

Concretely, for the correct-answer option:

```
correctAdjustment = (isCorrect && !unfamiliarOptionWords.contains(correctAnswer.word))
    ? 'upgrade'
    : 'downgrade'
```

This is computed in Dart, not left to the review model to infer — matching the existing pattern
where `isCorrect` is precomputed and stated as given fact ("Correctness is already determined
above, do not re-judge it"). The model is told the resolved outcome, never asked to resolve the
conflict itself.

Every other option flagged unfamiliar (i.e. `unfamiliarOptionWords` minus `correctAnswer.word`)
gets an explicit, separate "record downgrade" instruction. This is intentionally a **different**
prompt block from the existing sentence-unfamiliar-word block: sentence words are explained "as
used in the sentence," but option words (especially distractors) are not necessarily used in the
sentence at all, so they get their own explain-then-downgrade phrasing.

## State (`ChatViewModel`)

- New `List<String> _unfamiliarOptionWords` (mirrors `_unfamiliarWords`'s shape — a list of
  words, not labels), exposed via `unfamiliarOptionWords` getter.
- Reset to `[]` in `startQuestion()` alongside the existing `_unfamiliarWords` reset.
- New method, mirroring `toggleUnfamiliarWord` exactly:

```dart
void toggleOptionUnfamiliar(Option option) {
  if (_unfamiliarOptionWords.contains(option.word)) {
    _unfamiliarOptionWords.remove(option.word);
  } else {
    _unfamiliarOptionWords.add(option.word);
  }
  notifyListeners();
}
```

- `submitAnswer()` passes `_unfamiliarOptionWords` through `_userResponse(...)` into
  `PromptSetter.reviewPrompt(...)`, alongside the existing `unfamiliarWords` argument.

## Review prompt (`PromptSetter.reviewPrompt`)

New signature:

```dart
static String reviewPrompt(
  Option userAnswer,
  Option correctAnswer,
  bool isCorrect,
  List<String> unfamiliarWords,
  List<String> unfamiliarOptionWords,
)
```

Behavior:

1. State the correct answer and the user's answer/correctness as today.
2. If `unfamiliarWords` (sentence words) is non-empty, list them as today.
3. If `unfamiliarOptionWords` minus `correctAnswer.word` is non-empty, list those separately
   under their own heading (e.g. "User also marked these answer options as unfamiliar:").
4. In the goal/workflow section, compute `correctAdjustment` as above and record it for
   `correctAnswer.word` — if the override fired (flagged-but-correct), say so explicitly so the
   model states it as fact rather than re-deriving it.
5. If sentence-unfamiliar words exist: keep the existing "explain as used in the sentence, then
   record downgrade for each" block, unchanged.
6. If unfamiliar option words (excluding the correct answer) exist: add a new block —
   "explain what each unfamiliar option word means, then record an entry with adjustment
   'downgrade' in memoryStateUpdateResult for every word in that list" — worded without "as used
   in the sentence," since distractor words are not necessarily used there.

Step numbers are generated dynamically (a running counter) rather than hardcoded, since which
blocks appear depends on which lists are non-empty.

No other model (`generateQuestionModel`, `updateMemoryStateModel`) changes. The function-calling
model still reads `memoryStateUpdateResult` from history exactly as today — it does not need to
know *why* an entry says downgrade.

## UI (`chat_ui.dart`)

- `_buildOptionCard` adds `onSecondaryTap: () => _chatViewModel.toggleOptionUnfamiliar(option)`
  to its `GestureDetector`.
- Visual treatment keeps selection's existing look (tinted background, `kPrimary` border,
  trailing checkmark) untouched. "Unfamiliar" gets its own independent signal — a small
  warning-colored badge icon overlaid on the card via `Stack` — so both states are visible at
  once without fighting over the same border/background color.
- A `Tooltip` wraps the option card with a hint (e.g. "右鍵標記為不熟悉單字"), since right-click
  has no other affordance in the UI.
- The review view (`_buildReviewView`) needs no changes — it already renders whatever
  `memoryStateAdjustment` entries come back, regardless of why they were downgraded.

## Components touched

- `lib/chat/chat_viewmodel.dart` — new state field, getter, toggle method; thread the new list
  through `submitAnswer` → `_userResponse` → `PromptSetter.reviewPrompt`.
- `lib/chat/prompt_setter.dart` — `reviewPrompt` signature and body per above.
- `lib/chat/chat_ui.dart` — right-click handler, badge visual, tooltip on the option card.

No changes to `Option`, `Vocab`, `VocabAdjustment`, `VocabularyViewmodel`, `GeminiRepository`, or
the question-generation path.

## Testing (TDD; Fake pattern, no mocking library)

- `PromptSetter.reviewPrompt` (`test/prompt_setter_test.dart`, currently only covers
  `questionPrompt`/`novelQuestionPrompt` — new test group needed):
  - No flags: output unchanged from today (upgrade on correct, downgrade on wrong; no option
    block).
  - Correct answer flagged unfamiliar + `isCorrect == true` → records `downgrade` for
    `correctAnswer.word`, not `upgrade`; prompt explicitly notes the override.
  - Correct answer flagged unfamiliar + `isCorrect == false` → still `downgrade` (no behavior
    change, already the outcome).
  - A non-correct option flagged unfamiliar → separate block appears, instructs a downgrade
    entry for that word, does not duplicate/conflict with the correct-answer instruction.
  - Both sentence-unfamiliar-words and option-unfamiliar-words present → both blocks appear,
    independently, no overlap even if (edge case, shouldn't occur structurally) the same word
    were in both lists.
- `ChatViewModel` — no automated unit test for the toggle itself: `GeminiRepository` is
  constructed directly inside `ChatViewModel` rather than injected, so it cannot be faked without
  a DI refactor that is out of scope here (this is also why no `chat_viewmodel_test.dart` exists
  today). `toggleOptionUnfamiliar`/reset behavior is covered by the end-to-end pass below instead.
- End-to-end (`verify` skill, Windows): flag the correct option unfamiliar, answer it correctly,
  submit, and confirm the review shows a downgrade (not upgrade) for that word. Flag a
  non-selected distractor unfamiliar, submit any answer, confirm it is downgraded too. Confirm
  right-click does not alter `selectedOption` and left-click does not alter unfamiliar flags.

## Out of scope

Any change to how the sentence-word unfamiliar toggle works today; any change to how the correct
answer is chosen or scheduled; touching `updateMemoryStateModel` or its function-calling schema;
mobile/touch input (right-click has no touch equivalent, but this app targets desktop per
CLAUDE.md).
