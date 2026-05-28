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
  ChatViewModel({required this._store, required this._vocabularyViewModel});

  // UI 狀態
  // ...

  //method
  void initGeneratvieModels() {}
}
