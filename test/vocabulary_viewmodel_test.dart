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
