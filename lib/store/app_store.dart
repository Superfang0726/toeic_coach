import 'package:flutter/material.dart';
import 'package:toeic_coach/models/vocab.dart';

class Store with ChangeNotifier {
  List<Vocab> _vocabulary = [];
  String _apiKey = '';
  String _modelName = '';

  List<Vocab> get vocabulary => _vocabulary;
  String get apiKey => _apiKey;
  String get modelName => _modelName;

  void updateVocabularyStore(List<Vocab> target) {
    _vocabulary = target;
    notifyListeners();
  }

  void updateApiKeyStore(String apiKey) {
    _apiKey = apiKey;
    notifyListeners();
  }

  void updateModelNameStore(String modelName) {
    _modelName = modelName;
    notifyListeners();
  }

  //constructor
  Store();
}
