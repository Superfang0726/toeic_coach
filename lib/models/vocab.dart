enum Level { red, yellow, green }

/// Finer-grained mastery states than [Level], ordered from least to most
/// mastered. Declaration order is load-bearing: `VocabDomain`'s interval
/// lookup and its upgrade/downgrade chain both index off this ordering via
/// `.index`, so reordering these values silently changes scheduling.
enum MemoryState { redLow, redMedium, redHigh, yellowLow, yellowHigh, green }

class Vocab {
  final String id;
  final String word;
  final String mean;

  /// Coarse bucket derived from [memoryState] via `VocabDomain.inferLevel`.
  /// Not enforced by the type system — callers that set this independently
  /// of [memoryState] can make the two drift out of sync.
  final Level level;
  final MemoryState memoryState;

  /// The absolute round number this word next becomes due, not a countdown.
  /// Legacy Excel files headed `cooldown` predate round persistence and
  /// stored the countdown value directly as this absolute round; see
  /// `ExcelRepository` for the one-time upgrade on first write.
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
