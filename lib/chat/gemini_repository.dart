import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:toeic_coach/models/vocab_adjustment.dart';

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
            'options': Schema.object(
              properties: {
                'A': Schema.string(
                  description:
                      'A single vocabulary word that is a candidate answer for the blank — '
                      'grammatically plausible and semantically confusable with the other '
                      'choices. Just the word.',
                  nullable: false,
                ),
                'B': Schema.string(
                  description:
                      'A single vocabulary word that is a candidate answer for the blank — '
                      'grammatically plausible and semantically confusable with the other '
                      'choices. Just the word.',
                  nullable: false,
                ),
                'C': Schema.string(
                  description:
                      'A single vocabulary word that is a candidate answer for the blank — '
                      'grammatically plausible and semantically confusable with the other '
                      'choices. Just the word.',
                  nullable: false,
                ),
                'D': Schema.string(
                  description:
                      'A single vocabulary word that is a candidate answer for the blank — '
                      'grammatically plausible and semantically confusable with the other '
                      'choices. Just the word.',
                  nullable: false,
                ),
              },
              requiredProperties: ['A', 'B', 'C', 'D'],
            ),
            'answer': Schema.enumString(
              enumValues: ['A', 'B', 'C', 'D'],
              description: 'The key of the correct choice for the blank.',
              nullable: false,
            ),
            'sentence': Schema.string(
              description:
                  'A sentence in TOEIC Part 5 pattern containing exactly one blank written as "___", which only the correct choice can fill',
              nullable: false,
            ),
          },
          requiredProperties: ['options', 'answer', 'sentence'],
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
              description:
                  "One short sentence in traditional chinese telling user whether the answer is correct, and if wrong, which option is the correct answer. No explanation here.",
              nullable: false,
            ),
            'review': Schema.array(
              items: Schema.string(
                description:
                    "An explanation item in traditional chinese: why the correct option fits the blank and user's choice does not, or the meaning of an unfamiliar vocabulary as used in the sentence. Empty array if the answer is correct and there is no unfamiliar vocabulary.",
                nullable: false,
              ),
            ),
            'memoryStateUpdateResult': Schema.array(
              items: Schema.object(
                properties: {
                  'word': Schema.string(
                    description: 'The vocabulary word whose memoryState changes',
                    nullable: false,
                  ),
                  'adjustment': Schema.enumString(
                    enumValues: ['upgrade', 'downgrade'],
                    description:
                        'upgrade if the word was answered correctly, downgrade if it was answered wrong or flagged unfamiliar',
                    nullable: false,
                  ),
                },
                requiredProperties: ['word', 'adjustment'],
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
              'Use function calling to upgrade or downgrade memoryState according to "memoryStateUpdateResult"',
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
                              'The meaning of the wrong answer or unfamiliar word in traditional chinese',
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
                requiredProperties: ['updates'],
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

  Future<List<VocabAdjustment?>> updateMemoryState(
    List<Content> history,
  ) async {
    ChatSession session = _updateMemoryStateModel!.startChat(history: history);
    final result = await session.sendMessage(
      Content.text(
        'Use the update function to downgrade those vocabulary that user answered wrong or unfamiliar and upgrade those vocabulary that user answer correct. ',
      ),
    );

    return result.functionCalls.expand((call) {
      final updates = call.args['updates'] as List;
      return updates.map((entry) {
        final map = entry as Map;
        return VocabAdjustment(
          word: map['word'].toString(),
          mean: map['mean'].toString(),
          adjustment: Adjustment.values.byName(map['adjustment'].toString()),
        );
      });
    }).toList();
  }
}
