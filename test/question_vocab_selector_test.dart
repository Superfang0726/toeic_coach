import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/question_vocab_selector.dart';
import 'package:toeic_coach/models/option.dart';
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

Vocab leveled({
  required String word,
  required Level level,
  required MemoryState memoryState,
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

  group('QuestionVocabSelector.pickAnswerWord', () {
    test('picks the most overdue due red/yellow word', () {
      final result = QuestionVocabSelector.pickAnswerWord([
        leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 8),
        leveled(word: 'b', level: Level.yellow, memoryState: MemoryState.yellowLow, nextDueRound: 2),
        leveled(word: 'c', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 5),
      ], 10);
      // overdue: a=2, b=8, c=5 -> b is most overdue
      expect(result?.word, 'b');
    });

    test('ignores green words even when they are more overdue', () {
      final result = QuestionVocabSelector.pickAnswerWord([
        leveled(word: 'known', level: Level.green, memoryState: MemoryState.green, nextDueRound: 0),
        leveled(word: 'learning', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 9),
      ], 10);
      expect(result?.word, 'learning');
    });

    test('returns null when every red/yellow word is resting (not due)', () {
      final result = QuestionVocabSelector.pickAnswerWord([
        leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 12),
        leveled(word: 'b', level: Level.yellow, memoryState: MemoryState.yellowLow, nextDueRound: 20),
        leveled(word: 'g', level: Level.green, memoryState: MemoryState.green, nextDueRound: 0),
      ], 10);
      expect(result, isNull);
    });

    test('returns null for an empty vocabulary', () {
      expect(QuestionVocabSelector.pickAnswerWord([], 10), isNull);
    });

    test('random tiebreak returns one of the tied maxima', () {
      final input = [
        leveled(word: 'a', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
        leveled(word: 'b', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
        leveled(word: 'c', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
      ];
      final result = QuestionVocabSelector.pickAnswerWord(input, 5, random: Random(1));
      expect(['a', 'b', 'c'].contains(result?.word), isTrue);
    });

    test('a strictly-maximum word is always chosen regardless of random', () {
      final input = [
        leveled(word: 'tie1', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 3),
        leveled(word: 'winner', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 0),
        leveled(word: 'tie2', level: Level.red, memoryState: MemoryState.redLow, nextDueRound: 3),
      ];
      for (var seed = 0; seed < 5; seed++) {
        final result = QuestionVocabSelector.pickAnswerWord(input, 10, random: Random(seed));
        expect(result?.word, 'winner');
      }
    });
  });

  group('QuestionVocabSelector.distractorPool', () {
    test('keeps red/yellow words and excludes the answer', () {
      final answer = leveled(word: 'answer', level: Level.red, memoryState: MemoryState.redLow);
      final result = QuestionVocabSelector.distractorPool([
        answer,
        leveled(word: 'red2', level: Level.red, memoryState: MemoryState.redLow),
        leveled(word: 'yellow1', level: Level.yellow, memoryState: MemoryState.yellowLow),
        leveled(word: 'green1', level: Level.green, memoryState: MemoryState.green),
      ], answer);
      expect(result.map((v) => v.word).toList(), ['red2', 'yellow1']);
    });

    test('matches the answer case-insensitively when excluding it', () {
      final answer = leveled(word: 'Answer', level: Level.red, memoryState: MemoryState.redLow);
      final result = QuestionVocabSelector.distractorPool([
        leveled(word: 'answer', level: Level.red, memoryState: MemoryState.redLow),
        leveled(word: 'other', level: Level.red, memoryState: MemoryState.redLow),
      ], answer);
      expect(result.map((v) => v.word).toList(), ['other']);
    });
  });

  group('QuestionVocabSelector.greenPool', () {
    test('keeps only green words', () {
      final result = QuestionVocabSelector.greenPool([
        leveled(word: 'g1', level: Level.green, memoryState: MemoryState.green),
        leveled(word: 'r1', level: Level.red, memoryState: MemoryState.redLow),
        leveled(word: 'g2', level: Level.green, memoryState: MemoryState.green),
      ]);
      expect(result.map((v) => v.word).toList(), ['g1', 'g2']);
    });
  });

  group('QuestionVocabSelector.resolveAnswerLabel', () {
    final options = [
      Option(label: 'A', word: 'alpha'),
      Option(label: 'B', word: 'bravo'),
      Option(label: 'C', word: 'charlie'),
      Option(label: 'D', word: 'delta'),
    ];

    test('returns the label whose word matches', () {
      expect(QuestionVocabSelector.resolveAnswerLabel(options, 'charlie'), 'C');
    });

    test('matches case-insensitively', () {
      expect(QuestionVocabSelector.resolveAnswerLabel(options, 'BRAVO'), 'B');
    });

    test('returns null when no option holds the word', () {
      expect(QuestionVocabSelector.resolveAnswerLabel(options, 'echo'), isNull);
    });
  });
}
