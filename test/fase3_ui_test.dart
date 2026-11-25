import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/app.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/branco_repository.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/dati/dati_provider.dart';
import 'package:lupetti_app/models/models.dart';

import 'fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;

class _Repo implements BrancoRepository {
  @override
  Future<CaricamentoDati?> daCache() async => null;
  @override
  Future<CaricamentoDati> daRete() async => CaricamentoDati(
    BrancoData.daTab(_p, {
      _p.tabDati: fxDati,
      _p.tabCensimenti: fxCensimenti,
      _p.tabPrede: fxPrede,
      _p.tabSestiglie: fxSestiglie,
      _p.tabBilancio: fxBilancio,
    }),
    DateTime(2026, 11, 24),
    daCache: false,
  );
  @override
  Future<void> esci() async {}
}

class _Scrittura implements ScritturaService {
  @override
  Future<void> impostaImportoQuota(String quota, double importo) async {}
  @override
  Future<void> creaQuotaExtra(String nome, double importo, List<String> lupetti) async {}
  @override
  Future<void> segnaQuotaExtra({
    required String quota,
    required String lupetto,
    required DateTime? data,
    required bool attesaPagata,
    bool forza = false,
  }) async {}
  @override
  Future<void> eliminaQuotaExtra(String quota) async {}

  _Scrittura({this.conflitto = false});
  final bool conflitto;
  final chiamate = <({String nome, List<Campo> campi, bool forza})>[];

  @override
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  }) async {
    chiamate.add((nome: nomeNelTab, campi: campi, forza: forza));
    if (conflitto && !forza) {
      throw ConflittoException([Conflitto('Censimento', 'pagato', 'non pagato', 'pagato')]);
    }
  }

  @override
  Future<String?> aggiungiMovimento(Movimento m) async => null;

  @override
  Future<void> segnaRimborsati(List<Movimento> movimenti, DateTime data) async {}

  @override
  Future<void> aggiungiCapo(String nome) async {}

  @override
  Future<EsitoNuovoLupetto> aggiungiLupetto(NuovoLupetto n) async => const EsitoNuovoLupetto([], {});

  @override
  Future<EsitoEliminazione> eliminaLupetto(Map<String, String> nomiPerTab) async =>
      EsitoEliminazione(nomiPerTab.keys.toList(), const {});
}

Future<void> _avvia(WidgetTester t, _Scrittura w, {bool online = true}) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        repositoryProvider.overrideWithValue(_Repo()),
        scritturaProvider.overrideWithValue(w),
        controlloOnlineProvider.overrideWithValue(() async => online),
      ],
      child: const LupettiApp(),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Quote'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('segna come pagato: chiede la data e scrive censimento + data', (t) async {
    final w = _Scrittura();
    await _avvia(t, w);
    await t.tap(find.widgetWithText(FilledButton, 'Pagato').first);
    await t.pumpAndSettle();
    expect(find.text('Data (gg/mm/aaaa)'), findsOneWidget);
    await t.tap(find.text('Conferma'));
    await t.pumpAndSettle();
    expect(find.textContaining('quanto costa'), findsOneWidget); // importo ancora ignoto
    await t.tap(find.text('Non registrare'));
    await t.pumpAndSettle();
    expect(w.chiamate.length, 1);
    expect(w.chiamate.single.campi.map((c) => c.header), ['Censimento', 'Data']);
    expect(w.chiamate.single.campi.first.nuovo, 'pagato');
    expect(w.chiamate.single.campi.last.nuovo, isA<DateTime>());
    expect(w.chiamate.single.forza, false);
    expect(find.text('Salvato nel foglio.'), findsOneWidget);
  });

  testWidgets('conflitto: mostra i due valori e chiede quale tenere; "sovrascrivi" riprova con forza', (t) async {
    final w = _Scrittura(conflitto: true);
    await _avvia(t, w);
    await t.tap(find.widgetWithText(FilledButton, 'Pagato').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Conferma'));
    await t.pumpAndSettle();
    expect(find.textContaining('quanto costa'), findsOneWidget); // importo ancora ignoto
    await t.tap(find.text('Non registrare'));
    await t.pumpAndSettle();
    expect(find.text('Un altro capo ha modificato il foglio'), findsOneWidget);
    expect(find.textContaining('Nel foglio ora: pagato'), findsOneWidget);
    expect(find.textContaining('Tu avevi visto: non pagato'), findsOneWidget);
    await t.tap(find.text('Sovrascrivi con il mio'));
    await t.pumpAndSettle();
    expect(w.chiamate.map((c) => c.forza), [false, true]);
  });

  testWidgets('conflitto: "tieni quello del foglio" non scrive di nuovo', (t) async {
    final w = _Scrittura(conflitto: true);
    await _avvia(t, w);
    await t.tap(find.widgetWithText(FilledButton, 'Pagato').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Conferma'));
    await t.pumpAndSettle();
    expect(find.textContaining('quanto costa'), findsOneWidget); // importo ancora ignoto
    await t.tap(find.text('Non registrare'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tieni quello del foglio'));
    await t.pumpAndSettle();
    expect(w.chiamate.length, 1);
  });

  testWidgets('offline: messaggio chiaro e nessuna maschera né scrittura', (t) async {
    final w = _Scrittura();
    await _avvia(t, w, online: false);
    await t.tap(find.widgetWithText(FilledButton, 'Pagato').first);
    await t.pumpAndSettle();
    expect(find.textContaining('Sei offline: le modifiche sono bloccate'), findsOneWidget);
    expect(find.text('Data (gg/mm/aaaa)'), findsNothing);
    expect(w.chiamate, isEmpty);
  });
}
