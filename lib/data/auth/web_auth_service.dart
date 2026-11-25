// Le proprietà JS di Google (client_id, access_token...) hanno questi nomi.
// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:js_interop';

import '../../config/app_config.dart';
import 'auth_service.dart';

/// Login per la versione web (GitHub Pages), con Google Identity Services.
///
/// Il browser riceve un token di accesso a Sheets che dura circa un'ora e lo
/// tiene SOLO in memoria. Alla scadenza si prova a rinnovarlo in silenzio; se
/// Google chiede un'interazione, l'app mostra "Accedi" e basta un tocco.
/// Nessuna password e nessun client secret passano di qui.

@JS('google.accounts.oauth2.initTokenClient')
external _TokenClient _initTokenClient(_TokenClientConfig config);

@JS('google.accounts.oauth2.revoke')
external void _revoke(String token);

@JS('google')
external JSAny? get _google;

extension type _TokenClientConfig._(JSObject _) implements JSObject {
  external factory _TokenClientConfig({
    required String client_id,
    required String scope,
    required String prompt,
    required JSFunction callback,
    required JSFunction error_callback,
  });
}

extension type _TokenClient._(JSObject _) implements JSObject {
  external void requestAccessToken();
}

extension type _TokenResponse._(JSObject _) implements JSObject {
  external String? get access_token;
  external JSAny? get expires_in;
  external String? get error;
}

class WebAuthService implements AuthService {
  String? _token;
  DateTime _scade = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String>? _inCorso;

  bool get _tokenValido => _token != null && DateTime.now().isBefore(_scade.subtract(const Duration(minutes: 2)));

  /// Chiede un token a Google. [prompt] '' = finestra di accesso se serve,
  /// 'none' = solo in silenzio.
  Future<String> _richiedi(String prompt) {
    if (_google == null) {
      return Future.error(StateError('Il servizio di accesso di Google non è stato caricato. Controlla la connessione e ricarica la pagina.'));
    }
    final c = Completer<String>();
    void fallisci() {
      if (!c.isCompleted) c.completeError(NonAutenticatoException());
    }

    final client = _initTokenClient(_TokenClientConfig(
      client_id: AppConfig.googleBrowserClientId,
      scope: AppConfig.scopeSheets,
      prompt: prompt,
      callback: ((_TokenResponse r) {
        final t = r.access_token;
        if (r.error != null || t == null) {
          fallisci();
          return;
        }
        final e = r.expires_in?.dartify();
        final secondi = e is num ? e.toInt() : (int.tryParse('$e') ?? 3600);
        _token = t;
        _scade = DateTime.now().add(Duration(seconds: secondi));
        if (!c.isCompleted) c.complete(t);
      }).toJS,
      error_callback: ((JSAny? _) => fallisci()).toJS,
    ));
    client.requestAccessToken();
    return c.future.timeout(const Duration(seconds: 90), onTimeout: () {
      throw NonAutenticatoException();
    });
  }

  Future<String> _unaSolaVolta(String prompt) {
    final f = _inCorso ??= _richiedi(prompt);
    return f.whenComplete(() => _inCorso = null);
  }

  @override
  Future<bool> accediSilenzioso() async {
    if (_tokenValido) return true;
    try {
      await _unaSolaVolta('none').timeout(const Duration(seconds: 8));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Da chiamare dal tocco su un pulsante (i browser bloccano le finestre
  /// aperte senza un'azione dell'utente).
  @override
  Future<void> accedi() async {
    await _unaSolaVolta('');
  }

  @override
  Future<String> token() async {
    if (_tokenValido) return _token!;
    try {
      return await _unaSolaVolta('none').timeout(const Duration(seconds: 8));
    } catch (_) {
      throw NonAutenticatoException();
    }
  }

  @override
  Future<void> esci() async {
    final t = _token;
    _token = null;
    _scade = DateTime.fromMillisecondsSinceEpoch(0);
    if (t != null && _google != null) {
      try {
        _revoke(t);
      } catch (_) {}
    }
  }
}
