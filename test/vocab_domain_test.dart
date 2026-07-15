import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/vocab_domain.dart';

Vocab vocab({
  required String word,
  required MemoryState memoryState,
  required Level level,
  int nextDueRound = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: memoryState,
      nextDueRound: nextDueRound,
    );

void main() {
  group('applyDueForUsedWords', () {
    test('sets nextDueRound to currentRound + interval for a used word', () {
      final result = VocabDomain.applyDueForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
        10,
      );
      // inferInterval(green) == 2
      expect(result.single.nextDueRound, 12);
    });

    test('uses the current memoryState interval (redHigh -> 5)', () {
      final result = VocabDomain.applyDueForUsedWords(
        [vocab(word: 'audit', memoryState: MemoryState.redHigh, level: Level.red)],
        {'audit'},
        10,
      );
      expect(result.single.nextDueRound, 15);
    });

    test('matches case-insensitively', () {
      final result = VocabDomain.applyDueForUsedWords(
        [vocab(word: 'Apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
        10,
      );
      expect(result.single.nextDueRound, 12);
    });

    test('ignores words not present in the vocab list', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green),
      ];
      final result = VocabDomain.applyDueForUsedWords(input, {'banana'}, 10);
      expect(result.single.nextDueRound, 0);
    });

    test('leaves memoryState and level untouched', () {
      final result = VocabDomain.applyDueForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
        10,
      );
      expect(result.single.memoryState, MemoryState.green);
      expect(result.single.level, Level.green);
    });

    test('leaves non-used vocabs completely unchanged', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green, nextDueRound: 0),
        vocab(word: 'banana', memoryState: MemoryState.redLow, level: Level.red, nextDueRound: 4),
      ];
      final result = VocabDomain.applyDueForUsedWords(input, {'apple'}, 10);
      expect(result[1].nextDueRound, 4);
      expect(result[1].memoryState, MemoryState.redLow);
    });

    test('schedules multiple words simultaneously', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green),
        vocab(word: 'audit', memoryState: MemoryState.redHigh, level: Level.red),
        vocab(word: 'banana', memoryState: MemoryState.redLow, level: Level.red),
      ];
      final result = VocabDomain.applyDueForUsedWords(input, {'apple', 'audit'}, 10);
      // green -> interval 2
      expect(result[0].nextDueRound, 12);
      // redHigh -> interval 5
      expect(result[1].nextDueRound, 15);
      // banana (not used) -> untouched
      expect(result[2].nextDueRound, 0);
    });
  });

  group('inferInterval', () {
    test('keeps the same interval bands as the old cooldown values', () {
      expect(VocabDomain.inferInterval(MemoryState.redLow), 2);
      expect(VocabDomain.inferInterval(MemoryState.redMedium), 3);
      expect(VocabDomain.inferInterval(MemoryState.redHigh), 5);
      expect(VocabDomain.inferInterval(MemoryState.yellowLow), 7);
      expect(VocabDomain.inferInterval(MemoryState.yellowHigh), 7);
      expect(VocabDomain.inferInterval(MemoryState.green), 2);
    });
  });
}
