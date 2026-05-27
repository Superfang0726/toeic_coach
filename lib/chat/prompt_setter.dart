import 'package:toeic_coach/models/vocab.dart';

class PromptSetter {
  //method
  static String questionPrompt(List<Vocab> filteredVocabulary) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('| word | mean | level |');
    buffer.writeln('|---|---|---|');
    for (Vocab vocab in filteredVocabulary) {
      buffer.writeln('| ${vocab.word} | ${vocab.mean} | ${vocab.level.name} |');
    }
    buffer.writeln(
      """
Goal: Using the vocabulary data provided above, generate one TOEIC Part 5 question by following the rules below.
Workflow: 
1. Classify the vocabulary according to its level: red and yellow words should be used as the answer choices for the blank, while green words should be used to construct the question sentence.
2. The four answer choices for the blank must be selected from the red and yellow words. If the vocabulary data contains fewer than four red and yellow words, include all available red and yellow words, and fill the remaining answer choices with commonly confused TOEIC vocabulary.
3. Select one of the four answer choices as the correct answer.
4. After selecting the correct answer, construct the question sentence using as many relevant green words as possible, ensuring that the correct answer naturally and grammatically fits the blank.""",
    );
    return buffer.toString();
  }

  static String reviewPrompt() {}
}
