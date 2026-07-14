import 'dart:math';

import 'package:toeic_coach/models/vocab.dart';

class QuestionVocabSelector {
  static List<Vocab> filter(List<Vocab> vocabulary) =>
      vocabulary.where((vocab) => vocab.cooldown == 0).toList();

  static List<Vocab> shuffle(List<Vocab> vocabulary, {Random? random}) {
    final shuffled = List<Vocab>.of(vocabulary);
    shuffled.shuffle(random);
    return shuffled;
  }
}
