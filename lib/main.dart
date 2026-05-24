import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';
import 'store/app_store.dart';
import 'vocabulary/excel_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Store store = Store();
  ExcelRepository excelRepository = await ExcelRepository.create();
  store.updateStore(excelRepository.readExcel());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        Provider.value(value: excelRepository),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
