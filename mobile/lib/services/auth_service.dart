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
    if (accessToken == null) return null;

    _api.setAccessToken(accessToken);

    try {
      final res = await _api.get('/auth/me', auth: true);
      return res['user'] as Map<String, dynamic>;
    } on ApiException catch (e) {
      // Token expirado o inválido: limpiamos y devolvemos null
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