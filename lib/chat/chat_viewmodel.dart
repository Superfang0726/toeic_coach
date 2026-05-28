import 'package:google_generative_ai/google_generative_ai.dart';

class ChatViewmodel {
  late GenerativeModel _generativeModel;
  //constructor

  //method
  GenerativeModel initGenerativeModel({
    required String modelName,
    required String apiKey,
  }) {
    _generativeModel = GenerativeModel(model: modelName, apiKey: apiKey);
  }
}
