import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/models/vocab.dart';


class ExcelRepository {
  
  final String path;

  //constructor
  ExcelRepository(this.path);

  static Future<ExcelRepository> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/vocabulary.xlsx';

    return ExcelRepository(path);
  }

  //methods
  
  //
  //It will return a `List<Vocab>` as a App running storage for eazy read and write
  //
  List<Vocab> readExcel() {

    //Check file is exist
    if (!File(path).existsSync()) {
      return [];
    }

    List<Vocab> vocabulary = [];

    final bytes = File(path).readAsBytesSync();

    final excel = Excel.decodeBytes(bytes);

    final sheet = excel['Sheet1'];

    for (var row in sheet.rows.skip(1)) {
      String? id = row[0]?.value?.toString();
      String? word = row[1]?.value?.toString();
      String? mean = row[2]?.value?.toString();
      Level? level = Level.values.byName(row[3]?.value.toString() ?? 'red');
      MemoryState? memoryState = MemoryState.values.byName(row[4]?.value.toString() ?? 'redLow');
      int cooldown = (row[5]?.value as IntCellValue?)?.value ?? 0;

      if (id == null || word == null || mean == null) continue; //TODO: delete the data which is broken.

      vocabulary.add(Vocab(id: id, word: word, mean: mean, level: level, memoryState: memoryState, cooldown: cooldown));
    }

    return vocabulary;
  }
  
  void writeExcel(List<Vocab> vocabs) {

    final excel = Excel.createExcel();

    final sheet = excel['Sheet1'];

    final headers = ['id', 'word', 'mean', 'level', 'state', 'cooldown'];
    for(int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    for(int i = 0; i < vocabs.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i+1)).value = TextCellValue(vocabs[i].id);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i+1)).value = TextCellValue(vocabs[i].word);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i+1)).value = TextCellValue(vocabs[i].mean);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i+1)).value = TextCellValue(vocabs[i].level.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i+1)).value = TextCellValue(vocabs[i].memoryState.name);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i+1)).value = IntCellValue(vocabs[i].cooldown);
    }

    final bytes = excel.encode();

    File(path).writeAsBytesSync(bytes!);
  }
}