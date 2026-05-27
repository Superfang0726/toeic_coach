import 'package:flutter/material.dart';
import 'package:toeic_coach/models/vocab.dart';

class Store with ChangeNotifier {
  List<Vocab> _vocabulary = [];
  String _apiKey = '';

  List<Vocab> get vocabulary => _vocabulary;
  String get apiKey => _apiKey;

  void updateVocabularyStore(List<Vocab> target) {
    _vocabulary = target;
    notifyListeners();
  }

  //constructor
  Store();
}
