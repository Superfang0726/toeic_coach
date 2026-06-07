enum Level { red, yellow, green }

enum MemoryState { redLow, redMedium, redHigh, yellowLow, yellowHigh, green }

class Vocab {
  final String id;
  final String word;
  final String mean;
  final Level level;
  final MemoryState memoryState;
  final int cooldown;

  const Vocab({
    required this.id,
    required this.word,
    required this.mean,
    required this.level,
    required this.memoryState,
    required this.cooldown,
  });

  Vocab copyWith({
    String? id,
    String? word,
    String? mean,
    Level? level,
    MemoryState? memoryState,
    int? cooldown,
  }) {
    return Vocab(
      id: id ?? this.id,
      word: word ?? this.word,
      mean: mean ?? this.mean,
      level: level ?? this.level,
      memoryState: memoryState ?? this.memoryState,
      cooldown: cooldown ?? this.cooldown,
    );
  }
}
