import 'package:flutter/material.dart';
import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/theme/app_theme.dart';
import 'package:toeic_coach/update/update_dialog.dart';
import 'package:toeic_coach/update/update_viewmodel.dart';
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
  final UpdateViewModel _updateViewModel = UpdateViewModel();
  bool _obscureApiKey = true;
  bool _checkingForUpdate = false;

  // Manually checks GitHub for a newer release. Shows the update dialog when one
  // exists, otherwise a brief "already up to date" message.
  Future<void> _checkForUpdates() async {
    setState(() => _checkingForUpdate = true);
    await _updateViewModel.checkForUpdate();
    if (!mounted) return;
    setState(() => _checkingForUpdate = false);
    if (_updateViewModel.status == UpdateStatus.available) {
      UpdateDialog.show(context, _updateViewModel);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已是最新版本（${_updateViewModel.currentVersion}）')),
      );
    }
  }

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
    _updateViewModel.dispose();
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
                  value: 'gemini-3.1-flash-lite',
                  child: Text('Gemini 3.1 flash lite (Recommended)'),
                ),
                DropdownMenuItem<String>(
                  value: 'gemma-4-31b-it',
                  child: Text('Gemma 4 31B it'),
                ),
              ],
              onChanged: (value) =>
                  _selectedModel = value ?? 'gemini-3.1-flash-lite',
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
          onPressed: _checkingForUpdate ? null : _checkForUpdates,
          child: _checkingForUpdate
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  '檢查更新',
                  style: TextStyle(color: kTextSecondary),
                ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: kTextSecondary)),
        ),
      ],
    );
  }
}
