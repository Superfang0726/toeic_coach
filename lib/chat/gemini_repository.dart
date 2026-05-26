import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiRepository {
  //constructor
  String apiKey;
  String modelName;

  GeminiRepository({
    required this.apiKey,
    required this.modelName,
  }); //(No need params when implementation)

  GenerativeModel model = GenerativeModel(model: modelName, apiKey: apiKey);
  //method
}

void main() async {
  final apiKey = 'AIzaSyDYPZi5gXCgRnVju9kMC2s5atwXMpOaLpE';
  final modelName = 'gemma-4-31b-it';
  final prompt = 'Say Hello';

  GeminiRepository geminiRepository = GeminiRepository();
}
