import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/chat/chat_ui.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/settings_ui.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/vocabulary/database_ui.dart';
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

  store.updateVocabularyStore(excelRepository.readExcel());
  store.updateApiKeyStore(await secureStorageRepository.readAPI());
  store.updateModelNameStore(await sharedPreferencesRepository.readModelName());

  VocabularyViewmodel vocabularyViewmodel = VocabularyViewmodel(
    store: store,
    excelRepository: excelRepository,
  );

  ///
  ///TEST
  ///
  // store.updateApiKeyStore('AIzaSyDYPZi5gXCgRnVju9kMC2s5atwXMpOaLpE');
  // store.updateModelNameStore('gemma-4-31b-it');
  // store.updateVocabularyStore([
  //   Vocab(
  //     id: '',
  //     word: 'recession',
  //     mean: '經濟衰退',
  //     level: Level.red,
  //     memoryState: MemoryState.redLow,
  //     cooldown: 0,
  //   ),
  //   Vocab(
  //     id: '',
  //     word: 'finance',
  //     mean: '經濟',
  //     level: Level.green,
  //     memoryState: MemoryState.green,
  //     cooldown: 0,
  //   ),
  // ]);
  // chatViewModel.initGenerativeModels();
  // await chatViewModel.generateQuestion();

  // print('running userResponse method');
  // await chatViewModel.userResponse(Option(label: 'A', word: 'recession'), []);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        Provider.value(value: excelRepository),
        // Provider.value(value: chatViewModel),
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
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('TOIEC Coach'),
          actions: [
            Builder(
              builder: (context) => Padding(
                padding: EdgeInsetsGeometry.all(10),
                child: IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => SettingsUi(),
                  ),
                  icon: Icon(Icons.settings),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            Expanded(child: ChatUi()),
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
