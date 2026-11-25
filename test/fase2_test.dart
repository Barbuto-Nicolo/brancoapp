import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/app.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/auth/auth_service.dart';
import 'package:lupetti_app/data/branco_repository.dart';
import 'package:lupetti_app/data/cache_store.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/features/censimenti/censimenti_logic.dart';
import 'package:lupetti_app/features/dati/dati_provider.dart';
import 'package:lupetti_app/features/lupetti/contatti.dart';
import 'package:lupetti_app/features/lupetti/lupetti_logic.dart';
import 'package:lupetti_app/features/sestiglie/sestiglie_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/fixtures.dart';

final _profilo = AppConfig.profili['copia']!;

Map<String, List<List<Object?>>> _tab() => {
      _profilo.tabDati: fxDati,
      _profilo.tabCensimenti: fxCensimenti,
      _profilo.tabPrede: fxPrede,
      _profilo.tabSestiglie: fxSestiglie,
      _profilo.tabBilancio: fxBilancio,
    };

CaricamentoDati _caricamento({bool daCache = false}) =>
    CaricamentoDati(BrancoData.daTab(_profilo, _tab()), DateTime(2026, 11, 24, 10, 30), daCache: daCache);

/// Repository finto: cache opzionale, rete configurabile.
class FakeRepo implements BrancoRepository {
  FakeRepo({this.cache, this.rete});
  final CaricamentoDati? cache;
  final Object? Function()? rete; // lancia l'eccezione o restituisce null = successo
  int chiamateRete = 0;

  @override
  Future<CaricamentoDati?> daCache() async => cache;

  @override
  Future<CaricamentoDati> daRete() async {
    chiamateRete++;
    final e = rete?.call();
    if (e != null) throw e;
    return _caricamento();
  }

  @override
  Future<void> esci() async {}
}

Future<void> _avvia(WidgetTester t, BrancoRepository repo) async {
  t.view.physicalSize = const Size(800, 2000); // schermo alto: niente righe fuori vista
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [repositoryProvider.overrideWithValue(repo)],
    child: const LupettiApp(),
  ));
  await t.pumpAndSettle();
}

void main() {
  final lupetti = unisciPerNome(BrancoData.daTab(_profilo, _tab()), alias: const {}).lupetti;

  group('logica', () {
    test('filtri lupetti: ricerca, anno, sestiglia', () {
      expect(filtraLupetti(lupetti, query: 'rossi').map((l) => l.nome), ['Mario Rossi']);
      expect(filtraLupetti(lupetti, query: 'mario   ROSSI').length, 1);
      expect(filtraLupetti(lupetti, anno: 3).map((l) => l.nome), ['Giulia Bianchi']);
      final grigi = filtraLupetti(lupetti, sestiglia: 'Grigi', annoSestiglia: 2027);
      expect(grigi.map((l) => l.nome), ['Diego Ciccolini']);
    });

    test('sestiglie: composizione e conteggio per anno di cammino', () {
      final g = gruppiSestiglie(lupetti, 2027);
      expect(g.map((x) => x.nome), ['Bianchi', 'Fulvi', 'Grigi', 'Neri', 'Pezzati']);
      final fulvi = g.firstWhere((x) => x.nome == 'Fulvi');
      expect(fulvi.membri.map((m) => m.nome), ['Elena Verdi']);
      expect(fulvi.perAnnoCammino[2], 1);
      final grigi = g.firstWhere((x) => x.nome == 'Grigi');
      expect(grigi.senzaAnno, 1); // Diego Ciccolini: anno di cammino sconosciuto
    });

    test('censimenti: chi deve pagare / consegnare', () {
      expect(daSistemare(lupetti, VoceQuota.censimento).map((l) => l.nome), ['Elena Verdi', 'Mario Rossi']);
      expect(daSistemare(lupetti, VoceQuota.sanFra).map((l) => l.nome), ['Giulia Bianchi']);
      expect(daSistemare(lupetti, VoceQuota.vdb), isEmpty);
      // "sanitaria" FALSE: chi ha una riga in Censimenti e non ha consegnato (anche il segnaposto)
      expect(daSistemare(lupetti, VoceQuota.sanitaria).map((l) => l.nome),
          containsAll(['Mario Rossi', 'Elena Verdi']));
    });

    test('contatti: numeri per WhatsApp', () {
      expect(numeroPerWhatsapp('3000000001'), '393000000001');
      expect(numeroPerWhatsapp('+39 300 000 0001'), '393000000001');
      expect(numeroPerWhatsapp('0039 3000000001'), '393000000001');
      expect(numeroPerWhatsapp('123'), isNull);
      expect(uriMail(' a@b.test ').toString(), 'mailto:a@b.test');
      expect(uriChiamata('300 000 0001').toString(), 'tel:3000000001');
    });
  });

  group('cache', () {
    test('salva, rilegge identica e cancella', () async {
      SharedPreferences.setMockInitialValues({});
      final c = CacheStore();
      expect(await c.leggi('copia'), isNull);
      await c.salva('copia', _tab(), DateTime(2026, 11, 24));
      final r = (await c.leggi('copia'))!;
      expect(r.aggiornatoAl, DateTime(2026, 11, 24));
      expect(r.tab[_profilo.tabSestiglie]!.first, ['Lupetto/a', 2024, 2025, 2026, 2027]);
      expect(r.tab[_profilo.tabBilancio]![4][2], -7.5);
      await c.cancella('copia');
      expect(await c.leggi('copia'), isNull);
    });

    test('cache corrotta → null, senza lanciare', () async {
      SharedPreferences.setMockInitialValues({'cache_v1_copia': '{non json'});
      expect(await CacheStore().leggi('copia'), isNull);
    });
  });

  group('app (widget)', () {
    testWidgets('con rete: mostra le 5 sezioni con i dati', (t) async {
      await _avvia(t, FakeRepo());
      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.textContaining('foglio copia'), findsOneWidget); // chip di collegamento

      await t.tap(find.text('Sestiglie').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Pezzati'), findsWidgets);

      await t.tap(find.text('Quote'));
      await t.pumpAndSettle();
      expect(find.textContaining('Censimento (2)'), findsOneWidget);

      await t.tap(find.text('Prede'));
      await t.pumpAndSettle();
      expect(find.textContaining('Lupo Anziano'), findsWidgets);

      await t.tap(find.text('Bilancio').last);
      await t.pumpAndSettle();
      expect(find.textContaining('257,50'), findsWidgets); // saldo calcolato dall'app
    });

    testWidgets('modalità aereo con cache: si apre e mostra i dati con avviso', (t) async {
      await _avvia(t, FakeRepo(cache: _caricamento(daCache: true), rete: () => RetePersaException()));
      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.textContaining('Sei offline'), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget); // chip: dati salvati sul telefono
    });

    testWidgets('senza cache e senza sessione: schermata di login', (t) async {
      await _avvia(t, FakeRepo(rete: () => NonAutenticatoException()));
      expect(find.text('Accedi con Google'), findsOneWidget);
    });

    testWidgets('senza cache e offline: messaggio chiaro', (t) async {
      await _avvia(t, FakeRepo(rete: () => RetePersaException()));
      expect(find.textContaining('Nessuna connessione'), findsOneWidget);
    });

    testWidgets('scheda lupetto unisce i tab e segnala i tab mancanti', (t) async {
      await _avvia(t, FakeRepo());
      await t.tap(find.text('Mario Rossi'));
      await t.pumpAndSettle();
      expect(find.text('Dati anagrafici'), findsOneWidget);
      expect(find.text('Madre'), findsOneWidget);
      expect(find.text('3000000001'), findsOneWidget);

      await t.pageBack();
      await t.pumpAndSettle();
      await t.enterText(find.byType(SearchBar), 'linda');
      await t.pumpAndSettle();
      await t.tap(find.text('Linda Neri'));
      await t.pumpAndSettle();
      expect(find.textContaining('Non presente nel tab "Dati e recapiti"'), findsOneWidget);
    });

    testWidgets('profilo "copia" attivo di default e nessun uso del reale', (t) async {
      expect(AppConfig.attivo.nome, 'copia');
    });
  });
}
