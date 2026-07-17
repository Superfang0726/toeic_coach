import 'dart:math';

import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/models/vocab.dart';

class QuestionVocabSelector {
  static List<Vocab> shuffle(List<Vocab> vocabulary, {Random? random}) {
    final shuffled = List<Vocab>.of(vocabulary);
    shuffled.shuffle(random);
    return shuffled;
  }

  /// The most overdue red/yellow word at [currentRound] (max
  /// `currentRound - nextDueRound`, random tiebreak among ties), or `null`
  /// when nothing is due.
  ///
  /// That `null` is a mode signal, not just "no result": `ChatViewModel`
  /// reads it as the trigger to fall back to novel mode instead of testing
  /// a scheduled word.
  static Vocab? pickAnswerWord(
    List<Vocab> vocabulary,
    int currentRound, {
    Random? random,
  }) {
    final due = vocabulary
        .where(
          (v) =>
              (v.level == Level.red || v.level == Level.yellow) &&
              v.nextDueRound <= currentRound,
        )
        .toList();
    if (due.isEmpty) return null;

    final maxOverdue = due
        .map((v) => currentRound - v.nextDueRound)
        .reduce((a, b) => a > b ? a : b);
    final tied = due
        .where((v) => currentRound - v.nextDueRound == maxOverdue)
        .toList();
    tied.shuffle(random);
    return tied.first;
  }

  /// Red/yellow words (excluding [answer]) offered to Gemini as candidate
  /// wrong options — the same pool [answer] itself is drawn from, so
  /// distractors stay at a comparable difficulty to the tested word.
  static List<Vocab> distractorPool(List<Vocab> vocabulary, Vocab answer) =>
      vocabulary
          .where(
            (v) =>
                (v.level == Level.red || v.level == Level.yellow) &&
                v.word.toLowerCase() != answer.word.toLowerCase(),
          )
          .toList();

  /// Already-mastered words offered to Gemini as an easier distractor
  /// source, kept separate from [distractorPool] so a question isn't
  /// accidentally built entirely from words the user is still struggling
  /// with.
  static List<Vocab> greenPool(List<Vocab> vocabulary) =>
      vocabulary.where((v) => v.level == Level.green).toList();

  /// Finds which [options] label holds [answerWord] (case-insensitive), or
  /// `null` if Gemini omitted the scheduled word from its own options.
  ///
  /// `ChatViewModel` treats that `null` as `ScheduledAnswerMissingException`,
  /// which `RetryHandler` retries by regenerating the question.
  static String? resolveAnswerLabel(List<Option> options, String answerWord) {
    for (final option in options) {
      if (option.word.toLowerCase() == answerWord.toLowerCase()) {
        return option.label;
      }
    }
    return null;
  }
}
