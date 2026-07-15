enum Level { red, yellow, green }

enum MemoryState { redLow, redMedium, redHigh, yellowLow, yellowHigh, green }

class Vocab {
  final String id;
  final String word;
  final String mean;
  final Level level;
  final MemoryState memoryState;
  final int nextDueRound;

  const Vocab({
    required this.id,
    required this.word,
    required this.mean,
    required this.level,
    required this.memoryState,
    required this.nextDueRound,
  });

  Vocab copyWith({
    String? id,
    String? word,
    String? mean,
    Level? level,
    MemoryState? memoryState,
    int? nextDueRound,
  }) {
    return Vocab(
      id: id ?? this.id,
      word: word ?? this.word,
      mean: mean ?? this.mean,
      level: level ?? this.level,
      memoryState: memoryState ?? this.memoryState,
      nextDueRound: nextDueRound ?? this.nextDueRound,
    );
  }
}
