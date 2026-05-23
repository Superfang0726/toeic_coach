class ExcelRepository {
  
  final String path;

  //constructor
  ExcelRepository(this.path);

  static Future<ExcelRepository> create() async {
    final path = await getApplicationDocumentsDirectory();
    return ExcelRepository(path);
  }

  //methods
  List<Vocab> _readExcel() {

  }
  
  void _writeExcel(List<Vocab> vocabs) {

  }
}