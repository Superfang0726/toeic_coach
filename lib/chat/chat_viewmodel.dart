import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  GenerativeModel? _generateQuestionModel;
  GenerativeModel? _reviewUserAnswerModel;
  GenerativeModel? _updateMemoryStateModel;
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
    _generateQuestionModel = GenerativeModel(
      model: _store.modelName,
      apiKey: _store.apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'sentence': Schema.string(
              description:
                  'Generate a sentence with blank as ___ in TOEIC Part 5 pattern',
              nullable: false,
            ),
            'options': Schema.array(
              items: Schema.string(
                description:
                    'Exactly 4 different options labeled A, B, C, D in "<label>. <word>" pattern',
                nullable: false,
              ),
            ),
            'answer': Schema.string(
              description:
                  'The correct answer for the blank in "<label>. <word>" pattern',
              nullable: false,
            ),
          },
        ),
      ),
    );

    _reviewUserAnswerModel = GenerativeModel(
      model: _store.modelName,
      apiKey: _store.apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'result': Schema.string(
              description: "Output if user's answer is correct or not",
              nullable: false,
            ),
            'review': Schema.array(
              items: Schema.string(
                description:
                    'Provide meanings about the vocabulary user is unfamiliar or answer wrong',
                nullable: true,
              ),
            ),
            'memoryStateUpdateResult': Schema.array(
              items: Schema.string(
                description:
                    "List all updates of vocabulary memoryState by using '>' to arrow to the level before and after",
                nullable: true,
              ),
            ),
          },
        ),
      ),
    );

    _updateMemoryStateModel = GenerativeModel(
      model: _store.modelName,
      apiKey: _store.apiKey,
      tools: [
        Tool(
          functionDeclarations: [
            FunctionDeclaration(
              'updateMemoryState',
              "Use function calling to upgrade or downgrade memoryState according to 'memoryStateResult",
              Schema.object(
                properties: {
                  'updates': Schema.array(
                    items: Schema.object(
                      properties: {
                        'word': Schema.string(
                          description: 'The word to update',
                        ),
                        'mean': Schema.string(
                          description:
                              'The means of the word in the sentence or another in traditional chinese',
                        ),
                        'adjustment': Schema.enumString(
                          enumValues: ['upgrade', 'downgrade'],
                          description:
                              'Use upgrade on vocabulary that answer correct, and use downgrade on vocabulary that answer wrong or unfamiliar',
                          nullable: false,
                        ),
                      },
                    ),
                  ),
                },
              ), //items: Schema.object(properties: {Schema.enumString(enumValues: ['upgrade', 'downgrade'], description: 'Use upgrade on vocabulary that answer correct, and use downgrade on vocabulary that answer wrong or unfamiliar', nullable: false)}),
            ),
          ],
        ),
      ],
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig(
          mode: FunctionCallingMode.any,
          allowedFunctionNames: {'updateMemoryState'},
        ),
      ),
    );

    print('---init---');
  }

  Future<void> generateQuestion() async {
    List<Vocab> filteredVocabulary = QuestionVocabFilter.filter(
      _store.vocabulary,
    );
    String prompt = PromptSetter.questionPrompt(filteredVocabulary);
    _generateQuestionSession = _generateQuestionModel!.startChat();
    GenerateContentResponse result = await _generateQuestionSession!
        .sendMessage(Content.text(prompt));

    //test
    print('---result---');
    print(result.text);
    print('------------');
    //TODO: update UI
  }

  Future<void> userResponse(
    Option userAnswer,
    List<String> unfamiliarWords,
  ) async {
    print('Reviewing');

    String prompt = PromptSetter.reviewPrompt(userAnswer, unfamiliarWords);
    _reviewUserAnswerSession = _reviewUserAnswerModel!.startChat(
      history: _generateQuestionSession!.history.toList(),
    );
    GenerateContentResponse result = await _reviewUserAnswerSession!
        .sendMessage(Content.text(prompt));

    print('---reviewUserAnswer---');
    print(result.text);
    print('-----------');

    ChatSession updateMemoryStateSession = _updateMemoryStateModel!.startChat(
      history: _reviewUserAnswerSession!.history.toList(),
    );
    result = await updateMemoryStateSession.sendMessage(
      Content.text(
        'Use the update function to adjust memoryState of those vocabulary that user answered wrong or unfamiliar',
      ),
    );

    //TODO: update UI and Vocab
  }
}
