import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocabAdjustment.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'vocab_domain.dart';
import 'excel_repository.dart';
import 'vocab_domain.dart';

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
    List<Vocab> currentVocabs = store.vocabulary;
    int index = currentVocabs.indexWhere(
      (vocab) => vocab.word == vocabAdjustment.word,
    );

    print('---index---');
    print(index);

    currentVocabs[index].mean = vocabAdjustment.mean;

    if (vocabAdjustment.adjustment == Adjustment.upgrade) {
      currentVocabs[index].memoryState = VocabDomain.upgrade(
        currentVocabs[index].memoryState,
      );
    } else {
      //adjustment == Adjustment.downgrade
      currentVocabs[index].memoryState = VocabDomain.downgrade(
        currentVocabs[index].memoryState,
      );
    }

    currentVocabs[index].level = VocabDomain.inferLevel(
      currentVocabs[index].memoryState,
    );

    //write in
    print('excel write in sucessfully');
    store.updateVocabularyStore(currentVocabs);
    excelRepository.writeExcel(currentVocabs);
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
