import 'package:flutter/material.dart';
import 'package:toeic_coach/models/vocab.dart';

class Store with ChangeNotifier {
  List<Vocab> _vocabulary = [];
  String _apiKey = '';
  String _modelName = '';
  int _currentRound = 0;

  List<Vocab> get vocabulary => _vocabulary;
  String get apiKey => _apiKey;
  String get modelName => _modelName;
  int get currentRound => _currentRound;

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

  void updateRoundStore(int round) {
    _currentRound = round;
    notifyListeners();
  }

  //constructor
  Store();
}
