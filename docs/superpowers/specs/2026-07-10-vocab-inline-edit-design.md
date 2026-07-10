# Vocabulary Inline Edit — Design

## Goal

Let the user click a `VocabListItem` in the vocabulary database pane to enter an
inline edit mode where **word** and **mean** become editable. While any item is
in edit mode, hovering over other items must **not** reveal their delete icons.

## Scope

- UI-only feature in `lib/vocabulary/database_ui.dart`.
- The data layer is unchanged: reuse the existing
  `VocabularyViewmodel.updateVocab(Vocab)` (updates by `id`, writes back to
  Excel).
- Add widget tests for `VocabListItem`.

## Behavior (agreed decisions)

1. **Inline edit with explicit buttons (approach A).** Clicking a row (anywhere
   except the delete icon) turns its word/mean text into text fields. A ✓ save
   button and a ✗ cancel button appear on the right.
2. **Empty-value validation.** The ✓ save button is disabled while either field
   is empty after trimming — same rule as the existing "Add" button (`_canAdd`).
3. **Keyboard shortcuts.** In a field, **Enter** saves and **Esc** cancels.
4. **One at a time.** While row A is being edited, clicking another row is
   ignored — A stays in edit mode. The user must finish A (✓ or ✗) before
   editing another row.
5. **Layout.** In edit mode: word/mean become two side-by-side text fields
   (reusing the existing outlined input style); the word field autofocuses; the
   memory-state dot is hidden to make room; the left level color strip stays; the
   right side shows ✓ / ✗ in the widened action slot. The edited row keeps a
   highlighted background (`kPrimaryLight`) as a visual cue.

## Architecture

Lift the "which row is being edited" state up to the parent so hover suppression
can be coordinated across items.

### `_DatabaseUiState`

- New field: `String? _editingVocabId`.
- `_startEdit(String id)`: sets `_editingVocabId = id` **only when it is
  currently `null`** (implements decision 4).
- `_cancelEdit()`: sets `_editingVocabId = null`.
- `_saveEdit(Vocab updated)`: calls
  `context.read<VocabularyViewmodel>().updateVocab(updated)`, then sets
  `_editingVocabId = null`.
- In the `ListView.builder`, pass each `VocabListItem`:
  - `isEditing: vocabs[index].id == _editingVocabId`
  - `isAnyEditing: _editingVocabId != null`
  - `onStartEdit`, `onSave`, `onCancel` wired to the methods above.

### `VocabListItem` (becomes a controlled edit widget)

New parameters:

- `bool isEditing`
- `bool isAnyEditing`
- `VoidCallback onStartEdit`
- `ValueChanged<Vocab> onSave`
- `VoidCallback onCancel`

Internal state:

- Keeps its own `_isHovered` (unchanged).
- Two `TextEditingController`s (word / mean), initialized from the current vocab
  when entering edit mode, disposed in `dispose()`.
- Save button enable rule mirrors `_canAdd` (both fields non-empty after trim);
  rebuild on field changes via controller listeners.

Interaction:

- **Normal mode:** wrap the row in a `GestureDetector`/`InkWell`; tap →
  `onStartEdit`. The delete-icon area stays independent (tapping it does not
  enter edit). Delete icon visibility becomes `_isHovered && !isAnyEditing`.
- **Edit mode:** render two `TextField`s in place of the word/mean text; hide the
  memory-state dot; show ✓ / ✗.
  - ✓ save (and field `onSubmitted` / Enter): build
    `widget.vocab.copyWith(word: …, mean: …)` and call `onSave`.
  - ✗ cancel (and Esc via a `Focus` `onKeyEvent`): call `onCancel`, discarding
    changes.

When `isEditing` flips from true→false (save or cancel), reset the controllers so
re-entering the row shows the persisted values.

## Data flow

```
tap row → onStartEdit → _editingVocabId = id → rebuild → row renders fields
edit fields (local controllers)
✓ / Enter → copyWith → onSave → VocabularyViewmodel.updateVocab → Store + Excel
✗ / Esc  → onCancel → _editingVocabId = null → rebuild → row renders text
```

## Testing

Widget tests for `VocabListItem`:

- Tapping a row in normal mode invokes `onStartEdit`.
- In edit mode, clearing either field disables the ✓ save button.
- Pressing ✓ (or Enter) invokes `onSave` with a `Vocab` carrying the edited
  word/mean.
- Pressing ✗ (or Esc) invokes `onCancel` and does not call `onSave`.
- When `isAnyEditing` is true and the row is not the one being edited, hovering
  does **not** show the delete icon.

## Out of scope

- Editing level / memory-state / cooldown (only word and mean are editable).
- Any change to the Gemini/review flow or the mastery domain logic.
