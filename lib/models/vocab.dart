enum Level { red, yellow, green }

enum MemoryState { redLow, redMedium, redHigh, yellowLow, yellowHigh, green }

class Vocab {
  String id;
  String word;
  String mean;
  Level level;
  MemoryState memoryState;
  int cooldown;

  //constructor
  Vocab({
    required this.id,
    required this.word,
    required this.mean,
    required this.level,
    required this.memoryState,
    required this.cooldown,
  });
}
