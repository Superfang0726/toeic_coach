import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesRepository {
  final sharedPreferences = SharedPreferencesAsync();

  //constructor
  SharedPreferencesRepository();

  //method
  Future<void> writeModelName(String modelName) async {
    await sharedPreferences.setString('model', modelName);
  }

  Future<String> readModelName() async =>
      await sharedPreferences.getString('model') ?? 'gemma-4-31b-it';
}
