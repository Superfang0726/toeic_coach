import 'package:toeic_coach/models/vocab.dart';

class QuestionVocabFilter {
  //method
  static List<Vocab> filter(List<Vocab> vocabulary) =>
      vocabulary.where((vocab) => vocab.cooldown == 0).toList();
}
