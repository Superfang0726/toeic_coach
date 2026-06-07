# Spec: Constrain question `options` to exactly four words via object schema

## Problem Statement

`_generateQuestionModel` in [lib/chat/gemini_repository.dart](lib/chat/gemini_repository.dart) declares the answer choices as `Schema.array(items: Schema.string(...))`. A JSON-schema array has no fixed length, so the language model is free to emit the wrong number of items. In practice it has produced **six** options with the last two being garbage (e.g. `"D. D."`), which breaks the question UI and feeds nonsense words into the review/memory-state cycle. There is no way to express "exactly 4" with an array, so the only robust fix is to change the shape of the response.

A secondary smell: the model is asked to embed the label inside each string (`"<label>. <word>"`), then the ViewModel splits the string back apart on `". "` ([chat_viewmodel.dart:110-113](lib/chat/chat_viewmodel.dart)). This is fragile — any word containing `". "` or a missing label corrupts the parse — and the label is presentation, not data.

## Goals

1. The question-generation schema **structurally guarantees exactly four answer choices** — A, B, C, and D — so the "6 options / `D. D.`" class of failure becomes impossible to represent.
2. The model returns **only the word** for each choice; labels (A/B/C/D) are owned entirely by the presentation layer in [chat_ui.dart](lib/chat/chat_ui.dart).
3. The change is **schema + parsing only** — the downstream domain logic, review cycle, and UI rendering of options continue to work unchanged (the `Option {label, word}` shape the rest of the app consumes is preserved).

## Non-Goals

- **Changing the review or memory-state schemas** (`_reviewUserAnswerModel`, `_updateMemoryStateModel`). Out of scope — this spec is only about question generation. The `memoryStateUpdateResult` array length problem, if any, is a separate concern.
- **Validation / retry logic for malformed model output.** The object schema removes the count problem at the source; building a fallback validator is a separate hardening task (see Open Questions).
- **Redesigning the `Option` model or the option-card UI.** `Option {label, word}` and `_optionCard` stay as-is; only how `Option`s are constructed changes.
- **Localizing or restyling option text.** No visual change is intended — A/B/C/D badges already render from `option.label`.

## Proposed Change

### 1. Schema — wrap four named strings in an object

Replace the `'options'` property (currently `Schema.array`) with a `Schema.object` whose four properties are keyed `A`, `B`, `C`, `D`, each a required `Schema.string`.

**Design choice (per spec review): never introduce the concept of a "label" in the schema or the prompt.** The A/B/C/D keys already structure the four choices, and the badge is rendered client-side from the key. If the schema never mentions a label, the model has no reason to emit `"A. "` — so rather than *negatively* instructing "no label / no punctuation," each description *positively* describes what a good choice is: a single vocabulary word that is a plausible fit for the blank and carries grammatical/semantic distractor value. This both removes the failure mode and keeps the description focused on answer quality.

Sketch (final wording to be refined during implementation):

```dart
'options': Schema.object(
  properties: {
    'A': Schema.string(
      description:
          'A single vocabulary word that is a candidate answer for the blank — '
          'grammatically plausible and semantically confusable with the other '
          'choices. Just the word.',
      nullable: false,
    ),
    'B': Schema.string(description: 'A single vocabulary word that is a candidate answer for the blank — grammatically plausible and semantically confusable with the other choices. Just the word.', nullable: false),
    'C': Schema.string(description: 'A single vocabulary word that is a candidate answer for the blank — grammatically plausible and semantically confusable with the other choices. Just the word.', nullable: false),
    'D': Schema.string(description: 'A single vocabulary word that is a candidate answer for the blank — grammatically plausible and semantically confusable with the other choices. Just the word.', nullable: false),
  },
  requiredProperties: ['A', 'B', 'C', 'D'],
),
```

Note the descriptions say nothing about labels, prefixes, or punctuation — they describe a single word and what makes it a good distractor. The "label" vocabulary is deliberately absent from the model's instructions entirely.

### 2. `answer` field — `enumString` over the option keys (decided)

`answer` is currently `"<label>. <word>"`. It becomes a **`Schema.enumString(enumValues: ['A','B','C','D'])`** — the key of the correct choice. The description should state it is the key of the correct option among A/B/C/D, again without invoking the word "label." This field is **not currently parsed by `ChatViewModel`** (the review model relies on chat history), so it has no direct consumer today, but the enum keeps the response internally consistent and ready for future use.

```dart
'answer': Schema.enumString(
  enumValues: ['A', 'B', 'C', 'D'],
  description: 'The key of the correct choice for the blank.',
  nullable: false,
),
```

### 3. Parsing — build `Option`s from the object

In [chat_viewmodel.dart:110-113](lib/chat/chat_viewmodel.dart), replace the array-split logic:

```dart
// before
_options = (map['options'] as List).map((e) {
  final parts = (e as String).split('. ');
  return Option(label: parts[0], word: parts[1]);
}).toList();

// after — iterate the fixed A/B/C/D keys
final opts = map['options'] as Map<String, dynamic>;
_options = ['A', 'B', 'C', 'D']
    .map((k) => Option(label: k, word: opts[k] as String))
    .toList();
```

The label is now synthesized client-side from the key; `Option.word` holds the bare word the model returned. `chat_ui.dart` already renders `option.label` (badge) and `option.word` (text) separately, so **no UI change is required**.

### 4. Prompt text consistency (`prompt_setter.dart`)

`questionPrompt` does not currently reference the `"<label>. <word>"` format, so it likely needs no change — but verify the workflow wording still matches an object-of-four-words output. `reviewPrompt` builds `"User's answer is ${userAnswer.label}. ${userAnswer.word}"` from the `Option`, which still holds both fields, so it continues to work unchanged.

## Requirements

### Must-Have (P0)

- **P0.1** — `options` in the question schema is a `Schema.object` with exactly four required string properties keyed `A`, `B`, `C`, `D`.
  - Given the question model runs, when it returns, then the parsed result always contains exactly four options keyed A–D — never five, six, or a duplicated/garbage entry.
- **P0.2** — Each option value is a single word. Neither the schema descriptions nor any prompt mention "label," prefixes, or punctuation — the descriptions only describe a good single-word distractor.
  - Given a generated question, when an option is rendered, then `option.word` is the bare vocabulary word and `option.label` is the client-supplied A/B/C/D.
- **P0.3** — `ChatViewModel.startQuestion` parses the object form and builds four `Option`s without string-splitting.
  - Given a valid model response, when parsed, then no `". "`-split logic remains and `_options.length == 4`.
- **P0.4** — `answer` is a `Schema.enumString(['A','B','C','D'])` returning the correct option key.
- **P0.5** — The existing question → submit → review → memory-state flow still completes end-to-end with the new schema (no regression in review or adjustment behavior).

### Nice-to-Have (P1)

- _None._ Earlier candidates (label-trim defense, label-aware descriptions) were dropped — the decision to keep the word "label" out of the model's instructions entirely makes them unnecessary.

### Future Considerations (P2)

- **P2.1** — Apply the same "object of fixed keys" pattern to any other place that currently relies on a length-sensitive `Schema.array`.
- **P2.2** — Centralized parse-and-validate for model JSON so malformed responses surface a clean user-facing error instead of throwing in `jsonDecode`/cast.

## Open Questions

- **(eng)** Keys are assumed uppercase `A`–`D`. Confirm nothing compares them case-sensitively elsewhere. The UI badge renders whatever `label` we set, so this is an internal convention only.
- **(eng / resolved)** `answer` representation → **decided: `enumString` over the option keys** (P0.4).
- **(eng / resolved)** Whether to mention "no label" in the schema → **decided: do not mention labels at all**; describe options positively as single-word distractors (P0.2).

## Acceptance Criteria (checklist)

- [ ] `options` schema is an object with required keys `A`, `B`, `C`, `D`, all `Schema.string`.
- [ ] Each option `description` describes a single-word distractor and never mentions "label," prefix, or punctuation.
- [ ] `answer` is a `Schema.enumString(['A','B','C','D'])`.
- [ ] `ChatViewModel.startQuestion` reads `map['options']` as a map and builds `Option(label: key, word: value)` for A–D.
- [ ] No `split('. ')` remains in the options parse path.
- [ ] Generated questions render four option cards with correct A/B/C/D badges and bare words.
- [ ] A full answer-and-review cycle runs without error.
- [ ] `flutter analyze` is clean for the touched files.

## Timeline / Dependencies

Small, self-contained change touching three files: [gemini_repository.dart](lib/chat/gemini_repository.dart) (schema), [chat_viewmodel.dart](lib/chat/chat_viewmodel.dart) (parse), and a verification pass on [prompt_setter.dart](lib/chat/prompt_setter.dart). No external dependencies. Single PR; manual smoke test (generate a few questions) is the main validation since there is no test suite yet.
