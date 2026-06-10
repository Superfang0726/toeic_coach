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

  static String reviewPrompt(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
  ) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'The correct answer is (${correctAnswer.label}) ${correctAnswer.word}.',
    );
    buffer.writeln(
      "User's answer is (${userAnswer.label}) ${userAnswer.word}, "
      'which is ${isCorrect ? 'correct' : 'wrong'}.',
    );

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln(
        'And here are some unfamiliar vocabulary provided by user:',
      );
      for (String word in unfamiliarWords) {
        buffer.writeln('$word,');
      }
    }

    buffer.writeln("""
Goal: Explain the result above to user in traditional chinese, and record memoryState adjustments in the "memoryStateUpdateResult" field. Correctness is already determined above, do not re-judge it.
Workflow:
1. In "result", tell user in one short sentence whether the answer is correct, and if wrong, which option is correct. Do not explain why there.
2. If the answer is wrong, explain in "review" why the correct option fits the blank and why user's choice does not.
3. Record an entry with word "${correctAnswer.word}" and adjustment "${isCorrect ? 'upgrade' : 'downgrade'}" in "memoryStateUpdateResult".
""");

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln("""
4. Explain in "review" the meaning of each unfamiliar vocabulary as it is used in the sentence.
5. Record an entry with adjustment "downgrade" in "memoryStateUpdateResult" for every unfamiliar vocabulary listed above.
""");
    }

    return buffer.toString();
  }
}
