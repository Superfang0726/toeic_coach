import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocab_adjustment.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'vocab_domain.dart';
import 'excel_repository.dart';

class VocabularyViewmodel {
  Store store;
  ExcelRepository excelRepository;

  //constructor
  VocabularyViewmodel({required this.store, required this.excelRepository});

  //methods
  void addVocab({
    required String word,
    required String mean,
    required Level level, //Level will decide the memoryState
  }) {
    final currentVocabs = store.vocabulary;

    //alert user the vocab has existed and stop adding new vocab
    if (VocabDomain.checkVocabExist(currentVocabs, word)) {
      return; //TODO: alert user
    }

    String id = VocabDomain.generateUuid();
    MemoryState memoryState = VocabDomain.getDefaultMemoryState(level);

    Vocab newVocab = Vocab(
      id: id,
      word: word,
      mean: mean,
      level: level,
      memoryState: memoryState,
      cooldown: 0,
    );
    currentVocabs.add(newVocab);

    //write in
    store.updateVocabularyStore(currentVocabs);
    excelRepository.writeExcel(currentVocabs);
  }

  List<Vocab> searchVocab({required String target}) {
    final currentVocabs = store.vocabulary;

    return currentVocabs.where((vocab) => vocab.word.contains(target)).toList();
  }

  void deleteVocab(Vocab target) {
    final currentVocabs = store.vocabulary;
    currentVocabs.removeWhere((vocab) => vocab.word == target.word);

    //write in
    store.updateVocabularyStore(currentVocabs);
    excelRepository.writeExcel(currentVocabs);
  }

  //TODO: Change this into updateVocabByUI
  void updateVocab(Vocab updatedVocab) {
    final currentVocabs = store.vocabulary;
    final int index = currentVocabs.indexWhere(
      (vocab) => vocab.id == updatedVocab.id,
    );
    currentVocabs[index] = updatedVocab;

    //write in
    store.updateVocabularyStore(currentVocabs);
    excelRepository.writeExcel(currentVocabs);
  }

  void applyVocabAdjustment(VocabAdjustment vocabAdjustment) {
    int index = store.vocabulary.indexWhere(
      (vocab) =>
          vocab.word.toLowerCase() == vocabAdjustment.word.toLowerCase(),
    );

    Vocab target = store.vocabulary[index];

    MemoryState newMemoryState =
        vocabAdjustment.adjustment == Adjustment.upgrade
        ? VocabDomain.upgrade(target.memoryState)
        : VocabDomain.downgrade(target.memoryState);

    Vocab updatedVocab = target.copyWith(
      mean: vocabAdjustment.mean,
      memoryState: newMemoryState,
      level: VocabDomain.inferLevel(newMemoryState),
      cooldown: VocabDomain.inferCooldown(newMemoryState),
    );

    List<Vocab> updatedVocabs = List.from(store.vocabulary);
    updatedVocabs[index] = updatedVocab;

    store.updateVocabularyStore(updatedVocabs);
    excelRepository.writeExcel(updatedVocabs);
  }

  void handleVocabAdjustment(VocabAdjustment vocabAdjustment) {
    if (VocabDomain.checkVocabExist(store.vocabulary, vocabAdjustment.word)) {
      applyVocabAdjustment(vocabAdjustment);
    } else {
      addVocab(
        word: vocabAdjustment.word,
        mean: vocabAdjustment.mean,
        level: Level.red,
      );
    }
  }
}
