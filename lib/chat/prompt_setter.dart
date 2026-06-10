import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/option.dart';

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
2. The four different answer choices for the blank must be selected from the red and yellow words. If the vocabulary data contains fewer than four red and yellow words, include all available red and yellow words, and fill the remaining answer choices with commonly differently confused TOEIC vocabulary.
3. Select one of the four answer choices as the correct answer.
4. After selecting the correct answer, construct the question sentence using as many relevant green words as possible, ensuring that the correct answer naturally and grammatically fits the blank.""",
    );
    return buffer.toString();
  }

  static String reviewPrompt(Option userAnswer, List<String> unfamiliarWords) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln("User's answer is ${userAnswer.label}. ${userAnswer.word}");

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln(
        'And here are some unfamiliar vocabulary provided by user:',
      );
      for (String word in unfamiliarWords) {
        buffer.writeln('$word,');
      }
    }

    buffer.writeln("""
Goal: Evaluate the answer, tell user if the answer is correct or not in traditional chinese. Besides, if the answer is wrong or user provide some unfamiliar vocabulary, record its adjustment in the "memoryStateUpdateResult" field.
Workflow:
1. Evaluate the answer based on chat history.
2. If the answer is correct, tell user the answer provided is correct, and record "<word> > upgrade" for the answered vocabulary in "memoryStateUpdateResult"; if not, tell user which option is correct and why user's choice is wrong, and record "<word> > downgrade" instead.
""");

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln("""
3. Tell user the mean of the unfamiliar vocabulary in the sentence.
4. Downgrade the unfamiliar vocabulary by recording "<word> > downgrade" in "memoryStateUpdateResult" depends on how common it is. If it appear in TOEIC test usually or has enough confusion, downgrade it.
""");
    }

    return buffer.toString();
  }
}
