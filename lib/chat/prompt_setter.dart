import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/option.dart';

class PromptSetter {
  //method
  static String questionPrompt(
    Vocab answer,
    List<Vocab> distractorPool,
    List<Vocab> greenPool,
  ) {
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Correct answer word: ${answer.word} (meaning: ${answer.mean}).',
    );
    buffer.writeln();
    buffer.writeln('Distractor candidates (red/yellow words):');
    buffer.writeln('| word | mean | level |');
    buffer.writeln('|---|---|---|');
    for (Vocab vocab in distractorPool) {
      buffer.writeln('| ${vocab.word} | ${vocab.mean} | ${vocab.level.name} |');
    }
    buffer.writeln();
    buffer.writeln('Green words available for the sentence:');
    buffer.writeln('| word | mean |');
    buffer.writeln('|---|---|');
    for (Vocab vocab in greenPool) {
      buffer.writeln('| ${vocab.word} | ${vocab.mean} |');
    }
    buffer.writeln(
      """
Goal: Generate one TOEIC Part 5 question whose correct answer is EXACTLY "${answer.word}".
Workflow:
1. The correct answer for the blank MUST be "${answer.word}". Never substitute another word.
2. Choose three distractors for the other choices. Prefer words from the distractor candidates above; if there are fewer than three, fill the rest with plausible TOEIC-level distractors that are not in any table. The three distractors must be clearly wrong in this sentence, either by meaning or by usage.
3. Place the four choices (the correct answer plus the three distractors) at randomly chosen positions among A, B, C and D, and set "answer" to the key holding "${answer.word}".
4. Construct the question sentence using as many relevant green words as possible. It must contain exactly one blank written as "___", and only "${answer.word}" may fit it naturally and grammatically.
5. List in "usedGreenWords" every green word from the table above that you actually used, reported using the EXACT form written in the table. If the sentence inflects a word, still report the table's original form: e.g. if the table lists "announce" but the sentence uses "announced", report "announce"; if the table lists "meeting", report "meeting", never "meet". If you used no green words, return an empty array.""",
    );
    return buffer.toString();
  }

  static String novelQuestionPrompt() {
    return """
Goal: Generate one fresh TOEIC Part 5 vocabulary question from common TOEIC vocabulary. You are not given a word list; choose all words yourself.
Workflow:
1. Choose one correct answer word and three distractors that are grammatically plausible but clearly wrong in the sentence, either by meaning or by usage.
2. Place the four choices at randomly chosen positions among A, B, C and D, and set "answer" to the key holding the correct word.
3. Construct the question sentence: it must contain exactly one blank written as "___", and only the correct choice may fit it naturally and grammatically.
4. Return an empty array for "usedGreenWords".""";
  }

  static String reviewPrompt(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
    List<String> unfamiliarOptionWords,
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

    final List<String> optionWordsToDowngrade = unfamiliarOptionWords
        .where((word) => word != correctAnswer.word)
        .toList();
    if (optionWordsToDowngrade.isNotEmpty) {
      buffer.writeln('User also marked these answer options as unfamiliar:');
      for (String word in optionWordsToDowngrade) {
        buffer.writeln('$word,');
      }
    }

    final bool correctFlaggedUnfamiliar =
        unfamiliarOptionWords.contains(correctAnswer.word);
    final String correctAdjustment =
        (isCorrect && !correctFlaggedUnfamiliar) ? 'upgrade' : 'downgrade';

    buffer.writeln(
      'Goal: Explain the result above to user in traditional chinese, and '
      'record memoryState adjustments in the "memoryStateUpdateResult" '
      'field. Correctness is already determined above, do not re-judge it.',
    );
    buffer.writeln('Workflow:');

    int step = 1;
    buffer.writeln(
      '$step. In "result", tell user in one short sentence whether the '
      'answer is correct, and if wrong, which option is correct. Do not '
      'explain why there.',
    );
    step++;
    buffer.writeln(
      '$step. If the answer is wrong, explain in "review" why the correct '
      "option fits the blank and why user's choice does not.",
    );
    step++;

    final String correctStep =
        '$step. Record an entry with word "${correctAnswer.word}" and '
        'adjustment "$correctAdjustment" in "memoryStateUpdateResult".';
    buffer.writeln(
      (correctFlaggedUnfamiliar && isCorrect)
          ? '$correctStep Even though this answer is correct, the user '
              'marked it unfamiliar, so it must be downgraded, not upgraded.'
          : correctStep,
    );
    step++;

    if (unfamiliarWords.isNotEmpty) {
      buffer.writeln(
        '$step. Explain in "review" the meaning of each unfamiliar '
        'vocabulary from the first unfamiliar list as it is used in the '
        'sentence.',
      );
      step++;
      buffer.writeln(
        '$step. Record an entry with adjustment "downgrade" in '
        '"memoryStateUpdateResult" for every unfamiliar vocabulary in that '
        'first list.',
      );
      step++;
    }

    if (optionWordsToDowngrade.isNotEmpty) {
      buffer.writeln(
        '$step. Explain in "review" what each unfamiliar answer option '
        'word above means.',
      );
      step++;
      buffer.writeln(
        '$step. Record an entry with adjustment "downgrade" in '
        '"memoryStateUpdateResult" for every word in that answer-option '
        'list, even if it is also the correct or user-selected option.',
      );
      step++;
    }

    return buffer.toString();
  }
}
