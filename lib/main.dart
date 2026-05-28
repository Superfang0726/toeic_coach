import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/chat/chat_viewmodel.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/vocabulary/database_UI.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';
import 'store/app_store.dart';
import 'vocabulary/excel_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Store store = Store();

  ExcelRepository excelRepository = await ExcelRepository.create();
  SecureStorageRepository secureStorageRepository = SecureStorageRepository();
  SharedPreferencesRepository sharedPreferencesRepository =
      SharedPreferencesRepository();

  ChatViewModel chatViewModel = ChatViewModel();
  chatViewModel.initGeneratvieModels();

  VocabularyViewmodel vocabularyViewmodel = VocabularyViewmodel(
    store: store,
    excelRepository: excelRepository,
  );

  store.updateVocabularyStore(excelRepository.readExcel());
  store.updateApiKeyStore(await secureStorageRepository.readAPI());
  store.updateModelNameStore(await sharedPreferencesRepository.readModelName());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        Provider.value(value: excelRepository),
        Provider.value(value: chatViewModel),
        Provider.value(value: vocabularyViewmodel),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  bool _isDatabaseUiVisible = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            Expanded(child: Placeholder()),
            _isDatabaseUiVisible
                ? Expanded(
                    child: DatabaseUi(
                      isVisible: _isDatabaseUiVisible,
                      onToggle: (value) => setState(() {
                        _isDatabaseUiVisible = value;
                      }),
                    ),
                  )
                : SizedBox(
                    width: 48.0,
                    child: DatabaseUi(
                      isVisible: _isDatabaseUiVisible,
                      onToggle: (value) => setState(() {
                        _isDatabaseUiVisible = value;
                      }),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
