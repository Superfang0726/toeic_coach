import 'package:toeic_coach/models/vocab.dart';
import 'package:uuid/uuid.dart';

class VocabDomain {
  static Uuid uuid = Uuid();

  //methods
  static String generateUuid() => uuid.v4();

  static bool checkVocabExist(List<Vocab> currentVocabs, String word) =>
      currentVocabs.any((vocab) => vocab.word == word);

  static MemoryState getDefaultMemoryState(Level level) {
    switch (level) {
      case Level.red:
        return MemoryState.redLow;
      case Level.yellow:
        return MemoryState.yellowLow;
      case Level.green:
        return MemoryState.green;
    }
  }
}
