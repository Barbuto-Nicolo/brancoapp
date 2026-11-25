import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lupetti_app/app.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/branco_repository.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/data/parsers/parsers.dart';
import 'package:lupetti_app/data/sheets_client.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/bilancio/bilancio_screen.dart';
import 'package:lupetti_app/features/bilancio/nuovo_movimento_page.dart';
import 'package:lupetti_app/features/dati/dati_provider.dart';
import 'package:lupetti_app/features/home/stato_foglio.dart';
import 'package:lupetti_app/features/sestiglie/nuovo_lupetto_page.dart';
import 'package:lupetti_app/models/models.dart';

import 'fake_sheets.dart';
import 'fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;

List<List<Object?>> _copia(List<List<Object?>> t) => [for (final r in t) List<Object?>.from(r)];

FakeSheets _foglio({List<List<Object?>>? bilancio, Map<String, List<List<Object?>>>? extra}) => FakeSheets({
      _p.tabDati: _copia(fxDati),
      _p.tabCensimenti: _copia(fxCensimenti),
      _p.tabPrede: _copia(fxPrede),
      _p.tabSestiglie: _copia(fxSestiglie),
      _p.tabBilancio: _copia(bilancio ?? fxBilancio),
      ...?extra,
    });

SheetsWriteService _svc(FakeSheets f) => SheetsWriteService(
      client: SheetsClient(profilo: _p, token: () async => 't', httpClient: f.client),
      online: () async => true,
    );

BrancoData _leggi(FakeSheets f) => BrancoData.daTab(_p, {for (final e in f.tabs.entries) e.key: e.value});

/// Bilancio con le colonne dei rimborsi già presenti.
List<List<Object?>> _bilancioRimborsi() => [
      ['Dettagli spese', 'Categoria', 'Costo', 'Data della transazione', 'Pagato da', 'Note', 'Da rimborsare', 'Rimborsata il'],
      ['Conto iniziale', 'Sede', 235, '', '', 'Contanti'],
      ['Colori', 'Materiale', -18, s(2026, 11, 3), 'Akela', '', 'sì'],
      ['Quaderni', 'Attività', -7.5, s(2026, 11, 3), 'Akela', '', 'sì'],
      ['Corda', 'Materiale', -12, s(2026, 10, 1), 'Bagheera', '', 'sì', s(2026, 10, 20)], // già rimborsata
      ['Pane', 'Cibo', -6, s(2026, 11, 9), 'Raksha'], // pagata dalla cassa
      [],
      ['', '', 191.5], // totale
    ];

void main() {
  mainEliminazione();
  group('rimborsi: lettura', () {
    test('il parser legge "Da rimborsare" e "Rimborsata il"; senza colonne tutto è falso', () {
      final m = parseBilancio(_bilancioRimborsi());
      expect(m.where((x) => x.rimborsoPendente).map((x) => x.descrizione), ['Colori', 'Quaderni']);
      expect(m.firstWhere((x) => x.descrizione == 'Corda').rimborsataIl, DateTime.utc(2026, 10, 20));
      expect(m.firstWhere((x) => x.descrizione == 'Pane').daRimborsare, isFalse);
      expect(parseBilancio(fxBilancio).any((x) => x.daRimborsare), isFalse);
    });

    test('riepilogo: quanto spetta a ogni capo e totale', () {
      final r = RiepilogoBilancio(parseBilancio(_bilancioRimborsi()));
      expect(r.rimborsiPerPersona, {'Akela': 25.5});
      expect(r.totaleDaRimborsare, 25.5);
      expect(r.daRimborsare.length, 2);
    });

    test('promemoria: testo con importi e spese', () {
      final t = testoPromemoria(RiepilogoBilancio(parseBilancio(_bilancioRimborsi())));
      expect(t, contains('Akela'));
      expect(t, contains('Colori'));
      expect(t, contains('25,50'));
      expect(t, isNot(contains('Corda')));
    });

    test('parseCapi: con e senza intestazione, senza doppioni', () {
      expect(parseCapi([['Capo/a'], ['Akela'], ['Bagheera '], [], ['akela'], ['Akela']]), ['Akela', 'Bagheera', 'akela']);
      expect(parseCapi([]), isEmpty);
    });
  });

  group('rimborsi: scrittura', () {
    test('nuova spesa anticipata su un foglio senza colonne: crea le 2 intestazioni a destra e scrive "sì"', () async {
      final f = _foglio();
      await _svc(f).aggiungiMovimento(const Movimento(
        descrizione: 'Cartoncini',
        importo: -9,
        categoria: 'Attività',
        pagatoDa: 'Akela',
        daRimborsare: true,
      ));
      final celle = {
        for (final d in f.scritture.single['data'] as List) (d as Map)['range'] as String: (d['values'] as List).first.first,
      };
      expect(celle["'Bilancio'!G1"], 'Da rimborsare');
      expect(celle["'Bilancio'!H1"], 'Rimborsata il');
      // 1ª riga libera sopra il totale: dopo "Quote Caccia" (riga 6) → riga 7.
      expect(celle["'Bilancio'!A7"], 'Cartoncini');
      expect(celle["'Bilancio'!C7"], -9);
      expect(celle["'Bilancio'!G7"], 'sì');
      // Il totale non è mai scritto.
      expect(celle.keys.any((k) => k.contains('!C9') || k.contains('!C8')), isFalse);
      // Riletto dal foglio: la spesa è da rimborsare.
      expect(parseBilancio(f.tabs[_p.tabBilancio]!).last.rimborsoPendente, isTrue);
    });

    test('una spesa normale non crea colonne né intestazioni', () async {
      final f = _foglio();
      await _svc(f).aggiungiMovimento(const Movimento(descrizione: 'Pane', importo: -3, pagatoDa: 'Akela'));
      final range = [for (final d in f.scritture.single['data'] as List) (d as Map)['range'] as String];
      expect(range.any((r) => r.endsWith('!G1') || r.endsWith('!H1')), isFalse);
    });

    test('segna rimborsato: scrive la data SOLO nella riga giusta, senza toccare il resto', () async {
      final f = _foglio(bilancio: _bilancioRimborsi());
      final mov = parseBilancio(f.tabs[_p.tabBilancio]!);
      final daFare = mov.where((m) => m.pagatoDa == 'Akela').toList();
      await _svc(f).segnaRimborsati(daFare, DateTime.utc(2026, 11, 24));

      final celle = {
        for (final d in f.scritture.single['data'] as List) (d as Map)['range'] as String: (d['values'] as List).first.first,
      };
      expect(celle.length, 2);
      expect(celle["'Bilancio'!H3"], s(2026, 11, 24)); // Colori
      expect(celle["'Bilancio'!H4"], s(2026, 11, 24)); // Quaderni
      expect(RiepilogoBilancio(parseBilancio(f.tabs[_p.tabBilancio]!)).daRimborsare, isEmpty);
      // L'importo totale (saldo) non cambia: il rimborso è solo un'annotazione.
      expect(RiepilogoBilancio(parseBilancio(f.tabs[_p.tabBilancio]!)).saldo, RiepilogoBilancio(mov).saldo);
    });

    test('già rimborsata da un altro capo: conflitto e nessuna scrittura', () async {
      final f = _foglio(bilancio: _bilancioRimborsi());
      final colori = parseBilancio(f.tabs[_p.tabBilancio]!).firstWhere((m) => m.descrizione == 'Colori');
      f.tabs[_p.tabBilancio]![2].add(s(2026, 11, 20)); // un altro capo l'ha già segnata (colonna H)
      await expectLater(
        _svc(f).segnaRimborsati([colori], DateTime.utc(2026, 11, 24)),
        throwsA(isA<ConflittoException>()),
      );
      expect(f.scritture, isEmpty);
    });

    test('due spese identiche: ognuna usa la sua riga', () async {
      final b = _bilancioRimborsi()..insert(3, ['Colori', 'Materiale', -18, s(2026, 11, 3), 'Akela', '', 'sì']);
      final f = _foglio(bilancio: b);
      final uguali = parseBilancio(f.tabs[_p.tabBilancio]!).where((m) => m.descrizione == 'Colori').toList();
      expect(uguali.length, 2);
      await _svc(f).segnaRimborsati(uguali, DateTime.utc(2026, 11, 24));
      final r = [for (final d in f.scritture.single['data'] as List) (d as Map)['range'] as String];
      expect(r.toSet().length, 2); // due celle diverse
    });
  });

  group('capi', () {
    test('primo capo: il tab "Capi" viene creato con intestazione e nome', () async {
      final f = _foglio();
      await _svc(f).aggiungiCapo('Akela');
      expect(f.tabCreati, 1);
      expect(f.tabs['Capi'], [
        ['Capo/a'],
        ['Akela'],
      ]);
      await _svc(f).aggiungiCapo('Bagheera');
      expect(f.tabCreati, 1); // non si ricrea
      expect(parseCapi(f.tabs['Capi']!), ['Akela', 'Bagheera']);
    });

    test('capo già presente (anche con maiuscole/spazi diversi): errore, nulla scritto', () async {
      final f = _foglio(extra: {
        'Capi': [
          ['Capo/a'],
          ['Akela'],
        ],
      });
      await expectLater(_svc(f).aggiungiCapo(' akela '), throwsA(isA<CapoGiaPresenteException>()));
      expect(f.numeroScritture, 0);
    });

    test('tab "Capi" con contenuto ma senza intestazione: non si scrive alla cieca', () async {
      final f = _foglio(extra: {
        'Capi': [
          ['Akela'],
        ],
      });
      await expectLater(_svc(f).aggiungiCapo('Baloo'), throwsA(isA<StrutturaException>()));
      expect(f.numeroScritture, 0);
    });
  });

  group('nuovo lupetto', () {
    test('viene aggiunto a tutti i 4 tab e poi si ritrova unito per nome', () async {
      final f = _foglio();
      final esito = await _svc(f).aggiungiLupetto(
        const NuovoLupetto(nome: 'Paolo Gialli', annoCammino: 2, sestiglia: 'Neri', annoSestiglia: 2026),
      );
      expect(esito.completo, isTrue);
      expect(esito.scritti.length, 4);

      final u = unisciPerNome(_leggi(f));
      final l = u.lupetti.firstWhere((x) => x.nome == 'Paolo Gialli');
      expect(l.dati?.anno, '2° anno');
      expect(l.sestiglie?.perAnno[2026], 'Neri');
      expect(l.sestiglie?.perAnno[2027], isNull);
      expect(l.censimento?.censimento, 'non pagato');
      expect(l.censimento?.sanitaria, isFalse);
      expect(l.prede?.stato, 'Non assegnata');
      // Nessun nome sparito o duplicato, report dei nomi invariato per i nuovi.
      expect(u.lupetti.where((x) => x.nome == 'Paolo Gialli').length, 1);
      expect(u.report.mancanti.containsKey('Paolo Gialli'), isFalse);
    });

    test('nome già presente: nessuna scrittura', () async {
      final f = _foglio();
      await expectLater(
        _svc(f).aggiungiLupetto(
          const NuovoLupetto(nome: 'mario  rossi', annoCammino: 3, sestiglia: 'Neri', annoSestiglia: 2026),
        ),
        throwsA(isA<NomeEsistenteException>()),
      );
      expect(f.numeroScritture, 0);
    });

    test('se sotto l\'ultimo nome c\'è altro contenuto, si inserisce una riga e non si scrive sopra', () {
      final valori = <List<Object?>>[
        ['Lupetto/a', 'Anno'],
        ['Mario Rossi', '4° anno'],
        ['', 'Totale', 1], // riga subito sotto (senza nome): contenuto da non sovrascrivere
      ];
      final piano = pianificaRigaNuova(
        tab: 'T',
        valori: valori,
        nome: 'Nuovo Lupo',
        campi: [('Anno', 0, '2° anno')],
      );
      expect(piano.serveInserimento, isTrue);
      expect(piano.indiceInserimento0, 2); // prima della riga dei totali
      expect(piano.celle.first.range, "'T'!A3");
      expect(piano.celle.last.range, "'T'!B3");
    });

    test('colonna mancante in un tab opzionale: si salta, il tab viene scritto lo stesso', () {
      final piano = pianificaRigaNuova(
        tab: 'T',
        valori: [
          ['Lupetto/a'],
          ['Mario Rossi'],
        ],
        nome: 'Nuovo Lupo',
        campi: [('Anno', 0, '2° anno')],
      );
      expect(piano.celle.length, 1);
      expect(piano.serveInserimento, isFalse);
    });

    test('validazione del modulo', () {
      String? v({String nome = 'Paolo Gialli', int? anno = 2, String sest = 'Neri', List<String> esistenti = const []}) =>
          validaNuovoLupetto(nome: nome, anno: anno, sestiglia: sest, nomiEsistenti: esistenti);
      expect(v(), isNull);
      expect(v(nome: 'Paolo'), contains('nome e cognome'));
      expect(v(anno: null), contains('anno'));
      expect(v(sest: ' '), contains('sestiglia'));
      expect(v(esistenti: ['PAOLO gialli']), contains('già'));
    });
  });

  group('movimento: validazione rimborso', () {
    test('anticipata senza "Pagato da": errore', () {
      final r = costruisciMovimento(descrizione: 'Colori', importo: '5', uscita: true, daRimborsare: true);
      expect(r.movimento, isNull);
      expect(r.errore, contains('Pagato da'));
    });
    test('anticipata con capo: ok; su un\'entrata il flag viene ignorato', () {
      final a = costruisciMovimento(
          descrizione: 'Colori', importo: '5', uscita: true, pagatoDa: 'Akela', daRimborsare: true);
      expect(a.movimento!.daRimborsare, isTrue);
      final b = costruisciMovimento(
          descrizione: 'Offerta', importo: '5', uscita: false, pagatoDa: 'Akela', daRimborsare: true);
      expect(b.movimento!.daRimborsare, isFalse);
    });
  });

  group('stato del collegamento', () {
    DatiState dati({String? avviso, bool login = false, bool offline = false}) => DatiState(
          data: _leggi(_foglio()),
          unione: const UnioneRisultato([], ReportNomi(mancanti: {}, suggerimenti: [], duplicati: [])),
          aggiornatoAl: DateTime(2026, 11, 25),
          daCache: false,
          avviso: avviso,
          avvisoRichiedeLogin: login,
          offline: offline,
        );
    test('priorità: aggiornamento > accesso scaduto > offline > errore > collegato', () {
      expect(calcolaStato(dati: dati(), inCorso: true), StatoConnessione.aggiornamento);
      expect(calcolaStato(dati: dati(), inCorso: false), StatoConnessione.connesso);
      expect(calcolaStato(dati: dati(avviso: 'x', login: true), inCorso: false), StatoConnessione.accessoScaduto);
      expect(calcolaStato(dati: dati(avviso: 'x', offline: true), inCorso: false), StatoConnessione.offline);
      expect(calcolaStato(dati: dati(avviso: 'Errore'), inCorso: false), StatoConnessione.errore);
      expect(calcolaStato(dati: null, inCorso: false), StatoConnessione.errore);
    });
  });

  group('schermate', () {
    testWidgets('Bilancio: mostra "Da rimborsare" con il totale e segna rimborsato', (t) async {
      final w = _Scrittura();
      await _avvia(t, w, bilancio: _bilancioRimborsi());
      await t.tap(find.text('Bilancio').last);
      await t.pumpAndSettle();
      expect(find.text('Da rimborsare'), findsWidgets);
      expect(find.textContaining('25,50'), findsWidgets);
      expect(find.text('Akela'), findsWidgets);
      expect(find.textContaining('25,50'), findsWidgets);

      await t.tap(find.widgetWithText(FilledButton, 'Rimborsato tutto a Akela'));
      await t.pumpAndSettle();
      await t.tap(find.text('Conferma')); // data precompilata a oggi
      await t.pumpAndSettle();
      expect(w.rimborsi.length, 1);
      expect(w.rimborsi.single.map((m) => m.descrizione), ['Colori', 'Quaderni']);
    });

    testWidgets('Sestiglie: "Nuovo lupetto" scrive il lupetto scelto', (t) async {
      final w = _Scrittura();
      await _avvia(t, w);
      await t.tap(find.text('Sestiglie').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Nuovo lupetto'));
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).first, 'Paolo Gialli');
      await t.tap(find.text('3° anno'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, 'Fulvi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Aggiungi al foglio'));
      await t.pumpAndSettle();

      expect(w.nuovi.length, 1);
      expect(w.nuovi.single.nome, 'Paolo Gialli');
      expect(w.nuovi.single.annoCammino, 3);
      expect(w.nuovi.single.sestiglia, 'Fulvi');
      expect(w.nuovi.single.annoSestiglia, 2027); // ultimo anno con dati nelle fixture
    });

    testWidgets('Sestiglie: il modulo rifiuta un nome già esistente senza scrivere', (t) async {
      final w = _Scrittura();
      await _avvia(t, w);
      await t.tap(find.text('Sestiglie').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Nuovo lupetto'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Mario Rossi');
      await t.tap(find.text('2° anno'));
      await t.tap(find.widgetWithText(ChoiceChip, 'Neri'));
      await t.pumpAndSettle();
      await t.tap(find.text('Aggiungi al foglio'));
      await t.pumpAndSettle();
      expect(find.textContaining('Esiste già'), findsOneWidget);
      expect(w.nuovi, isEmpty);
    });

    testWidgets('Sestiglie: ogni sestiglia mostra i conteggi per anno di cammino', (t) async {
      await _avvia(t, _Scrittura());
      await t.tap(find.text('Sestiglie').last);
      await t.pumpAndSettle();
      expect(find.text('2°  1'), findsWidgets);
      expect(find.text('4°  1'), findsWidgets);
    });

    testWidgets('testata: il chip dice a che foglio si è collegati e il dettaglio lo spiega', (t) async {
      await _avvia(t, _Scrittura());
      expect(find.textContaining('Collegato'), findsWidgets);
      await t.tap(find.textContaining('Collegato').first);
      await t.pumpAndSettle();
      expect(find.text('BRANCO 2026_2027'), findsOneWidget);
      expect(find.text('Copia di prova'), findsOneWidget);
      expect(find.text('Aggiorna ora'), findsOneWidget);
      expect(find.text('Apri il foglio'), findsOneWidget);
    });
  });
}

class _Repo implements BrancoRepository {
  _Repo(this.bilancio);
  final List<List<Object?>> bilancio;
  @override
  Future<CaricamentoDati?> daCache() async => null;
  @override
  Future<CaricamentoDati> daRete() async => CaricamentoDati(
        BrancoData.daTab(_p, {
          _p.tabDati: fxDati,
          _p.tabCensimenti: fxCensimenti,
          _p.tabPrede: fxPrede,
          _p.tabSestiglie: fxSestiglie,
          _p.tabBilancio: bilancio,
        }),
        DateTime(2026, 11, 25, 14, 30),
        daCache: false,
      );
  @override
  Future<void> esci() async {}
}

class _Scrittura implements ScritturaService {
  final rimborsi = <List<Movimento>>[];
  final nuovi = <NuovoLupetto>[];
  final eliminati = <Map<String, String>>[];

  @override
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  }) async {}
  @override
  Future<String?> aggiungiMovimento(Movimento m) async => null;
  @override
  Future<void> segnaRimborsati(List<Movimento> movimenti, DateTime data) async => rimborsi.add(movimenti);
  @override
  Future<void> aggiungiCapo(String nome) async {}
  @override
  Future<EsitoNuovoLupetto> aggiungiLupetto(NuovoLupetto n) async {
    nuovi.add(n);
    return const EsitoNuovoLupetto(['Dati e recapiti'], {});
  }
  @override
  Future<EsitoEliminazione> eliminaLupetto(Map<String, String> nomiPerTab) async {
    eliminati.add(nomiPerTab);
    return EsitoEliminazione(nomiPerTab.keys.toList(), const {});
  }
}

Future<void> _avvia(WidgetTester t, _Scrittura w, {List<List<Object?>>? bilancio}) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      repositoryProvider.overrideWithValue(_Repo(bilancio ?? fxBilancio)),
      scritturaProvider.overrideWithValue(w),
      controlloOnlineProvider.overrideWithValue(() async => true),
    ],
    child: const LupettiApp(),
  ));
  await t.pumpAndSettle();
}

void mainEliminazione() {
  final p = _p;

  FakeSheets foglio() => _foglio();
  Map<String, String> nomi(String n) => {
        p.tabDati: n,
        p.tabSestiglie: n,
        p.tabCensimenti: n,
        p.tabPrede: n,
      };

  group('eliminare un lupetto', () {
    test('piano: trova la riga giusta; nome assente o doppio sono errori', () {
      final piano = pianificaEliminazione(tab: 'Dati e recapiti', valori: fxDati, nomeNelTab: 'giulia  bianchi');
      expect(piano.rigaA1, 4); // riga vuota + intestazione + Mario + Giulia
      expect(piano.indiceRiga0, 3);
      expect(piano.celleNome, "'Dati e recapiti'!A4");
      expect(() => pianificaEliminazione(tab: 'T', valori: fxDati, nomeNelTab: 'Nessuno Qui'),
          throwsA(isA<LupettoNonTrovatoException>()));
      final doppio = [
        ...fxDati,
        ['Mario Rossi', '3° anno'],
      ];
      expect(() => pianificaEliminazione(tab: 'T', valori: doppio, nomeNelTab: 'Mario Rossi'),
          throwsA(isA<NomeAmbiguoException>()));
    });

    test('rimuove la riga da tutti e 4 i tab e lascia intatti gli altri e il Bilancio', () async {
      final f = foglio();
      final bilancioPrima = _copia(f.tabs[p.tabBilancio]!);
      final esito = await _svc(f).eliminaLupetto(nomi('Giulia Bianchi'));
      expect(esito.eliminati.length, 4);
      expect(esito.saltati, isEmpty);

      final u = unisciPerNome(_leggi(f));
      expect(u.lupetti.any((x) => x.nome == 'Giulia Bianchi'), isFalse);
      // Gli altri restano uniti e completi.
      final mario = u.lupetti.firstWhere((x) => x.nome == 'Mario Rossi');
      expect(mario.dati, isNotNull);
      expect(mario.sestiglie?.perAnno[2026], 'Fulvi');
      expect(mario.censimento, isNotNull);
      expect(u.lupetti.length, unisciPerNome(_leggi(_foglio())).lupetti.length - 1);
      expect(f.tabs[p.tabBilancio], bilancioPrima);
    });

    test('lupetto presente solo in alcuni tab: elimina da quelli e segnala gli altri', () async {
      final f = foglio();
      // Linda Neri c'è in Prede e Sestiglie ma non in Dati e Censimenti.
      final esito = await _svc(f).eliminaLupetto(nomi('Linda Neri'));
      expect(esito.eliminati.toSet(), {p.tabPrede, p.tabSestiglie});
      expect(esito.saltati.keys.toSet(), {p.tabDati, p.tabCensimenti});
      expect(f.eliminazioni, 2);
    });

    test('se la riga si è spostata tra lettura ed eliminazione, non si tocca nulla in quel tab', () async {
      final f = foglio();
      final svc = SheetsWriteService(
        client: SheetsClient(
          profilo: p,
          token: () async => 't',
          // Un altro capo inserisce una riga sopra appena prima della nostra rilettura mirata.
          httpClient: _ConInserimento(f).client,
        ),
        online: () async => true,
      );
      final esito = await svc.eliminaLupetto({p.tabSestiglie: 'Giulia Bianchi'});
      expect(esito.eliminati, isEmpty);
      expect(esito.saltati[p.tabSestiglie], contains('cambiata'));
      expect(f.tabs[p.tabSestiglie]!.any((r) => r.isNotEmpty && r.first == 'Giulia Bianchi'), isTrue);
    });

    test('nome presente due volte in un tab: errore e nessuna eliminazione', () async {
      final f = foglio();
      f.tabs[p.tabPrede]!.add(['Giulia Bianchi', 'Lupo Anziano']);
      await expectLater(_svc(f).eliminaLupetto(nomi('Giulia Bianchi')), throwsA(isA<NomeAmbiguoException>()));
      expect(f.eliminazioni, 0);
    });

    test('offline: nessuna operazione', () async {
      final f = foglio();
      final svc = SheetsWriteService(
        client: SheetsClient(profilo: p, token: () async => 't', httpClient: f.client),
        online: () async => false,
      );
      await expectLater(svc.eliminaLupetto(nomi('Giulia Bianchi')), throwsA(isA<OfflineException>()));
      expect(f.richieste, isEmpty);
    });
  });

  group('eliminare: schermata', () {
    testWidgets('chiede conferma elencando i tab e poi elimina', (t) async {
      final w = _Scrittura();
      await _avvia(t, w);
      await t.tap(find.text('Mario Rossi'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Altre azioni'));
      await t.pumpAndSettle();
      await t.tap(find.text('Elimina lupetto'));
      await t.pumpAndSettle();
      expect(find.text('Eliminare Mario Rossi?'), findsOneWidget);
      expect(find.textContaining('Le spese nel Bilancio non cambiano'), findsOneWidget);
      expect(w.eliminati, isEmpty); // finché non si conferma, nulla

      await t.tap(find.widgetWithText(FilledButton, 'Elimina'));
      await t.pumpAndSettle();
      expect(w.eliminati.length, 1);
      expect(w.eliminati.single.values.toSet(), {'Mario Rossi'});
      expect(w.eliminati.single.length, 4);
    });

    testWidgets('"Annulla" non elimina nulla', (t) async {
      final w = _Scrittura();
      await _avvia(t, w);
      await t.tap(find.text('Mario Rossi'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Altre azioni'));
      await t.pumpAndSettle();
      await t.tap(find.text('Elimina lupetto'));
      await t.pumpAndSettle();
      await t.tap(find.text('Annulla'));
      await t.pumpAndSettle();
      expect(w.eliminati, isEmpty);
    });
  });
}

/// Foglio finto che, alla prima rilettura mirata di una sola cella, simula un altro
/// capo che ha inserito una riga in cima al tab.
class _ConInserimento {
  _ConInserimento(this.f);
  final FakeSheets f;
  bool _fatto = false;

  http.Client get client => MockClient((req) async {
        final path = Uri.decodeFull(req.url.path);
        if (!_fatto && req.method == 'GET' && path.contains('/values/') && path.contains('!A') && !path.contains(':')) {
          _fatto = true;
          f.tabs['Sestiglie']!.insert(1, <Object?>['Intruso', 'X']);
        }
        return req.method == 'GET'
            ? f.client.get(req.url, headers: req.headers)
            : f.client.post(req.url, headers: req.headers, body: req.body);
      });
}
