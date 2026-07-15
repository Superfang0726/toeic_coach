import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/models/vocab.dart';

Vocab v(String word, String mean, Level level, MemoryState state) => Vocab(
      id: word,
      word: word,
      mean: mean,
      level: level,
      memoryState: state,
      nextDueRound: 0,
    );

void main() {
  group('PromptSetter.questionPrompt', () {
    final answer = v('orientation', '新人訓練', Level.yellow, MemoryState.yellowLow);
    final distractors = [v('analyze', '分析', Level.red, MemoryState.redLow)];
    final greens = [v('attend', '參加', Level.green, MemoryState.green)];

    test('names the fixed correct answer word', () {
      final prompt = PromptSetter.questionPrompt(answer, distractors, greens);
      expect(prompt.contains('orientation'), isTrue);
      expect(prompt.contains('MUST'), isTrue);
    });

    test('includes distractor and green candidate words', () {
      final prompt = PromptSetter.questionPrompt(answer, distractors, greens);
      expect(prompt.contains('analyze'), isTrue);
      expect(prompt.contains('attend'), isTrue);
    });
  });

  group('PromptSetter.novelQuestionPrompt', () {
    test('asks for a fresh question and an empty usedGreenWords', () {
      final prompt = PromptSetter.novelQuestionPrompt();
      expect(prompt.contains('TOEIC Part 5'), isTrue);
      expect(prompt.contains('usedGreenWords'), isTrue);
    });
  });
}
