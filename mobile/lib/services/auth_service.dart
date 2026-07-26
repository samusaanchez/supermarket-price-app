import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  AuthService(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? nombre,
  }) async {
    final res = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      if (nombre != null && nombre.isNotEmpty) 'nombre': nombre,
    });
    return res['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    final accessToken = res['accessToken'] as String;
    final refreshToken = res['refreshToken'] as String;

    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    _api.setAccessToken(accessToken);

    return res['user'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> tryRestoreSession() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);

    if (accessToken == null && refreshToken == null) {
      return null;
    }

    if (accessToken != null) {
      _api.setAccessToken(accessToken);
    }

    if (accessToken == null && refreshToken != null) {
      final newToken = await refreshAccessToken();
      if (newToken == null) return null;
    }

    try {
      final res = await _api.get('/auth/me', auth: true);
      return res['user'] as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        final newToken = await refreshAccessToken();
        if (newToken == null) return null;
        final res = await _api.get('/auth/me', auth: true);
        return res['user'] as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  // Datos frescos del usuario (incluye contadores: tickets, fotos…).
  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/auth/me', auth: true);
    return res['user'] as Map<String, dynamic>;
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return null;

    try {
      final res = await _api.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      final accessToken = res['accessToken'] as String;
      await _storage.write(key: _kAccessToken, value: accessToken);
      _api.setAccessToken(accessToken);
      return accessToken;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    _api.setAccessToken(null);
  }
}
