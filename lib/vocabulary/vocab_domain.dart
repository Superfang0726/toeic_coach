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

  static MemoryState upgrade(MemoryState currentMemoryState) {
    print(currentMemoryState);
    switch (currentMemoryState) {
      case MemoryState.redLow:
        return MemoryState.redMedium;
      case MemoryState.redMedium:
        return MemoryState.redHigh;
      case MemoryState.redHigh:
        return MemoryState.yellowLow;
      case MemoryState.yellowLow:
        return MemoryState.yellowHigh;
      case MemoryState.yellowHigh:
        return MemoryState.green;
      case MemoryState.green:
        return MemoryState.green;
    }
  }

  static MemoryState downgrade(MemoryState currentMemoryState) {
    switch (currentMemoryState) {
      case MemoryState.redLow:
        return MemoryState.redLow;
      case MemoryState.redMedium:
        return MemoryState.redLow;
      case MemoryState.redHigh:
        return MemoryState.redMedium;
      case MemoryState.yellowLow:
        return MemoryState.redLow;
      case MemoryState.yellowHigh:
        return MemoryState.yellowLow;
      case MemoryState.green:
        return MemoryState.yellowLow;
    }
  }

  static Level inferLevel(MemoryState memoryState) {
    switch (memoryState) {
      case MemoryState.redHigh:
      case MemoryState.redMedium:
      case MemoryState.redLow:
        return Level.red;
      case MemoryState.yellowHigh:
      case MemoryState.yellowLow:
        return Level.yellow;
      case MemoryState.green:
        return Level.green;
    }
  }
}
