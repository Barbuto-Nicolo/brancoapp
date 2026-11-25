import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';

/// Il capo non ha (più) una sessione Google valida.
class NonAutenticatoException implements Exception {
  @override
  String toString() => 'NonAutenticatoException';
}

/// Interfaccia minima: permette di sostituire Google con un finto nei test.
abstract class AuthService {
  /// Prova ad accedere senza interazione. true se c'è una sessione valida.
  Future<bool> accediSilenzioso();

  /// Accesso interattivo (tap sul pulsante). Lancia se annullato o fallito.
  Future<void> accedi();

  /// Token OAuth per Sheets. Lancia [NonAutenticatoException] se non c'è sessione.
  Future<String> token();

  Future<void> esci();
}

class GoogleAuthService implements AuthService {
  static const _scopes = [AppConfig.scopeSheets];

  GoogleSignInAccount? _utente;
  Future<void>? _init;

  Future<void> _inizializza() => _init ??= GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );

  @override
  Future<bool> accediSilenzioso() async {
    try {
      await _inizializza();
      final f = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (f != null) {
        _utente = await f.timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      _utente = null;
    }
    return _utente != null;
  }

  @override
  Future<void> accedi() async {
    await _inizializza();
    _utente = await GoogleSignIn.instance.authenticate(scopeHint: _scopes);
    // Chiede subito il consenso a Sheets, mentre il capo ha appena toccato il pulsante.
    await token();
  }

  @override
  Future<String> token() async {
    if (_utente == null && !await accediSilenzioso()) {
      throw NonAutenticatoException();
    }
    try {
      final client = _utente!.authorizationClient;
      final a = await client.authorizationForScopes(_scopes) ??
          await client.authorizeScopes(_scopes);
      return a.accessToken;
    } on GoogleSignInException {
      throw NonAutenticatoException();
    }
  }

  @override
  Future<void> esci() async {
    _utente = null;
    try {
      await _inizializza();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
