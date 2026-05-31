import 'package:toeic_coach/settings/secure_storage_repository.dart';
import 'package:toeic_coach/settings/shared_preferences_repository.dart';
import 'package:toeic_coach/store/app_store.dart';

class SettingsViewModel {
  final Store _store;
  final SecureStorageRepository _secureStorageRepository;
  final SharedPreferencesRepository _sharedPreferencesRepository;

  //constructor
  SettingsViewModel({
    required this._store,
    required this._secureStorageRepository,
    required this._sharedPreferencesRepository,
  });

  //methods
  Future<void> saveSettings(String apiKey, String modelName) async {
    await _secureStorageRepository.writeAPI(apiKey);
    await _sharedPreferencesRepository.writeModelName(modelName);
    _store.updateApiKeyStore(apiKey);
    _store.updateModelNameStore(modelName);
  }
}
