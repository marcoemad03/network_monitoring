import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class JwtManager {
  final FlutterSecureStorage _storage;

  JwtManager(this._storage);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.tokenKey, value: accessToken),
      _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null) return false;
    return !_isTokenExpired(token);
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = _decodeBase64(parts[1]);
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expiryDate =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiryDate.isBefore(
        DateTime.now().add(const Duration(minutes: 1)),
      );
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic> _decodeBase64(String str) {
    final normalized = str.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + (4 - normalized.length % 4) % 4,
      '=',
    );
    final decoded = String.fromCharCodes(
      base64.decode(padded),
    );
    return Map<String, dynamic>.from(
      Uri.splitQueryString(
        decoded.replaceAll('{', '').replaceAll('}', '').replaceAll('"', ''),
      ),
    );
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: AppConstants.tokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
    ]);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
