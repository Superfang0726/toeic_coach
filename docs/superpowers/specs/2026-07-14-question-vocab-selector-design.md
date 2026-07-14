# Question Vocab Selector: Shuffle + Domain Consolidation

## Problem

`ChatViewModel._generateQuestion` builds the question prompt directly from
`QuestionVocabFilter.filter(_store.vocabulary)`'s output. Because `Store.vocabulary`
is read from Excel in a fixed order and never reshuffled, the filtered list handed to
`PromptSetter.questionPrompt` has the same relative ordering every time. This biases
which words Gemini tends to pick for answer choices / sentence-building toward
whatever order they happen to sit in the spreadsheet.

Separately: `question_vocab_filter.dart` (`lib/chat/`) is a single-purpose,
untested one-liner class. Now that a second pure function (`shuffle`) is being added
alongside it, it's worth deciding where "pure functions that operate on
`List<Vocab>`" should live going forward.

## Decision: keep chat-specific vocab selection logic in `lib/chat/`

The project's only existing domain file, `VocabDomain` (`lib/vocabulary/vocab_domain.dart`),
holds pure functions describing a `Vocab`'s own mastery-state lifecycle
(`upgrade`, `downgrade`, `inferLevel`, `inferCooldown`, `applyCooldownForUsedWords`,
`canonicalizeWord`). These describe how a word evolves, independent of which feature
triggers the change — `chat_viewmodel.dart` already calls `VocabDomain.canonicalizeWord`
directly, confirming cross-feature calls into this domain are an accepted pattern.

Filtering-by-cooldown and shuffling, by contrast, describe how **chat specifically**
prepares a vocab list right before handing it to `PromptSetter` — a concern owned by
the chat feature's question-generation flow, not by the `Vocab` entity's own lifecycle.
CLAUDE.md's stated layering (`UI → ViewModel → Repository → external`, one
UI/ViewModel/Repository set per feature folder) doesn't mandate a single shared domain
file, and no such rule is broken either way — this is a cohesion choice, not a layering
one. Given the two function groups answer different questions ("what should this word
become" vs. "what subset/order feeds today's question"), they're kept in separate files.

**Outcome:** rename `lib/chat/question_vocab_filter.dart` →
`lib/chat/question_vocab_selector.dart`, class `QuestionVocabFilter` →
`QuestionVocabSelector`, and add `shuffle` there rather than merging into
`VocabDomain`.

## Design

### `lib/chat/question_vocab_selector.dart`

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

- `shuffle` returns a new list; it does not mutate the list passed in, matching the
  immutable style of `vocab_domain.dart`'s functions (`copyWith`-based, no in-place
  mutation).
- `random` is optional, mirroring Dart's own `List.shuffle(Random?)` signature. Callers
  in production omit it; tests inject a seeded `Random` to get a deterministic,
  assertable order instead of relying on flaky repeated-run checks.

### `lib/chat/chat_viewmodel.dart`

`_generateQuestion` filters, then shuffles, before building the prompt:

```dart
List<Vocab> filteredVocabulary = QuestionVocabSelector.filter(_store.vocabulary);
filteredVocabulary = QuestionVocabSelector.shuffle(filteredVocabulary);
String prompt = PromptSetter.questionPrompt(filteredVocabulary);
```

The `import 'package:toeic_coach/chat/question_vocab_filter.dart';` line updates to the
new file path and class name.

### Documentation

`CLAUDE.md`'s domain-logic section currently reads:

> `PromptSetter.questionPrompt` (in `lib/chat/`) tells Gemini to use **red/yellow**
> words as the answer choices and **green** (known) words to build the sentence.
> `QuestionVocabFilter.filter` (also in `lib/chat/`) selects only words with
> `cooldown == 0` before passing them into the prompt.

Update to reference `QuestionVocabSelector` and mention that the filtered list is
shuffled before being handed to `PromptSetter`.

### Testing

New `test/question_vocab_selector_test.dart`, following the existing pure-function test
style (see `test/vocab_domain_test.dart` — no mocking library, direct static-method
calls):

- `filter`: excludes words with `cooldown > 0`, keeps `cooldown == 0` words, preserves
  order of the words it keeps.
- `shuffle`: with a seeded `Random`, asserts the result is a permutation of the input
  (same multiset of words) and that it does not mutate the original list (original list
  reference still has its original order after the call).

No `chat_viewmodel_test.dart` exists in `test/` currently, so no other test file needs
updating.

## Out of scope

- No change to `PromptSetter` or the prompt content itself.
- No change to how `green` words used in the sentence are chosen — this only affects
  the list passed in for red/yellow answer-choice selection.
- No change to `cooldown` semantics or `VocabDomain`.
