//lib\core\services\storage_service.dart

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const String _tokenKey = 'authToken';
  static const String _partnerIdKey = 'partnerId';
  static const String _partnerStatusKey = 'partnerStatus';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> savePartnerId(String id) async {
    await _storage.write(key: _partnerIdKey, value: id);
  }

  static Future<String?> getPartnerId() async {
    return await _storage.read(key: _partnerIdKey);
  }

  static Future<void> savePartnerStatus(String status) async {
    await _storage.write(key: _partnerStatusKey, value: status);
  }

  static Future<String?> getPartnerStatus() async {
    return await _storage.read(key: _partnerStatusKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
