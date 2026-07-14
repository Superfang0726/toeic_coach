import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/question_vocab_selector.dart';
import 'package:toeic_coach/models/vocab.dart';

Vocab vocab({
  required String word,
  int cooldown = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: Level.red,
      memoryState: MemoryState.redLow,
      cooldown: cooldown,
    );

void main() {
  group('QuestionVocabSelector.filter', () {
    test('keeps only words with cooldown == 0', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', cooldown: 0),
        vocab(word: 'banana', cooldown: 2),
        vocab(word: 'cherry', cooldown: 0),
      ]);

      expect(result.map((v) => v.word).toList(), ['apple', 'cherry']);
    });

    test('returns an empty list when all words are on cooldown', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', cooldown: 1),
      ]);

      expect(result, isEmpty);
    });
  });

  group('QuestionVocabSelector.shuffle', () {
    test('returns a list with the same words as the input', () {
      final input = [
        vocab(word: 'apple'),
        vocab(word: 'banana'),
        vocab(word: 'cherry'),
        vocab(word: 'date'),
      ];

      final result = QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(
        result.map((v) => v.word).toSet(),
        {'apple', 'banana', 'cherry', 'date'},
      );
      expect(result.length, input.length);
    });

    test('does not mutate the input list', () {
      final input = [
        vocab(word: 'apple'),
        vocab(word: 'banana'),
        vocab(word: 'cherry'),
        vocab(word: 'date'),
      ];
      final originalOrder = input.map((v) => v.word).toList();

      QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(input.map((v) => v.word).toList(), originalOrder);
    });

    test('returns a different list instance than the input', () {
      final input = [vocab(word: 'apple'), vocab(word: 'banana')];

      final result = QuestionVocabSelector.shuffle(input, random: Random(42));

      expect(identical(result, input), isFalse);
    });
  });
}
