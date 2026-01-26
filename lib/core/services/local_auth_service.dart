import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar autenticación local (biometría y credenciales guardadas)
class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keys para almacenamiento
  static const String _keyUsername = 'saved_username';
  static const String _keyPassword = 'saved_password';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyBiometricEnabled = 'biometric_enabled';

  /// Verifica si el dispositivo soporta biometría
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;

    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  /// Obtiene los tipos de biometría disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];

    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Autentica usando biometría
  Future<bool> authenticateWithBiometrics() async {
    if (kIsWeb) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Usa tu huella o rostro para iniciar sesión',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Error de biometría: $e');
      return false;
    }
  }

  /// Guarda las credenciales de forma segura
  Future<void> saveCredentials(String username, String password) async {
    if (kIsWeb) {
      // En web usamos SharedPreferences (menos seguro pero funcional)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyPassword, password);
    } else {
      // En móvil usamos almacenamiento seguro
      await _secureStorage.write(key: _keyUsername, value: username);
      await _secureStorage.write(key: _keyPassword, value: password);
    }
  }

  /// Obtiene las credenciales guardadas
  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      String? username;
      String? password;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        username = prefs.getString(_keyUsername);
        password = prefs.getString(_keyPassword);
      } else {
        username = await _secureStorage.read(key: _keyUsername);
        password = await _secureStorage.read(key: _keyPassword);
      }

      if (username != null && password != null) {
        return {'username': username, 'password': password};
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo credenciales: $e');
      return null;
    }
  }

  /// Elimina las credenciales guardadas
  Future<void> clearCredentials() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyPassword);
    } else {
      await _secureStorage.delete(key: _keyUsername);
      await _secureStorage.delete(key: _keyPassword);
    }
  }

  /// Guarda la preferencia de "Recordarme"
  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
  }

  /// Obtiene la preferencia de "Recordarme"
  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }

  /// Guarda la preferencia de biometría habilitada
  Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, value);
  }

  /// Obtiene si la biometría está habilitada
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  /// Verifica si hay credenciales guardadas para biometría
  Future<bool> hasSavedCredentialsForBiometric() async {
    final biometricEnabled = await isBiometricEnabled();
    if (!biometricEnabled) return false;

    final credentials = await getSavedCredentials();
    return credentials != null;
  }

  void debugPrint(String message) {
    // ignore: avoid_print
    print(message);
  }
}
