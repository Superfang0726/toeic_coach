import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/question_vocab_selector.dart';
import 'package:toeic_coach/models/vocab.dart';

Vocab vocab({
  required String word,
  int nextDueRound = 0,
}) => Vocab(
      id: word,
      word: word,
      mean: '',
      level: Level.red,
      memoryState: MemoryState.redLow,
      nextDueRound: nextDueRound,
    );

void main() {
  group('QuestionVocabSelector.filter', () {
    test('keeps only words with nextDueRound <= currentRound', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', nextDueRound: 0),
        vocab(word: 'banana', nextDueRound: 12),
        vocab(word: 'cherry', nextDueRound: 3),
      ], 10);

      expect(result.map((v) => v.word).toList(), ['apple', 'cherry']);
    });

    test('a word due exactly this round is eligible', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', nextDueRound: 10),
      ], 10);

      expect(result.map((v) => v.word).toList(), ['apple']);
    });

    test('returns an empty list when every word is due in the future', () {
      final result = QuestionVocabSelector.filter([
        vocab(word: 'apple', nextDueRound: 11),
      ], 10);

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
