import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocab_adjustment.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
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

class FakeSharedPreferencesRepository extends SharedPreferencesRepository {
  int? lastWrittenRound;
  @override
  Future<void> writeRound(int round) async {
    lastWrittenRound = round;
  }

  @override
  Future<int> readRound() async => lastWrittenRound ?? 0;
}

Vocab vocab(String word, MemoryState state, Level level,
        {int nextDueRound = 0}) =>
    Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: state,
      nextDueRound: nextDueRound,
    );

VocabularyViewmodel makeViewmodel(
  Store store,
  FakeExcelRepository excel,
  FakeSharedPreferencesRepository prefs,
) =>
    VocabularyViewmodel(
      store: store,
      excelRepository: excel,
      sharedPreferencesRepository: prefs,
    );

void main() {
  test('applyDueForUsedWords schedules from currentRound and persists', () {
    final store = Store();
    store.updateVocabularyStore([
      vocab('apple', MemoryState.green, Level.green),
      vocab('banana', MemoryState.redLow, Level.red, nextDueRound: 4),
    ]);
    store.updateRoundStore(10);
    final excel = FakeExcelRepository();
    final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

    vm.applyDueForUsedWords(['apple']);

    // Store updated: apple due at currentRound + interval (10 + 2 for green),
    // banana untouched.
    expect(
      store.vocabulary.firstWhere((v) => v.word == 'apple').nextDueRound,
      12,
    );
    expect(
      store.vocabulary.firstWhere((v) => v.word == 'banana').nextDueRound,
      4,
    );
    // Persisted the same list.
    expect(excel.lastWritten, isNotNull);
    expect(
      excel.lastWritten!.firstWhere((v) => v.word == 'apple').nextDueRound,
      12,
    );
  });

  test('incrementRound bumps the store round and persists it', () {
    final store = Store();
    store.updateRoundStore(41);
    final prefs = FakeSharedPreferencesRepository();
    final vm = makeViewmodel(store, FakeExcelRepository(), prefs);

    vm.incrementRound();

    expect(store.currentRound, 42);
    expect(prefs.lastWrittenRound, 42);
  });

  test('applyVocabAdjustment schedules the word from currentRound', () {
    final store = Store();
    store.updateVocabularyStore([
      vocab('apple', MemoryState.redLow, Level.red),
    ]);
    store.updateRoundStore(10);
    final excel = FakeExcelRepository();
    final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

    vm.applyVocabAdjustment(
      VocabAdjustment(
        word: 'apple',
        mean: 'apple',
        adjustment: Adjustment.upgrade,
      ),
    );

    // redLow upgraded to redMedium; interval(redMedium) == 3.
    final updated = store.vocabulary.single;
    expect(updated.memoryState, MemoryState.redMedium);
    expect(updated.nextDueRound, 13);
  });

  test('addVocab starts a new word immediately eligible (nextDueRound 0)', () {
    final store = Store();
    store.updateVocabularyStore([]);
    store.updateRoundStore(10);
    final vm =
        makeViewmodel(store, FakeExcelRepository(), FakeSharedPreferencesRepository());

    vm.addVocab(word: 'apple', mean: 'apple', level: Level.red);

    expect(store.vocabulary.single.nextDueRound, 0);
  });

  test('handleVocabAdjustment adds an unknown word as red on downgrade', () {
    final store = Store();
    store.updateVocabularyStore([]);
    final excel = FakeExcelRepository();
    final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

    vm.handleVocabAdjustment(
      VocabAdjustment(word: 'novel', mean: '新字', adjustment: Adjustment.downgrade),
    );

    final added = store.vocabulary.single;
    expect(added.word, 'novel');
    expect(added.level, Level.red);
  });

  test('handleVocabAdjustment ignores an unknown word answered correctly (upgrade)', () {
    final store = Store();
    store.updateVocabularyStore([]);
    final excel = FakeExcelRepository();
    final vm = makeViewmodel(store, excel, FakeSharedPreferencesRepository());

    vm.handleVocabAdjustment(
      VocabAdjustment(word: 'known', mean: '會的字', adjustment: Adjustment.upgrade),
    );

    expect(store.vocabulary, isEmpty);
  });
}
