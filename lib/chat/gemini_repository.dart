import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/models/vocab.dart';

class GeminiRepository {
  GenerativeModel? _generateQuestionModel;
  GenerativeModel? _reviewUserAnswerModel;
  GenerativeModel? _updateMemoryStateModel;

  //constructor
  GeminiRepository();

  //method
  void init({required String apiKey, required String modelName}) {
    _generateQuestionModel = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
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
          requiredProperties: ['sentence', 'options', 'answer'],
        ),
      ),
    );

    _reviewUserAnswerModel = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
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
                    'List all updates of vocabulary memoryState by using ">" to point out upgrade or downgrade in "<word> > <upgrade/downgrade>" pattern',
                nullable: true,
              ),
            ),
          },
          requiredProperties: ['result', 'memoryStateUpdateResult'],
        ),
      ),
    );

    _updateMemoryStateModel = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      tools: [
        Tool(
          functionDeclarations: [
            FunctionDeclaration(
              'updateMemoryState',
              'Use function calling to upgrade or downgrade memoryState according to "memoryStateResult"',
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
                          nullable: false,
                        ),
                        'adjustment': Schema.enumString(
                          enumValues: ['upgrade', 'downgrade'],
                          description:
                              'Use upgrade on vocabulary that answer correct, and use downgrade on vocabulary that answer wrong or unfamiliar',
                          nullable: false,
                        ),
                      },
                      requiredProperties: ['word', 'mean', 'adjustment'],
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

  Future<(GenerateContentResponse, List<Content>)> generateQuestion(
    String message,
  ) async {
    ChatSession session = _generateQuestionModel!.startChat();
    final GenerateContentResponse result = await session.sendMessage(
      Content.text(message),
    );
    return (result, session.history.toList());
  }

  Future<(GenerateContentResponse, List<Content>)> reviewUserAnswer(
    String message,
    List<Content> history,
  ) async {
    ChatSession session = _reviewUserAnswerModel!.startChat(history: history);
    final result = await session.sendMessage(Content.text(message));
    return (result, session.history.toList());
  }

  Future<List<FunctionCall>> updateMemoryState(List<Content> history) async {
    ChatSession session = _updateMemoryStateModel!.startChat(history: history);
    final result = await session.sendMessage(
      Content.text(
        'Use the update function to downgrade those vocabulary that user answered wrong or unfamiliar and upgrade those vocabulary that user answer correct. ',
      ),
    );
    return (result.functionCalls.toList());
  }
}
