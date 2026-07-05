import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/chat/chat_ui.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/settings_ui.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/theme/app_theme.dart';
import 'package:toeic_coach/update/update_dialog.dart';
import 'package:toeic_coach/update/update_viewmodel.dart';
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
  final UpdateViewModel _updateViewModel = UpdateViewModel();
  // Lets us obtain a BuildContext that is a *descendant* of MaterialApp (and
  // therefore has MaterialLocalizations) when showing the update dialog from
  // initState — MainAppState's own `context` sits above MaterialApp.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Check GitHub for a newer release once the first frame is on screen, so
    // startup is never blocked by the network. If one is available, surface
    // the update dialog. A failed/offline check ends silently as "up to date".
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _updateViewModel.checkForUpdate();
      if (!mounted) return;
      if (_updateViewModel.status == UpdateStatus.available) {
        // Fetched fresh after the await and null-checked, so it's safe; the
        // lint can't tie this non-State context to the `mounted` guard above.
        final dialogContext = _navigatorKey.currentContext;
        if (dialogContext != null) {
          // ignore: use_build_context_synchronously
          UpdateDialog.show(dialogContext, _updateViewModel);
        }
      }
    });
  }

  @override
  void dispose() {
    _updateViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('TOEIC Coach'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: kBorder),
          ),
          actions: [
            Builder(
              builder: (context) => Padding(
                padding: EdgeInsetsGeometry.all(10),
                child: IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => SettingsUi(),
                  ),
                  icon: Icon(Icons.settings_outlined, color: kTextSecondary),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            Expanded(child: ChatUi()),
            const VerticalDivider(width: 1, color: kBorder),
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
