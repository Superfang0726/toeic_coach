  //methods
  void addVocab(List<Vocab> currentVocabs, Vocab newVocab) {
    currentVocabs.add(newVocab);
    _writeExcel(currentVocabs);
  }

  List<Vocab> searchVocab(String param) {

  }

  void deleteVocab(List<Vocab> currentVocabs, Vocab target) {
    currentVocabs.removeWhere((vocab) => vocab.word == target.word);
    _writeExcel(currentVocabs);
  }

  void updateVocab(List<Vocab> currentVocabs, Vocab updatedVocab) {
    final int index = currentVocabs.indexWhere((vocab) => vocab.id == updatedVocab.id);
    currentVocabs[index] = updatedVocab;
    _writeExcel(currentVocabs);
  }