import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/chat/gemini_repository.dart';
import 'package:toeic_coach/chat/prompt_setter.dart';
import 'package:toeic_coach/chat/question_vocab_filter.dart';
import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/models/vocabAdjustment.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class ChatViewModel with ChangeNotifier {
  final Store _store;
  final VocabularyViewmodel _vocabularyViewModel;
  List<Content> _history = [];

  final GeminiRepository _geminiRepository = GeminiRepository();

  //constructor
  ChatViewModel({
    required this._store,
    required VocabularyViewmodel vocabularyViewmodel,
  }) : _vocabularyViewModel = vocabularyViewmodel;

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

    final List<VocabAdjustment?> functionCallsResponse = await _geminiRepository
        .updateMemoryState(_history);

    print('---function call---');
    for (VocabAdjustment? functionCall in functionCallsResponse) {
      print('${functionCall}: ${functionCall.toString()}');
    }

    print('---Processing function call---');
    for (VocabAdjustment? vocabAdjustment in functionCallsResponse) {
      if (vocabAdjustment != null) {
        print(
          '${vocabAdjustment.word}, ${vocabAdjustment.mean}, ${vocabAdjustment.adjustment}',
        );
        _vocabularyViewModel.handleVocabAdjustment(vocabAdjustment);
      }
    }
    //TODO: update UI and Vocab
  }
}
