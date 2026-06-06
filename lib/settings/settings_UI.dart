import 'package:flutter/material.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'settings_viewmodel.dart';
import 'package:provider/provider.dart';

class SettingsUi extends StatefulWidget {
  //constructor
  const SettingsUi({super.key});

  @override
  State<SettingsUi> createState() => _SettingsUiState();
}

class _SettingsUiState extends State<SettingsUi> {
  late TextEditingController _apiKeyController;
  String _selectedModel = '';
  late SettingsViewModel _settingsViewModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = context.read<Store>().modelName;
    _apiKeyController = TextEditingController(
      text: context.read<Store>().apiKey,
    );
    _settingsViewModel = SettingsViewModel(
      store: context.read<Store>(),
      secureStorageRepository: SecureStorageRepository(),
      sharedPreferencesRepository: SharedPreferencesRepository(),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('設定'),
      content: Column(
        spacing: 20,
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('獲得API key: https://aistudio.google.com/api-keys'),
          TextFormField(
            controller: _apiKeyController,
            decoration: InputDecoration(hintText: '輸入API Key'),
          ),
          Text('選擇語言模型', textAlign: TextAlign.left),
          DropdownMenu(
            initialSelection: _selectedModel,
            dropdownMenuEntries: [
              DropdownMenuEntry<String>(
                value: 'gemma-4-31b-it',
                label: 'Gemma 4 31B it (Recommended)',
              ),
              DropdownMenuEntry<String>(
                value: 'gemma-4-26b-a4b-it',
                label: 'Gemma 4 26B a4b it',
              ),
            ],
            onSelected: (value) => _selectedModel = value ?? 'gemma-4-31b-it',
          ),
        ],
      ),
      actions: [
        //取消
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'),
        ),
        //儲存
        TextButton(
          onPressed: () {
            _settingsViewModel.saveSettings(
              _apiKeyController.text,
              _selectedModel,
            );
            Navigator.of(context).pop();
          },
          child: Text('儲存'),
        ),
      ],
    );
  }
}
