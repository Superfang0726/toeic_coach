import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesRepository {
  // late so tests can subclass with I/O-free fakes: SharedPreferencesAsync()
  // throws without a platform implementation, which unit tests don't have.
  late final sharedPreferences = SharedPreferencesAsync();

  //constructor
  SharedPreferencesRepository();

  //method
  Future<void> writeModelName(String modelName) async {
    await sharedPreferences.setString('model', modelName);
  }

  Future<String> readModelName() async =>
      await sharedPreferences.getString('model') ?? 'gemini-3.1-flash-lite';

  Future<void> writeRound(int round) async {
    await sharedPreferences.setInt('round', round);
  }

  Future<int> readRound() async => await sharedPreferences.getInt('round') ?? 0;
}
