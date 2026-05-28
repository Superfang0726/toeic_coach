import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/chat/gemini_repository.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class ChatViewModel with ChangeNotifier {
  Store _store;
  VocabularyViewmodel _vocabularyViewModel;

  GenerativeModel? _generateQuestionModel;
  GenerativeModel? _reviewUserAnswerModel;
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
    if (_store.apiKey == '')
      print('apiError'); //How to implement?
    else {
      _generateQuestionModel = GenerativeModel(
        model: _store.modelName,
        apiKey: _store.apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: Schema.object(properties: Map<String, Schema> {'s':}), //WIP
        ),
      );
      _reviewUserAnswerModel = GenerativeModel(
        model: _store.modelName,
        apiKey: _store.apiKey,
      );
    }
  }
}
