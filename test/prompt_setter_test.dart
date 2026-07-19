import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/option.dart';

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

  group('PromptSetter.reviewPrompt', () {
    final correct = Option(label: 'A', word: 'orientation');
    final wrongOption = Option(label: 'B', word: 'analyze');

    test('correct, no flags: records upgrade, no option block', () {
      final prompt =
          PromptSetter.reviewPrompt(correct, correct, true, [], []);
      expect(
        prompt.contains('adjustment "upgrade" in "memoryStateUpdateResult"'),
        isTrue,
      );
      expect(prompt.contains('unfamiliar'), isFalse);
    });

    test('wrong, no flags: records downgrade for correct answer', () {
      final prompt =
          PromptSetter.reviewPrompt(wrongOption, correct, false, [], []);
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
    });

    test('correct answer flagged unfamiliar overrides upgrade to downgrade',
        () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        [],
        ['orientation'],
      );
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
      expect(prompt.contains('adjustment "upgrade"'), isFalse);
      expect(prompt.contains('marked it unfamiliar'), isTrue);
    });

    test(
        'correct answer flagged unfamiliar but already wrong stays '
        'downgrade without override note', () {
      final prompt = PromptSetter.reviewPrompt(
        wrongOption,
        correct,
        false,
        [],
        ['orientation'],
      );
      expect(
        prompt.contains(
          'adjustment "downgrade" in "memoryStateUpdateResult"',
        ),
        isTrue,
      );
      expect(prompt.contains('marked it unfamiliar'), isFalse);
    });

    test('non-correct option flagged unfamiliar adds its own downgrade block',
        () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        [],
        ['analyze'],
      );
      expect(
        prompt.contains(
          'User also marked these answer options as unfamiliar',
        ),
        isTrue,
      );
      expect(prompt.contains('analyze'), isTrue);
      expect(
        prompt.contains('adjustment "upgrade" in "memoryStateUpdateResult"'),
        isTrue,
      );
    });

    test(
        'sentence-unfamiliar and option-unfamiliar blocks both appear '
        'independently', () {
      final prompt = PromptSetter.reviewPrompt(
        correct,
        correct,
        true,
        ['bystander'],
        ['analyze'],
      );
      expect(
        prompt.contains('unfamiliar vocabulary provided by user'),
        isTrue,
      );
      expect(prompt.contains('bystander'), isTrue);
      expect(
        prompt.contains(
          'User also marked these answer options as unfamiliar',
        ),
        isTrue,
      );
      expect(prompt.contains('analyze'), isTrue);
    });
  });
}
