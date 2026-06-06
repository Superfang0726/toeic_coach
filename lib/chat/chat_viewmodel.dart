import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/chat/gemini_repository.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/chat/question_vocab_filter.dart';
import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocab_adjustment.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';
import 'package:toeic_coach/models/chat_state.dart';

class ChatViewModel with ChangeNotifier {
  final Store _store;
  final VocabularyViewmodel _vocabularyViewModel;
  List<Content> _history = [];

  List<String> _unfamiliarWords = [];
  ChatState chatState = ChatState.generatingQuestion;

  late String _sentence;
  late List<Option> _options;
  Option? _selectedOption;
  String? _result;
  List<String> _reviewItems = [];
  List<String> _memoryStateUpdateResult = [];

  List<String> get unfamiliarWords => _unfamiliarWords;
  String get sentence => _sentence;
  List<Option> get options => _options;
  Option? get selectedOption => _selectedOption;
  String? get result => _result;
  List<String> get reviewItems => _reviewItems;
  List<String> get memoryStateAdjustment => _memoryStateUpdateResult;

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
    List<Vocab> filteredVocabulary = QuestionVocabFilter.filter(
      _store.vocabulary,
    );
    String prompt = PromptSetter.questionPrompt(filteredVocabulary);
    final (response, history) = await _geminiRepository.generateQuestion(
      prompt,
    );

    _history = history;

    return response.text ?? 'No response got';
  }

  Future<String?> _userResponse(
    Option userAnswer,
    List<String> unfamiliarWords,
  ) async {
    String prompt = PromptSetter.reviewPrompt(userAnswer, unfamiliarWords);
    final (response, history) = await _geminiRepository.reviewUserAnswer(
      prompt,
      _history,
    );
    _history = history;

    final List<VocabAdjustment?> functionCallsResponse = await _geminiRepository
        .updateMemoryState(_history);

    for (VocabAdjustment? vocabAdjustment in functionCallsResponse) {
      if (vocabAdjustment != null) {
        _vocabularyViewModel.handleVocabAdjustment(vocabAdjustment);
      }
    }

    return response.text;
    //TODO: update UI and Vocab
  }

  ///
  ///The following methods are for chat_UI interactions;
  ///
  Future<void> startQuestion() async {
    //init member variables
    _unfamiliarWords = [];

    //Generating page
    chatState = ChatState.generatingQuestion;
    notifyListeners();

    //Generate question
    final String modelResponse = await _generateQuestion();
    final cleanedText = (modelResponse).trim().replaceAll('```', '');
    final map = jsonDecode(cleanedText);
    _sentence = map['sentence'];
    _options = (map['options'] as List).map((e) {
      final parts = (e as String).split('. ');
      return Option(label: parts[0], word: parts[1]);
    }).toList();

    chatState = ChatState.displayingQuestion;
    notifyListeners();
  }

  Future<void> submitAnswer() async {
    chatState = ChatState.generatingReview;
    notifyListeners();

    final String? modelResponse = await _userResponse(
      selectedOption!,
      unfamiliarWords,
    );
    final map = jsonDecode(modelResponse!);
    _result = map['result'] as String;
    _reviewItems = (map['review'] as List).map((e) => e as String).toList();
    _memoryStateUpdateResult = (map['memoryStateUpdateResult'] as List)
        .map((e) => e as String)
        .toList();

    chatState = ChatState.displayingReview;
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
