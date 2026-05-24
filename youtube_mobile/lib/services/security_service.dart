import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  bool _vaultLocked = false;

  bool get isVaultLocked => _vaultLocked;

  Future<bool> get isLockEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('vault_security_enabled') ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vault_security_enabled', enabled);
    if (!enabled) {
      _vaultLocked = false;
    }
  }

  Future<bool> canAuthenticate() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticate(String reason) async {
    final enabled = await isLockEnabled;
    if (!enabled) {
      _vaultLocked = false;
      return true;
    }

    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (didAuthenticate) {
        _vaultLocked = false;
      }
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }

  void lockVault() {
    _vaultLocked = true;
  }
}
