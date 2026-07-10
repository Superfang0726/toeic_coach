# Vocabulary Inline Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user click a vocabulary row to inline-edit its word and mean, with save/cancel, while suppressing other rows' delete icons during editing.

**Architecture:** Lift a single `String? _editingVocabId` into `_DatabaseUiState`. `VocabListItem` becomes a *controlled* widget: the parent tells it whether it (or any row) is editing and provides `onStartEdit / onSave / onCancel` callbacks. The word/mean text swap to `TextField`s in edit mode; save reuses the existing `VocabularyViewmodel.updateVocab(Vocab)` — no data-layer change.

**Tech Stack:** Flutter (Dart), `provider`, `flutter_test` widget tests.

## Global Constraints

- Do NOT modify ViewModel / Domain / Repository logic. Reuse the existing `VocabularyViewmodel.updateVocab(Vocab)` (updates by `id`, writes back to Excel).
- No new dependencies.
- Use existing theme constants from `lib/theme/app_theme.dart` (`kPrimary`, `kPrimaryLight`, `kSurface`, `kBorder`, `kError`, `kTextPrimary`, `kTextSecondary`, `kMemoryStateGradient`).
- Only `word` and `mean` are editable. Level, memory-state, cooldown are untouched.
- Save is disabled when either field is empty after `.trim()` (mirrors the existing `_canAdd` rule).
- All work happens on branch `feat/vocab-inline-edit` (already created).
- Spec: `docs/superpowers/specs/2026-07-10-vocab-inline-edit-design.md`.

---

### Task 1: Convert `VocabListItem` into a controlled inline-edit widget

Adds the edit params, controllers, inline edit UI (fields + ✓/✗), validation, keyboard shortcuts, and delete-icon hover suppression. The parent call site is updated with inert placeholders so the app still compiles; Task 2 makes it live. All interesting behavior is covered by widget tests here.

**Files:**
- Modify: `lib/vocabulary/database_ui.dart` (the `VocabListItem` widget + its single call site in `_DatabaseUiState.build`)
- Test: `test/vocab_list_item_test.dart` (create)

**Interfaces:**
- Consumes: `Vocab` (`lib/models/vocab.dart`) with `copyWith({String? word, String? mean, ...})`; theme constants.
- Produces: new `VocabListItem` constructor —
  ```dart
  VocabListItem({
    Key? key,
    required Vocab vocab,
    required VoidCallback onDelete,
    required bool isEditing,
    required bool isAnyEditing,
    required VoidCallback onStartEdit,
    required ValueChanged<Vocab> onSave,
    required VoidCallback onCancel,
  })
  ```
  Task 2 relies on exactly these parameter names/types.

- [ ] **Step 1: Write the failing tests**

Create `test/vocab_list_item_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/database_ui.dart';

Vocab _sampleVocab() => const Vocab(
      id: 'v1',
      word: 'apple',
      mean: '蘋果',
      level: Level.red,
      memoryState: MemoryState.redLow,
      cooldown: 0,
    );

/// Pumps a single VocabListItem and records callback invocations.
Future<Map<String, dynamic>> _pumpItem(
  WidgetTester tester, {
  required bool isEditing,
  required bool isAnyEditing,
}) async {
  final calls = <String, dynamic>{
    'startEdit': 0,
    'cancel': 0,
    'delete': 0,
    'saved': null, // Vocab
  };
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: VocabListItem(
          vocab: _sampleVocab(),
          isEditing: isEditing,
          isAnyEditing: isAnyEditing,
          onStartEdit: () => calls['startEdit']++,
          onCancel: () => calls['cancel']++,
          onDelete: () => calls['delete']++,
          onSave: (v) => calls['saved'] = v,
        ),
      ),
    ),
  );
  return calls;
}

Future<void> _hoverOver(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(finder));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a row in normal mode calls onStartEdit', (tester) async {
    final calls = await _pumpItem(tester, isEditing: false, isAnyEditing: false);
    await tester.tap(find.text('apple'));
    await tester.pump();
    expect(calls['startEdit'], 1);
  });

  testWidgets('hovering shows the delete icon when nothing is being edited',
      (tester) async {
    await _pumpItem(tester, isEditing: false, isAnyEditing: false);
    expect(find.byIcon(Icons.delete), findsNothing);
    await _hoverOver(tester, find.byType(VocabListItem));
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('hovering does NOT show the delete icon while another row edits',
      (tester) async {
    await _pumpItem(tester, isEditing: false, isAnyEditing: true);
    await _hoverOver(tester, find.byType(VocabListItem));
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('edit mode shows two text fields seeded with current values',
      (tester) async {
    await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'apple'), findsOneWidget);
    expect(find.widgetWithText(TextField, '蘋果'), findsOneWidget);
  });

  testWidgets('save button is disabled when a field is emptied', (tester) async {
    await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    final IconButton save =
        tester.widget(find.widgetWithIcon(IconButton, Icons.check));
    expect(save.onPressed, isNull);
  });

  testWidgets('pressing save calls onSave with edited word and mean',
      (tester) async {
    final calls = await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).first, 'banana');
    await tester.enterText(find.byType(TextField).last, '香蕉');
    await tester.pump();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.check));
    await tester.pump();
    final Vocab? saved = calls['saved'] as Vocab?;
    expect(saved, isNotNull);
    expect(saved!.word, 'banana');
    expect(saved.mean, '香蕉');
    expect(saved.id, 'v1');
  });

  testWidgets('pressing Enter in a field saves', (tester) async {
    final calls = await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).first, 'banana');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((calls['saved'] as Vocab?)?.word, 'banana');
  });

  testWidgets('pressing cancel calls onCancel and never onSave',
      (tester) async {
    final calls = await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).first, 'banana');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
    await tester.pump();
    expect(calls['cancel'], 1);
    expect(calls['saved'], isNull);
  });

  testWidgets('pressing Esc cancels', (tester) async {
    final calls = await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls['cancel'], 1);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/vocab_list_item_test.dart`
Expected: FAIL — the `VocabListItem` constructor does not yet accept `isEditing` / `isAnyEditing` / `onStartEdit` / `onSave` / `onCancel` (compile error), so the test file will not compile.

- [ ] **Step 3: Rewrite `VocabListItem` as a controlled edit widget**

In `lib/vocabulary/database_ui.dart`, add these imports at the top if missing:

```dart
import 'package:flutter/services.dart'; // LogicalKeyboardKey
```

Replace the entire `VocabListItem` widget + its `_VocabListItemState` (currently lines ~250-354) with:

```dart
///
///VocabListItem is every vocab object displays on databaseUI
///
class VocabListItem extends StatefulWidget {
  final Vocab vocab;
  final VoidCallback onDelete;

  /// True when THIS row is the one being edited.
  final bool isEditing;

  /// True when ANY row is being edited (used to suppress delete-on-hover).
  final bool isAnyEditing;

  final VoidCallback onStartEdit;
  final ValueChanged<Vocab> onSave;
  final VoidCallback onCancel;

  const VocabListItem({
    super.key,
    required this.vocab,
    required this.onDelete,
    required this.isEditing,
    required this.isAnyEditing,
    required this.onStartEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<VocabListItem> createState() => _VocabListItemState();
}

class _VocabListItemState extends State<VocabListItem> {
  bool _isHovered = false;
  late final TextEditingController _wordController;
  late final TextEditingController _meanController;
  final FocusNode _wordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.vocab.word);
    _meanController = TextEditingController(text: widget.vocab.mean);
    // Rebuild while editing so the save button enables/disables live.
    _wordController.addListener(_onEditChanged);
    _meanController.addListener(_onEditChanged);
  }

  void _onEditChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant VocabListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Seed the fields from the current vocab whenever edit mode toggles, and
    // focus the word field when entering edit mode.
    if (widget.isEditing && !oldWidget.isEditing) {
      _resetControllers();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _wordFocusNode.requestFocus(),
      );
    } else if (!widget.isEditing && oldWidget.isEditing) {
      _resetControllers();
    }
  }

  void _resetControllers() {
    _wordController.text = widget.vocab.word;
    _meanController.text = widget.vocab.mean;
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meanController.dispose();
    _wordFocusNode.dispose();
    super.dispose();
  }

  Color get _levelColor {
    switch (widget.vocab.level) {
      case Level.red:
        return kError;
      case Level.yellow:
        return kWarning;
      case Level.green:
        return kSuccess;
    }
  }

  // Mirrors the "Add" button rule: both fields non-empty after trimming.
  bool get _canSave =>
      _wordController.text.trim().isNotEmpty &&
      _meanController.text.trim().isNotEmpty;

  void _save() {
    if (!_canSave) return;
    widget.onSave(
      widget.vocab.copyWith(
        word: _wordController.text.trim(),
        mean: _meanController.text.trim(),
      ),
    );
  }

  // Compact outlined field for inline editing.
  InputDecoration _fieldDecoration() {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      filled: true,
      fillColor: kSurface,
      border: border(kBorder, 1),
      enabledBorder: border(kBorder, 1),
      focusedBorder: border(kPrimary, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool highlighted = widget.isEditing || _isHovered;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: highlighted ? kPrimaryLight : kSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left 4px color strip based on level.
              Container(width: 4, color: _levelColor),
              Expanded(
                child: widget.isEditing ? _buildEditRow() : _buildDisplayRow(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Normal mode: tapping anywhere (except the delete button) starts editing.
  Widget _buildDisplayRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onStartEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.vocab.word,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.vocab.mean,
                style: const TextStyle(color: kTextSecondary),
              ),
            ),
            // Right-side memory-state dot (gradient low -> high).
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kMemoryStateGradient[widget.vocab.memoryState.index],
              ),
            ),
            // Reserve width so the row doesn't jump on hover. The delete icon
            // is suppressed while any row is being edited.
            SizedBox(
              width: 40,
              child: (_isHovered && !widget.isAnyEditing)
                  ? IconButton(
                      icon: const Icon(Icons.delete, color: kError),
                      onPressed: widget.onDelete,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Edit mode: word/mean become fields; Esc cancels; Enter saves.
  Widget _buildEditRow() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _wordController,
                focusNode: _wordFocusNode,
                decoration: _fieldDecoration(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _meanController,
                decoration: _fieldDecoration(),
                style: const TextStyle(color: kTextPrimary),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check, color: kSuccess),
              tooltip: 'Save',
              onPressed: _canSave ? _save : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: kTextSecondary),
              tooltip: 'Cancel',
              onPressed: widget.onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
```

Also update the single call site inside `_DatabaseUiState.build` (the `ListView.builder` `itemBuilder`, currently ~lines 211-217) to pass inert placeholders so the app compiles (Task 2 wires them for real):

```dart
itemBuilder: (context, index) {
  return VocabListItem(
    vocab: vocabs[index],
    isEditing: false,
    isAnyEditing: false,
    onStartEdit: () {},
    onSave: (_) {},
    onCancel: () {},
    onDelete: () => context
        .read<VocabularyViewmodel>()
        .deleteVocab(vocabs[index]),
  );
},
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/vocab_list_item_test.dart`
Expected: PASS (all 9 tests).

- [ ] **Step 5: Lint**

Run: `flutter analyze lib/vocabulary/database_ui.dart test/vocab_list_item_test.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/vocabulary/database_ui.dart test/vocab_list_item_test.dart
git commit -m "feat: controlled inline-edit VocabListItem with tests"
```

---

### Task 2: Wire edit state into `_DatabaseUiState`

Replace the Task 1 placeholders with real state: a single `_editingVocabId`, the one-at-a-time guard, and the save/cancel handlers calling `updateVocab`.

**Files:**
- Modify: `lib/vocabulary/database_ui.dart` (`_DatabaseUiState`)

**Interfaces:**
- Consumes: `VocabListItem(... isEditing, isAnyEditing, onStartEdit, onSave, onCancel ...)` from Task 1; `VocabularyViewmodel.updateVocab(Vocab)`.
- Produces: none (top-level UI wiring).

- [ ] **Step 1: Add edit state + handlers to `_DatabaseUiState`**

In `lib/vocabulary/database_ui.dart`, add a field alongside the existing controllers in `_DatabaseUiState` (near line 26, after `Level _selectedLevel = Level.red;`):

```dart
  // id of the row currently being inline-edited, or null when none.
  String? _editingVocabId;
```

Add these methods to `_DatabaseUiState` (e.g. after `_onInputChanged`):

```dart
  // Enter edit mode only when nothing else is being edited (one at a time).
  void _startEdit(String id) {
    if (_editingVocabId != null) return;
    setState(() => _editingVocabId = id);
  }

  void _cancelEdit() => setState(() => _editingVocabId = null);

  void _saveEdit(Vocab updated) {
    context.read<VocabularyViewmodel>().updateVocab(updated);
    setState(() => _editingVocabId = null);
  }
```

- [ ] **Step 2: Wire the `ListView.builder` item to the real state**

Replace the `itemBuilder` body from Task 1 with:

```dart
itemBuilder: (context, index) {
  final Vocab vocab = vocabs[index];
  return VocabListItem(
    vocab: vocab,
    isEditing: _editingVocabId == vocab.id,
    isAnyEditing: _editingVocabId != null,
    onStartEdit: () => _startEdit(vocab.id),
    onSave: _saveEdit,
    onCancel: _cancelEdit,
    onDelete: () => context
        .read<VocabularyViewmodel>()
        .deleteVocab(vocab),
  );
},
```

- [ ] **Step 3: Lint**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Regression — run the full test suite**

Run: `flutter test`
Expected: all tests pass (Task 1's `vocab_list_item_test.dart` + existing `update_viewmodel_test.dart`).

- [ ] **Step 5: Manual smoke test**

Run: `flutter run -d windows`
Verify, in the vocabulary pane:
1. Click a row → word/mean become fields, word focused, dot hidden, ✓/✗ shown.
2. Empty a field → ✓ disabled. Refill → ✓ enabled.
3. ✓ (or Enter) → row returns to normal showing the new word/mean (persisted after restart).
4. ✗ (or Esc) → row reverts, no change saved.
5. While a row is being edited, hover another row → its delete icon does NOT appear; clicking another row is ignored.

- [ ] **Step 6: Commit**

```bash
git add lib/vocabulary/database_ui.dart
git commit -m "feat: wire vocabulary inline-edit state in DatabaseUi"
```

---

## Self-Review

- **Spec coverage:** inline edit + explicit buttons (Task 1 `_buildEditRow`), empty-value validation (`_canSave`, Task 1 Step 1 test + Task 2 disabled button), Enter/Esc keyboard (Task 1 `onSubmitted` + `Focus.onKeyEvent`, tests), one-at-a-time (`_startEdit` guard, Task 2), layout w/ hidden dot + widened ✓/✗ slot + level strip + `kPrimaryLight` cue (Task 1 build), reuse `updateVocab` (Task 2 `_saveEdit`), widget tests (Task 1). All covered.
- **Placeholder scan:** No TBD/TODO; the "inert placeholders" in Task 1 Step 3 are intentional compile stubs, replaced in Task 2.
- **Type consistency:** `VocabListItem` constructor params (`isEditing`, `isAnyEditing`, `onStartEdit`, `onSave: ValueChanged<Vocab>`, `onCancel`) are identical in Task 1 (definition) and Task 2 (call site). `_startEdit(String)`, `_cancelEdit()`, `_saveEdit(Vocab)` names match between definition and wiring.
