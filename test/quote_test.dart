import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/app.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/branco_repository.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/data/sheets_client.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/censimenti/censimenti_logic.dart';
import 'package:lupetti_app/features/common/colori_sestiglie.dart';
import 'package:lupetti_app/features/dati/dati_provider.dart';
import 'package:lupetti_app/models/models.dart';

import 'fake_sheets.dart';
import 'fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;

BrancoData _dati() => BrancoData.daTab(_p, {
  _p.tabDati: fxDati,
  _p.tabCensimenti: fxCensimenti,
  _p.tabPrede: fxPrede,
  _p.tabSestiglie: fxSestiglie,
  _p.tabBilancio: fxBilancio,
});

class _Repo implements BrancoRepository {
  @override
  Future<CaricamentoDati?> daCache() async => null;
  @override
  Future<CaricamentoDati> daRete() async => CaricamentoDati(_dati(), DateTime(2026, 11, 25), daCache: false);
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

  final chiamate = <List<Campo>>[];
  @override
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  }) async => chiamate.add(campi);
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

Future<_Scrittura> _avvia(WidgetTester t) async {
  final w = _Scrittura();
  t.view.physicalSize = const Size(800, 2200);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        repositoryProvider.overrideWithValue(_Repo()),
        scritturaProvider.overrideWithValue(w),
        controlloOnlineProvider.overrideWithValue(() async => true),
      ],
      child: const LupettiApp(),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.text('Quote'));
  await t.pumpAndSettle();
  return w;
}

void main() {
  final lupetti = unisciPerNome(_dati()).lupetti;

  group('logica quote', () {
    Lupetto l(String n) => lupetti.firstWhere((x) => x.nome == n);

    test('stato per voce: pagato, da pagare, non dovuto', () {
      final giulia = l('Giulia Bianchi').censimento!;
      expect(statoVoce(giulia, VoceQuota.censimento), StatoVoce.pagato);
      expect(statoVoce(giulia, VoceQuota.sanFra), StatoVoce.daPagare);
      expect(statoVoce(giulia, VoceQuota.vdb), StatoVoce.pagato);
      expect(statoVoce(giulia, VoceQuota.sanitaria), StatoVoce.pagato); // consegnata
      final mario = l('Mario Rossi').censimento!;
      expect(statoVoce(mario, VoceQuota.sanFra), StatoVoce.nonDovuto); // "/"
      expect(statoVoce(mario, VoceQuota.sanitaria), StatoVoce.daPagare);
    });

    test('conteggi escludono i non dovuti; filtri', () {
      final n = conteggi(lupetti, VoceQuota.censimento);
      expect(n.pagati, 1);
      expect(n.daPagare, 2);
      expect(perVoce(lupetti, VoceQuota.censimento, FiltroQuota.pagati).map((x) => x.nome), ['Giulia Bianchi']);
      expect(perVoce(lupetti, VoceQuota.sanFra, FiltroQuota.tutti).length, 4); // include i non dovuti
      expect(perVoce(lupetti, VoceQuota.sanFra, FiltroQuota.daPagare).map((x) => x.nome), ['Giulia Bianchi']);
    });

    test('data del pagamento per voce', () {
      expect(dataVoce(l('Giulia Bianchi').censimento!, VoceQuota.censimento), DateTime.utc(2026, 10, 5));
      expect(dataVoce(l('Giulia Bianchi').censimento!, VoceQuota.vdb), DateTime.utc(2026, 10, 20));
      expect(dataVoce(l('Mario Rossi').censimento!, VoceQuota.censimento), isNull);
    });

    test('i Fulvi sono rosso vinaccio, diversi dai Rossi', () {
      final f = coloreSestiglia('Fulvi');
      expect(f, const Color(0xFF8A2B3C));
      expect(f, isNot(coloreSestiglia('Rossi')));
    });
  });

  group('correggere un pagamento sbagliato (foglio finto)', () {
    FakeSheets foglio() => FakeSheets({
      _p.tabDati: [for (final r in fxDati) List<Object?>.from(r)],
      _p.tabCensimenti: [for (final r in fxCensimenti) List<Object?>.from(r)],
      _p.tabPrede: [for (final r in fxPrede) List<Object?>.from(r)],
      _p.tabSestiglie: [for (final r in fxSestiglie) List<Object?>.from(r)],
      _p.tabBilancio: [for (final r in fxBilancio) List<Object?>.from(r)],
    });
    SheetsWriteService svc(FakeSheets f) => SheetsWriteService(
      client: SheetsClient(profilo: _p, token: () async => 't', httpClient: f.client),
      online: () async => true,
    );

    test('"non pagato" + data cancellata: il foglio torna com\'era e l\'app lo rilegge', () async {
      final f = foglio();
      final giulia = lupetti.firstWhere((x) => x.nome == 'Giulia Bianchi').censimento!;
      await svc(f).scriviCampi(
        tab: _p.tabCensimenti,
        nomeNelTab: 'Giulia Bianchi',
        campi: [
          Campo(etichetta: 'Censimento', header: 'Censimento', atteso: giulia.censimento, nuovo: 'non pagato'),
          Campo(etichetta: 'Data', header: 'Data', atteso: giulia.dataCensimento, nuovo: ''),
        ],
      );
      final riletto = BrancoData.daTab(_p, {
        for (final e in f.tabs.entries) e.key: e.value,
      }).censimenti.firstWhere((c) => c.nome == 'Giulia Bianchi');
      expect(riletto.censimentoDaPagare, isTrue);
      expect(riletto.dataCensimento, isNull);
      expect(riletto.quotaVdB, 'pagato'); // le altre voci non si toccano
    });

    test('se un altro capo ha cambiato lo stato nel frattempo: conflitto, nulla scritto', () async {
      final f = foglio();
      final giulia = lupetti.firstWhere((x) => x.nome == 'Giulia Bianchi').censimento!;
      f.tabs[_p.tabCensimenti]![2][4] = 'non pagato'; // già annullato da un altro
      await expectLater(
        svc(f).scriviCampi(
          tab: _p.tabCensimenti,
          nomeNelTab: 'Giulia Bianchi',
          campi: [Campo(etichetta: 'Censimento', header: 'Censimento', atteso: giulia.censimento, nuovo: 'non pagato')],
        ),
        throwsA(isA<ConflittoException>()),
      );
      expect(f.scritture, isEmpty);
    });
  });

  group('schermata Quote', () {
    testWidgets('riepilogo con progresso e righe con lo stato scritto', (t) async {
      await _avvia(t);
      expect(find.text('1 su 3 in regola'), findsOneWidget);
      expect(find.text('2 da pagare'), findsOneWidget);
      expect(find.text('Da pagare'), findsWidgets);

      await t.tap(find.text('Pagati'));
      await t.pumpAndSettle();
      expect(find.text('Giulia Bianchi'), findsOneWidget);
      expect(find.text('Pagato il 05/10/2026'), findsOneWidget);
      expect(find.text('Mario Rossi'), findsNothing);

      await t.tap(find.text('Tutti'));
      await t.pumpAndSettle();
      expect(find.text('Mario Rossi'), findsOneWidget);
    });

    testWidgets('"Ho sbagliato": annulla il pagamento e cancella la data', (t) async {
      final w = await _avvia(t);
      await t.tap(find.text('Pagati'));
      await t.pumpAndSettle();
      await t.tap(find.text('Giulia Bianchi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ho sbagliato: NON ha pagato'));
      await t.pumpAndSettle();
      expect(find.textContaining('NON pagato'), findsOneWidget); // conferma esplicita
      await t.tap(find.text('Conferma'));
      await t.pumpAndSettle();

      expect(w.chiamate.length, 1);
      final c = w.chiamate.single;
      expect(c.map((x) => x.header), ['Censimento', 'Data']);
      expect(c[0].atteso, 'pagato');
      expect(c[0].nuovo, 'non pagato');
      expect(c[1].nuovo, ''); // data cancellata
      expect(c[1].atteso, DateTime.utc(2026, 10, 5));
    });

    testWidgets('cambia la data del pagamento senza toccare lo stato', (t) async {
      final w = await _avvia(t);
      await t.tap(find.text('Pagati'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Modifica'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cambia la data del pagamento'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '12/10/2026');
      await t.tap(find.text('Conferma'));
      await t.pumpAndSettle();

      expect(w.chiamate.single.length, 1);
      expect(w.chiamate.single.single.header, 'Data');
      expect(w.chiamate.single.single.nuovo, DateTime.utc(2026, 10, 12));
    });

    testWidgets('chi non deve la quota si può rimettere "da pagare"', (t) async {
      final w = await _avvia(t);
      await t.tap(find.text('Quota SanFra (1)'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tutti'));
      await t.pumpAndSettle();
      await t.tap(find.text('Mario Rossi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Segna come da pagare'));
      await t.pumpAndSettle();
      expect(w.chiamate.single.single.header, 'Quota SanFra');
      expect(w.chiamate.single.single.nuovo, 'non pagato');
    });
  });
}
