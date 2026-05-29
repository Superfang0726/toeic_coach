import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/chat/gemini_repository.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/chat/question_vocab_filter.dart';
import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class ChatViewModel with ChangeNotifier {
  Store _store;
  VocabularyViewmodel _vocabularyViewModel;
  List<Content> _history = [];

  ChatSession? _generateQuestionSession;
  ChatSession? _reviewUserAnswerSession;

  final GeminiRepository _geminiRepository = GeminiRepository();

  //constructor
  ChatViewModel({
    required Store store,
    required VocabularyViewmodel vocabularyViewmodel,
  }) : _store = store,
       _vocabularyViewModel = vocabularyViewmodel;

  // UI 狀態
  // ...

  //method
  void initGenerativeModels() {
    _geminiRepository.init(apiKey: _store.apiKey, modelName: _store.modelName);
  }

  Future<void> generateQuestion() async {
    print('Generating question');

    List<Vocab> filteredVocabulary = QuestionVocabFilter.filter(
      _store.vocabulary,
    );
    String prompt = PromptSetter.questionPrompt(filteredVocabulary);
    final (response, history) = await _geminiRepository.generateQuestion(
      prompt,
    );
    _history = history;

    //test
    print('---result---');
    print(response.text);
    print('------------');
    //TODO: update UI
  }

  Future<void> userResponse(
    Option userAnswer,
    List<String> unfamiliarWords,
  ) async {
    String prompt = PromptSetter.reviewPrompt(userAnswer, unfamiliarWords);
    final (response, history) = await _geminiRepository.reviewUserAnswer(
      prompt,
      _history,
    );
    _history = history;

    print('---reviewUserAnswer---');
    print(response.text);

    final functionCallsResponse = await _geminiRepository.updateMemoryState(
      _history,
    );

    print('---function call---');
    for (FunctionCall functionCall in functionCallsResponse) {
      print('${functionCall.name}: ${functionCall.args.toString()}');
    }

    //TODO: update UI and Vocab
  }
}
