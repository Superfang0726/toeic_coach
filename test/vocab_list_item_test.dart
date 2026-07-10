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

  testWidgets('save button is disabled when the mean field is emptied',
      (tester) async {
    await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.pump();
    final IconButton save =
        tester.widget(find.widgetWithIcon(IconButton, Icons.check));
    expect(save.onPressed, isNull);
  });

  testWidgets('pressing Enter in the mean field saves', (tester) async {
    final calls = await _pumpItem(tester, isEditing: true, isAnyEditing: true);
    await tester.enterText(find.byType(TextField).last, '香蕉汁');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect((calls['saved'] as Vocab?)?.mean, '香蕉汁');
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
