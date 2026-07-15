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
}
