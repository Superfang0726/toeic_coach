import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/excel_repository.dart';

/// Writes an xlsx in the pre-refactor format: 6th column header 'cooldown'.
void writeLegacyFile(String path, {required int cooldown}) {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];

  final headers = ['id', 'word', 'mean', 'level', 'state', 'cooldown'];
  for (int i = 0; i < headers.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        .value = TextCellValue(headers[i]);
  }

  final row = [
    TextCellValue('id-1'),
    TextCellValue('apple'),
    TextCellValue('蘋果'),
    TextCellValue('red'),
    TextCellValue('redLow'),
    IntCellValue(cooldown),
  ];
  for (int i = 0; i < row.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1))
        .value = row[i];
  }

  File(path).writeAsBytesSync(excel.encode()!);
}

void main() {
  late Directory tempDir;
  late String path;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('excel_repo_test');
    path = '${tempDir.path}/vocabulary.xlsx';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('legacy file with cooldown header reads its value as nextDueRound', () {
    writeLegacyFile(path, cooldown: 4);

    final vocabs = ExcelRepository(path).readExcel();

    expect(vocabs.single.word, 'apple');
    expect(vocabs.single.nextDueRound, 4);
  });

  test('writeExcel upgrades the header to nextDueRound and keeps values', () {
    writeLegacyFile(path, cooldown: 4);
    final repository = ExcelRepository(path);

    repository.writeExcel(repository.readExcel());

    final excel = Excel.decodeBytes(File(path).readAsBytesSync());
    final sheet = excel['Sheet1'];
    expect(sheet.rows[0][5]?.value.toString(), 'nextDueRound');

    final reread = repository.readExcel();
    expect(reread.single.nextDueRound, 4);
  });

  test('round-trips a vocab written with the new schema', () {
    final repository = ExcelRepository(path);
    repository.writeExcel([
      Vocab(
        id: 'id-2',
        word: 'audit',
        mean: '稽核',
        level: Level.yellow,
        memoryState: MemoryState.yellowLow,
        nextDueRound: 17,
      ),
    ]);

    final reread = repository.readExcel();
    expect(reread.single.nextDueRound, 17);
  });
}
