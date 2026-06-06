import 'package:flutter/material.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/theme/app_theme.dart';
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
  bool _obscureApiKey = true;

  // Field styling shared by the API key field and the model dropdown so the
  // two read as a matching set.
  InputDecoration _fieldDecoration(String label) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: kSurface,
      labelStyle: const TextStyle(color: kTextSecondary),
      border: border(kBorder, 1),
      enabledBorder: border(kBorder, 1),
      focusedBorder: border(kPrimary, 2),
    );
  }

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
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '設定',
        style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          spacing: 16,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '獲得API key: https://aistudio.google.com/api-keys',
              style: TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            TextFormField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: _fieldDecoration('API Key').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: kTextSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              isExpanded: true,
              decoration: _fieldDecoration('語言模型'),
              items: const [
                DropdownMenuItem<String>(
                  value: 'gemma-4-31b-it',
                  child: Text('Gemma 4 31B it (Recommended)'),
                ),
                DropdownMenuItem<String>(
                  value: 'gemma-4-26b-a4b-it',
                  child: Text('Gemma 4 26B a4b it'),
                ),
              ],
              onChanged: (value) =>
                  _selectedModel = value ?? 'gemma-4-31b-it',
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _settingsViewModel.saveSettings(
                    _apiKeyController.text,
                    _selectedModel,
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('儲存'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: kTextSecondary)),
        ),
      ],
    );
  }
}
