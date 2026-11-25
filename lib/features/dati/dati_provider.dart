import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/auth/auth_factory_stub.dart' if (dart.library.js_interop) '../../data/auth/auth_factory_web.dart';
import '../../data/auth/auth_service.dart';
import '../../data/branco_repository.dart';
import '../../data/cache_store.dart';
import '../../data/name_matcher.dart';
import '../../data/sheets_client.dart';
import '../../data/write_service.dart';
import '../../models/models.dart';

final profiloProvider = Provider<SheetProfile>((_) => AppConfig.attivo);
final authServiceProvider = Provider<AuthService>((_) => creaAuthService());
final cacheStoreProvider = Provider<CacheStore>((_) => CacheStore());

final repositoryProvider = Provider<BrancoRepository>(
  (ref) => SheetsBrancoRepository(
    profilo: ref.watch(profiloProvider),
    auth: ref.watch(authServiceProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);

/// true se c'è una connessione. Le modifiche sono permesse solo online.
final controlloOnlineProvider = Provider<ControlloOnline>(
  (_) => () async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((c) => c != ConnectivityResult.none);
    } catch (_) {
      return true; // nel dubbio si prova: gli errori di rete sono comunque gestiti
    }
  },
);

final scritturaProvider = Provider<ScritturaService>(
  (ref) => SheetsWriteService(
    client: SheetsClient(profilo: ref.watch(profiloProvider), token: ref.watch(authServiceProvider).token),
    online: ref.watch(controlloOnlineProvider),
  ),
);

/// Stato letto dalle schermate: dati + unione per nome + info su freschezza.
class DatiState {
  const DatiState({
    required this.data,
    required this.unione,
    required this.aggiornatoAl,
    required this.daCache,
    this.avviso,
    this.avvisoRichiedeLogin = false,
    this.offline = false,
  });

  factory DatiState.da(CaricamentoDati c, {String? avviso, bool richiedeLogin = false}) => DatiState(
    data: c.data,
    unione: unisciPerNome(c.data),
    aggiornatoAl: c.aggiornatoAl,
    daCache: c.daCache,
    avviso: avviso,
    avvisoRichiedeLogin: richiedeLogin,
  );

  final BrancoData data;
  final UnioneRisultato unione;
  final DateTime aggiornatoAl;
  final bool daCache;
  final String? avviso;
  final bool avvisoRichiedeLogin;

  /// true se l'ultimo tentativo di aggiornamento è fallito per mancanza di rete.
  final bool offline;

  List<Lupetto> get lupetti => unione.lupetti;

  DatiState conAvviso(String? avviso, {bool richiedeLogin = false, bool offline = false}) => DatiState(
    data: data,
    unione: unione,
    aggiornatoAl: aggiornatoAl,
    daCache: daCache,
    avviso: avviso,
    avvisoRichiedeLogin: richiedeLogin,
    offline: offline,
  );
}

final datiProvider = AsyncNotifierProvider<DatiController, DatiState>(DatiController.new);

/// true mentre è in corso una lettura dal foglio (per mostrare l'indicatore).
class InAggiornamento extends Notifier<bool> {
  @override
  bool build() => false;
  void imposta(bool v) => state = v;
}

final inAggiornamentoProvider = NotifierProvider<InAggiornamento, bool>(InAggiornamento.new);

/// Ogni quanto l'app rilegge il foglio mentre è aperta.
const intervalloAggiornamento = Duration(seconds: 30);

class DatiController extends AsyncNotifier<DatiState> {
  bool _inCorso = false;

  BrancoRepository get _repo => ref.read(repositoryProvider);

  @override
  Future<DatiState> build() async {
    final cache = await _repo.daCache();
    if (cache != null) {
      // Si mostra subito la cache (anche in modalità aereo) e si aggiorna in background.
      Future(aggiorna); // dopo che build() ha pubblicato la cache
      return DatiState.da(cache);
    }
    // Nessuna cache: serve la rete. Gli errori (login, rete) li gestisce la UI.
    return DatiState.da(await _repo.daRete());
  }

  /// Pull-to-refresh e ritorno in primo piano. Non lancia mai: in caso di
  /// problemi tiene i dati attuali e imposta un avviso.
  Future<void> aggiorna() async {
    if (_inCorso) return;
    _inCorso = true;
    ref.read(inAggiornamentoProvider.notifier).imposta(true);
    try {
      final c = await _repo.daRete();
      state = AsyncData(DatiState.da(c));
    } on NonAutenticatoException {
      final prima = state.value;
      if (prima == null) {
        state = AsyncError(NonAutenticatoException(), StackTrace.current);
      } else {
        state = AsyncData(prima.conAvviso('Accedi con Google per aggiornare i dati.', richiedeLogin: true));
      }
    } on RetePersaException {
      final prima = state.value;
      if (prima != null) {
        state = AsyncData(
          prima.conAvviso('Sei offline: stai vedendo i dati dell\'ultimo aggiornamento.', offline: true),
        );
      } else {
        state = AsyncError(RetePersaException(), StackTrace.current);
      }
    } on SheetsException catch (e) {
      final prima = state.value;
      if (e.accessoNegato) {
        // Nessun accesso al foglio = nessun dato visibile nell'app.
        state = AsyncError(e, StackTrace.current);
      } else if (prima != null) {
        state = AsyncData(prima.conAvviso(e.message));
      } else {
        state = AsyncError(e, StackTrace.current);
      }
    } finally {
      _inCorso = false;
      ref.read(inAggiornamentoProvider.notifier).imposta(false);
    }
  }

  /// Ritorno in primo piano e aggiornamento periodico: rilegge solo se i dati
  /// hanno più di [soglia].
  Future<void> aggiornaSeVecchi({Duration soglia = const Duration(minutes: 1)}) async {
    final s = state.value;
    if (s == null) return;
    if (DateTime.now().difference(s.aggiornatoAl) > soglia || s.daCache || s.avviso != null) {
      await aggiorna();
    }
  }
}

final lupettiProvider = Provider<List<Lupetto>>((ref) => ref.watch(datiProvider).value?.lupetti ?? const []);

/// Spese anticipate dai capi e non ancora rimborsate (per il promemoria).
final rimborsiPendentiProvider = Provider<RiepilogoBilancio>(
  (ref) => RiepilogoBilancio(ref.watch(datiProvider).value?.data.movimenti ?? const []),
);
