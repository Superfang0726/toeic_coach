import 'dart:math';

import 'package:toeic_coach/models/vocab.dart';

class QuestionVocabSelector {
  static List<Vocab> filter(List<Vocab> vocabulary, int currentRound) =>
      vocabulary.where((vocab) => vocab.nextDueRound <= currentRound).toList();

  static List<Vocab> shuffle(List<Vocab> vocabulary, {Random? random}) {
    final shuffled = List<Vocab>.of(vocabulary);
    shuffled.shuffle(random);
    return shuffled;
  }

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
}
