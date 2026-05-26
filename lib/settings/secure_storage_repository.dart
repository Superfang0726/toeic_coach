import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageRepository {
  final storage = FlutterSecureStorage();

  //constructor
  SecureStorageRepository();

  //methods
  Future<void> writeAPI(String apiKey) async {
    await storage.write(key: 'api_key', value: apiKey);
  }

  Future<String?> readAPI() async => await storage.read(key: 'api_key');

  Future<void> deleteAPI() async {
    await storage.delete(key: 'api_key');
  }
}
