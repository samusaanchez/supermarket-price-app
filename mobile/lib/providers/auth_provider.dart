import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  String? _lastError;

  AuthProvider(this._authService);

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  String? get lastError => _lastError;

  Future<void> bootstrap() async {
    final user = await _authService.tryRestoreSession();
    if (user != null) {
      _user = user;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _lastError = null;
    try {
      final user = await _authService.login(email: email, password: password);
      _user = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = _humanError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? nombre,
  }) async {
    _lastError = null;
    try {
      await _authService.register(
        email: email,
        password: password,
        nombre: nombre,
      );
      // Después de registrar, hacemos login automático
      return await login(email: email, password: password);
    } catch (e) {
      _lastError = _humanError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _humanError(Object e) {
    final msg = e.toString();
    if (msg.contains('EMAIL_YA_REGISTRADO')) return 'Ese email ya está registrado';
    if (msg.contains('CREDENCIALES_INVALIDAS')) return 'Email o contraseña incorrectos';
    if (msg.contains('PASSWORD_CORTA')) return 'La contraseña debe tener al menos 8 caracteres';
    if (msg.contains('DATOS_INVALIDOS')) return 'Faltan datos';
    return 'Ha ocurrido un error. Inténtalo de nuevo.';
  }
}