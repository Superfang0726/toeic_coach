import 'package:flutter/material.dart';
import 'package:toeic_coach/models/vocab.dart';


class Store with ChangeNotifier {

  List<Vocab> _vocabulary = [];

  List<Vocab> get vocabulary => _vocabulary;
  
  void updateStore(List<Vocab> target) {
    _vocabulary = target;
    notifyListeners();
  }

  //constructor
  Store();
}