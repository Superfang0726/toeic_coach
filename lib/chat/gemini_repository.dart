import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiRepository {
  //constructor
  GeminiRepository();

  //method
  Future<String?> sendMessage(String message, ChatSession session) async {
    Content content = Content.text(message);

    GenerateContentResponse response = await session.sendMessage(content);
    return response.text;
    //responseMimeType must be 'application/json', otherwise JsonDecode will go wrong
  }
}
