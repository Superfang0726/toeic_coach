import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/vocab_domain.dart';

Vocab vocab({
  required String word,
  required MemoryState memoryState,
  required Level level,
  int cooldown = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: level,
      memoryState: memoryState,
      cooldown: cooldown,
    );

void main() {
  group('applyCooldownForUsedWords', () {
    test('sets cooldown to the band value for a used word', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      // inferCooldown(green) == 2
      expect(result.single.cooldown, 2);
    });

    test('uses the current memoryState band (redHigh -> 5)', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'audit', memoryState: MemoryState.redHigh, level: Level.red)],
        {'audit'},
      );
      expect(result.single.cooldown, 5);
    });

    test('matches case-insensitively', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'Apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      expect(result.single.cooldown, 2);
    });

    test('ignores words not present in the vocab list', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green),
      ];
      final result = VocabDomain.applyCooldownForUsedWords(input, {'banana'});
      expect(result.single.cooldown, 0);
    });

    test('leaves memoryState and level untouched', () {
      final result = VocabDomain.applyCooldownForUsedWords(
        [vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green)],
        {'apple'},
      );
      expect(result.single.memoryState, MemoryState.green);
      expect(result.single.level, Level.green);
    });

    test('leaves non-used vocabs completely unchanged', () {
      final input = [
        vocab(word: 'apple', memoryState: MemoryState.green, level: Level.green, cooldown: 0),
        vocab(word: 'banana', memoryState: MemoryState.redLow, level: Level.red, cooldown: 4),
      ];
      final result = VocabDomain.applyCooldownForUsedWords(input, {'apple'});
      expect(result[1].cooldown, 4);
      expect(result[1].memoryState, MemoryState.redLow);
    });
  });
}
