import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/chat/gemini_repository.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/chat/question_vocab_selector.dart';
import 'package:toeic_coach/chat/retry_handler.dart';
import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocab_adjustment.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';
import 'package:toeic_coach/vocabulary/vocab_domain.dart';
import 'package:toeic_coach/models/chat_state.dart';

class ChatViewModel with ChangeNotifier {
  final Store _store;
  final VocabularyViewmodel _vocabularyViewModel;

  //chatViewModel's default states
  List<Content> _history = [];
  List<String> _unfamiliarWords = [];
  ChatState chatState = ChatState.waitingUserGenerateQuestion;
  int _retryTimes = 0;
  String? _errorMessage;

  //llm response
  late String _sentence;
  late List<Option> _options;
  String _correctLabel = '';
  String? _scheduledAnswerWord;
  Option? _selectedOption;
  String? _result;
  String? _translation;
  bool? _isCorrect;
  List<String> _reviewItems = [];
  List<String> _memoryStateUpdateResult = [];
  List<String> _usedGreenWords = [];

  List<String> get unfamiliarWords => _unfamiliarWords;
  String get sentence => _sentence;
  List<Option> get options => _options;
  String get correctLabel => _correctLabel;
  Option? get selectedOption => _selectedOption;
  String? get result => _result;
  String? get translation => _translation;
  bool? get isCorrect => _isCorrect;
  List<String> get reviewItems => _reviewItems;
  List<String> get memoryStateAdjustment => _memoryStateUpdateResult;
  String? get errorMessage => _errorMessage;
  int get retryTimes => _retryTimes;

  final GeminiRepository _geminiRepository = GeminiRepository();

  //constructor
  ChatViewModel({
    required Store store,
    required VocabularyViewmodel vocabularyViewModel,
  }) : _store = store,
       _vocabularyViewModel = vocabularyViewModel;

  // UI 狀態
  // ...

  //method
  void initGenerativeModels() {
    _geminiRepository.init(apiKey: _store.apiKey, modelName: _store.modelName);
  }

  Future<String> _generateQuestion() async {
    final Vocab? answer = QuestionVocabSelector.pickAnswerWord(
      _store.vocabulary,
      _store.currentRound,
    );
    _scheduledAnswerWord = answer?.word;

    final String prompt;
    if (answer != null) {
      final distractors = QuestionVocabSelector.shuffle(
        QuestionVocabSelector.distractorPool(_store.vocabulary, answer),
      );
      final greens = QuestionVocabSelector.shuffle(
        QuestionVocabSelector.greenPool(_store.vocabulary),
      );
      prompt = PromptSetter.questionPrompt(answer, distractors, greens);
    } else {
      prompt = PromptSetter.novelQuestionPrompt();
    }

    final (response, history) = await _geminiRepository.generateQuestion(prompt);
    _history = history;

    final text = response.text ?? 'No response got';
    _parseQuestion(text);
    return text;
  }

  void _parseQuestion(String modelResponse) {
    final cleanedText = modelResponse.trim().replaceAll('```', '');
    final map = jsonDecode(cleanedText);
    _sentence = map['sentence'];
    final opts = map['options'] as Map<String, dynamic>;
    _options = ['A', 'B', 'C', 'D'].map((k) {
      final word = VocabDomain.canonicalizeWord(
        _store.vocabulary,
        opts[k] as String,
      );
      return Option(label: k, word: word);
    }).toList();

    if (_scheduledAnswerWord != null) {
      final label = QuestionVocabSelector.resolveAnswerLabel(
        _options,
        _scheduledAnswerWord!,
      );
      if (label == null) {
        // Gemini did not place the scheduled word among the options; throw so
        // RetryHandler regenerates instead of showing a wrong question.
        throw StateError(
          'Scheduled answer "$_scheduledAnswerWord" missing from options',
        );
      }
      _correctLabel = label;
    } else {
      _correctLabel = map['answer'] as String;
    }

    _usedGreenWords = ((map['usedGreenWords'] as List?) ?? const [])
        .map((e) => e as String)
        .toList();
  }

  Future<String> _userResponse(
    Option userAnswer,
    Option correctAnswer,
    bool isCorrect,
    List<String> unfamiliarWords,
  ) async {
    String prompt = PromptSetter.reviewPrompt(
      userAnswer,
      correctAnswer,
      isCorrect,
      unfamiliarWords,
    );
    final (response, history) = await _geminiRepository.reviewUserAnswer(
      prompt,
      _history,
    );
    _history = history;

    // Advance the round before scheduling used words so their next due round
    // counts from the round that is about to start (matches the old
    // decrement-then-reset behavior).
    _vocabularyViewModel.incrementRound();

    final List<String> usedWords = [
      ..._options.map((option) => option.word),
      ..._usedGreenWords,
    ];
    _vocabularyViewModel.applyDueForUsedWords(usedWords);

    final List<VocabAdjustment?> functionCallsResponse = await _geminiRepository
        .updateMemoryState(_history);

    for (VocabAdjustment? vocabAdjustment in functionCallsResponse) {
      if (vocabAdjustment != null) {
        _vocabularyViewModel.handleVocabAdjustment(vocabAdjustment);
      }
    }

    return response.text ?? 'No response got';
  }

  ///
  ///The following methods are for chat_UI interactions;
  ///
  Future<void> startQuestion() async {
    initGenerativeModels();

    //init member variables
    _retryTimes = 0;
    _unfamiliarWords = [];
    _selectedOption = null;
    _errorMessage = null;

    //Generating page
    chatState = ChatState.generatingQuestion;
    notifyListeners();

    //Generate question
    final String? modelResponse;
    try {
      modelResponse = await RetryHandler.retryHandler(
        _generateQuestion,
        5,
        onRetry: (currentTimes) {
          _retryTimes = currentTimes;
          notifyListeners();
        },
      );

      if (modelResponse != null) {
        chatState = ChatState.displayingQuestion;
        notifyListeners();
      } else {
        chatState = ChatState.failToGenerateQuestion;
        notifyListeners();
      }
    } catch (error) {
      _handlePermanentError(error);
    }
  }

  Future<void> submitAnswer() async {
    //init member variables
    _retryTimes = 0;
    _errorMessage = null;

    chatState = ChatState.generatingReview;
    notifyListeners();

    final Option correctOption = _options.firstWhere(
      (option) => option.label == _correctLabel,
    );
    _isCorrect = selectedOption!.label == _correctLabel;

    try {
      final String? modelResponse = await RetryHandler.retryHandler(
        () => _userResponse(
          selectedOption!,
          correctOption,
          _isCorrect!,
          unfamiliarWords,
        ),
        5,
        onRetry: (currentTimes) {
          _retryTimes = currentTimes;
          notifyListeners();
        },
      );

      if (modelResponse != null) {
        final map = jsonDecode(modelResponse);
        _result = map['result'] as String;
        _translation = map['sentenceTranslation'] as String;
        _reviewItems = ((map['review'] as List?) ?? const [])
            .map((e) => e as String)
            .toList();
        _memoryStateUpdateResult = (map['memoryStateUpdateResult'] as List).map(
          (e) {
            final entry = e as Map<String, dynamic>;
            return '${entry['word']} > ${entry['adjustment']}';
          },
        ).toList();

        chatState = ChatState.displayingReview;
        notifyListeners();
      } else {
        chatState = ChatState.failToGenerateReview;
        notifyListeners();
      }
    } catch (error) {
      _handlePermanentError(error);
    }
  }

  void _handlePermanentError(Object error) {
    if (_store.apiKey == '') {
      _errorMessage = '尚未設定 API 金鑰，請至設定輸入';
    } else if (error is InvalidApiKey) {
      _errorMessage = 'API 金鑰無效，請至設定確認';
    } else if (error is UnsupportedUserLocation) {
      _errorMessage = '您所在的地區不支援 Google API 調用';
    } else {
      _errorMessage = '發生未預期錯誤，請稍後再試或至設定確認';
    }
    chatState = ChatState.waitingUserGenerateQuestion; // 提到外面設一次
    notifyListeners();
  }

  void toggleUnfamiliarWord(String word) {
    if (_unfamiliarWords.contains(word)) {
      _unfamiliarWords.remove(word);
    } else {
      _unfamiliarWords.add(word);
    }
    notifyListeners();
  }

  void toggleOption(Option option) {
    _selectedOption = option;
    notifyListeners();
  }
}
