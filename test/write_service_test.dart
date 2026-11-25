import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/sheets_client.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/bilancio/nuovo_movimento_page.dart';
import 'package:lupetti_app/features/common/modifica_campi_page.dart';
import 'package:lupetti_app/models/models.dart';

import 'fake_sheets.dart';
import 'fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;

List<List<Object?>> _copia(List<List<Object?>> t) => [for (final r in t) List<Object?>.from(r)];

FakeSheets _foglio({bool autoTotale = true, List<List<Object?>>? bilancio}) => FakeSheets({
      _p.tabDati: _copia(fxDati),
      _p.tabCensimenti: _copia(fxCensimenti),
      _p.tabPrede: _copia(fxPrede),
      _p.tabSestiglie: _copia(fxSestiglie),
      _p.tabBilancio: _copia(bilancio ?? fxBilancio),
    }, autoTotale: autoTotale);

SheetsWriteService _svc(FakeSheets f, {bool online = true}) => SheetsWriteService(
      client: SheetsClient(profilo: _p, token: () async => 't', httpClient: f.client),
      online: () async => online,
    );

Object? _cella(FakeSheets f, String tab, int riga0, int col) {
  final r = f.tabs[tab]![riga0];
  return col < r.length ? r[col] : null;
}

void main() {
  group('scrittura campi lupetto', () {
    test('segna come pagato: scrive SOLO le 2 celle giuste, con numero seriale per la data', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Mario Rossi', campi: [
        const Campo(etichetta: 'Censimento', header: 'Censimento', atteso: 'non pagato', nuovo: 'pagato'),
        Campo(etichetta: 'Data', header: 'Data', atteso: null, nuovo: DateTime.utc(2026, 11, 24)),
      ]);
      expect(f.scritture.length, 1);
      final dati = f.scritture.single['data'] as List;
      expect(dati.length, 2);
      // Mario Rossi è alla riga 2 del foglio; Censimento = colonna E, Data = colonna F.
      expect(dati[0]['range'], "'Censimenti e quote campi 2526'!E2");
      expect(dati[0]['values'], [['pagato']]);
      expect(dati[1]['range'], "'Censimenti e quote campi 2526'!F2");
      expect(dati[1]['values'], [[s(2026, 11, 24)]]);
      expect(f.scritture.single['valueInputOption'], 'RAW');
      // Le altre celle non sono cambiate.
      expect(_cella(f, _p.tabCensimenti, 1, 6), '/');
      expect(_cella(f, _p.tabCensimenti, 2, 4), 'pagato'); // Giulia: invariata
    });

    test('intestazioni duplicate: "in data" della Quota SanFra = colonna dopo la quota', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Giulia Bianchi', campi: [
        const Campo(etichetta: 'Quota SanFra', header: 'Quota SanFra', atteso: 'non pagato', nuovo: 'pagato'),
        Campo(etichetta: 'Data', header: 'Quota SanFra', offset: 1, atteso: null, nuovo: DateTime.utc(2026, 11, 24)),
      ]);
      final d = f.scritture.single['data'] as List;
      expect(d[0]['range'], endsWith('!G3'));
      expect(d[1]['range'], endsWith('!H3')); // NON la colonna J ("in data" di VdB)
    });

    test('checkbox scritto come booleano', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Mario Rossi', campi: [
        const Campo(etichetta: 'Sanitaria', header: 'sanitaria', atteso: false, nuovo: true),
      ]);
      expect(_cella(f, _p.tabCensimenti, 1, 3), true);
    });

    test('foglio riordinato da browser: la riga si ritrova per nome', () async {
      final f = _foglio();
      // Qualcuno inverte l'ordine delle righe e ne aggiunge una vuota in cima.
      final righe = f.tabs[_p.tabCensimenti]!;
      final dati = righe.sublist(1).reversed.toList();
      righe
        ..removeRange(1, righe.length)
        ..add(<Object?>[])
        ..addAll(dati);
      await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'mario  ROSSI', campi: [
        const Campo(etichetta: 'Censimento', header: 'Censimento', atteso: 'non pagato', nuovo: 'pagato'),
      ]);
      final nuovaRiga = f.tabs[_p.tabCensimenti]!.firstWhere((r) => r.isNotEmpty && r[0] == 'Mario Rossi');
      expect(nuovaRiga[4], 'pagato');
      final altri = f.tabs[_p.tabCensimenti]!.where((r) => r.length > 4 && r[0] != 'Mario Rossi' && r[0] != 'Giulia Bianchi');
      expect(altri.every((r) => r[4] != 'pagato'), true);
    });

    test('conflitto: un altro capo ha cambiato la cella → nessuna scrittura', () async {
      final f = _foglio();
      f.tabs[_p.tabCensimenti]![1][4] = 'pagato'; // l'altro capo ha già segnato
      f.tabs[_p.tabCensimenti]![1][5] = s(2026, 11, 20);
      final campi = [
        const Campo(etichetta: 'Censimento', header: 'Censimento', atteso: 'non pagato', nuovo: 'pagato'),
        Campo(etichetta: 'Data', header: 'Data', atteso: null, nuovo: DateTime.utc(2026, 11, 24)),
      ];
      try {
        await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Mario Rossi', campi: campi);
        fail('doveva lanciare ConflittoException');
      } on ConflittoException catch (e) {
        expect(e.conflitti.map((c) => c.etichetta), ['Censimento', 'Data']);
        expect(e.conflitti.first.attuale, 'pagato');
        expect(e.conflitti.first.atteso, 'non pagato');
      }
      expect(f.numeroScritture, 0);
      expect(_cella(f, _p.tabCensimenti, 1, 5), s(2026, 11, 20)); // data dell'altro capo intatta
    });

    test('conflitto risolto con "sovrascrivi" (forza)', () async {
      final f = _foglio();
      f.tabs[_p.tabCensimenti]![1][4] = 'pagato';
      await _svc(f).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Mario Rossi', forza: true, campi: [
        const Campo(etichetta: 'Censimento', header: 'Censimento', atteso: 'non pagato', nuovo: 'non pagato'),
      ]);
      expect(_cella(f, _p.tabCensimenti, 1, 4), 'non pagato');
    });

    test('nessun falso conflitto: "/" e vuoto sono equivalenti; numeri e testi numerici uguali', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabDati, nomeNelTab: 'Giulia Bianchi', campi: [
        const Campo(etichetta: 'Mail madre', header: 'Madre', offset: 2, atteso: null, nuovo: 'nuova@example.test'), // era "/"
        const Campo(etichetta: 'Tel madre', header: 'Madre', offset: 1, atteso: '3000000003', nuovo: 3111111111), // era numero
      ]);
      expect(_cella(f, _p.tabDati, 3, 9), 'nuova@example.test');
      expect(_cella(f, _p.tabDati, 3, 8), 3111111111);
    });

    test('data già presente come seriale: nessun falso conflitto con DateTime atteso', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabDati, nomeNelTab: 'Mario Rossi', campi: [
        Campo(etichetta: 'Nascita', header: 'il', atteso: DateTime.utc(2015, 5, 19), nuovo: DateTime.utc(2015, 5, 20)),
      ]);
      expect(_cella(f, _p.tabDati, 2, 4), s(2015, 5, 20));
    });

    test('nome non trovato / ambiguo / colonna mancante', () async {
      final f = _foglio();
      expect(
        _svc(f).scriviCampi(tab: _p.tabSestiglie, nomeNelTab: 'Nome Inesistente', campi: [
          const Campo(etichetta: 'x', header: '2027', nuovo: 'Neri'),
        ]),
        throwsA(isA<LupettoNonTrovatoException>()),
      );
      f.tabs[_p.tabSestiglie]!.add(['mario rossi', '/', '/', '/', 'Neri']);
      expect(
        _svc(f).scriviCampi(tab: _p.tabSestiglie, nomeNelTab: 'Mario Rossi', campi: [
          const Campo(etichetta: 'x', header: '2027', nuovo: 'Neri'),
        ]),
        throwsA(isA<NomeAmbiguoException>()),
      );
      expect(
        _svc(_foglio()).scriviCampi(tab: _p.tabSestiglie, nomeNelTab: 'Mario Rossi', campi: [
          const Campo(etichetta: 'x', header: '2030', nuovo: 'Neri'),
        ]),
        throwsA(isA<StrutturaException>()),
      );
    });

    test('sposta in un\'altra sestiglia: scrive la cella dell\'anno giusto', () async {
      final f = _foglio();
      await _svc(f).scriviCampi(tab: _p.tabSestiglie, nomeNelTab: 'Elena Verdi', campi: [
        const Campo(etichetta: 'Sestiglia 2027', header: '2027', atteso: 'Fulvi', nuovo: 'Neri'),
      ]);
      final d = (f.scritture.single['data'] as List).single;
      expect(d['range'], "'Sestiglie'!E5");
      expect(d['values'], [['Neri']]);
    });

    test('offline: blocco immediato, nessuna richiesta, nessuna coda', () async {
      final f = _foglio();
      expect(
        _svc(f, online: false).scriviCampi(tab: _p.tabCensimenti, nomeNelTab: 'Mario Rossi', campi: [
          const Campo(etichetta: 'x', header: 'Censimento', atteso: 'non pagato', nuovo: 'pagato'),
        ]),
        throwsA(isA<OfflineException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(f.richieste, isEmpty);
    });
  });

  group('bilancio: nuovo movimento', () {
    final nuovo = Movimento(
      descrizione: 'Gomme',
      importo: -12.5,
      categoria: 'Materiale',
      data: DateTime.utc(2026, 11, 24),
      pagatoDa: 'Akela',
    );

    test('va nella prima riga vuota sopra il totale, importo numerico, totale intatto', () async {
      final f = _foglio();
      final avviso = await _svc(f).aggiungiMovimento(nuovo);
      expect(avviso, isNull);
      final righe = f.tabs[_p.tabBilancio]!;
      // Ultimo movimento a indice 5 (riga 6) → il nuovo è alla riga 7 (indice 6).
      expect(righe[6][0], 'Gomme');
      expect(righe[6][2], -12.5);
      expect(righe[6][2], isA<num>());
      expect(righe[6][3], s(2026, 11, 24));
      expect(righe[6][4], 'Akela');
      expect(righe.length, fxBilancio.length); // nessuna riga inserita
      expect(f.inserimenti, 0);
      // La riga del totale (ultima) è dov'era e ora vale la somma aggiornata.
      expect(righe.last[0], '');
      expect(righe.last[2], closeTo(245, 1e-9));
      // Solo celle non vuote scritte (note e nessun'altra).
      final range = ((f.scritture.single['data'] as List)).map((d) => d['range']).toList();
      expect(range.every((r) => (r as String).startsWith("'Bilancio'!")), true);
      expect(range.length, 5);
    });

    test('nessuno spazio: inserisce una riga PRIMA del totale', () async {
      final senzaSpazio = <List<Object?>>[
        fxBilancio[0],
        fxBilancio[1],
        fxBilancio[2],
        ['', '', 217], // totale subito sotto l'ultimo movimento
      ];
      final f = _foglio(bilancio: senzaSpazio);
      final avviso = await _svc(f).aggiungiMovimento(nuovo);
      expect(f.inserimenti, 1);
      final righe = f.tabs[_p.tabBilancio]!;
      expect(righe.length, 5);
      expect(righe[3][0], 'Gomme'); // riga inserita al posto del vecchio totale
      expect(righe[4][0], ''); // il totale è sceso di una riga
      expect(righe[4][2], closeTo(235 - 18 - 12.5, 1e-9));
      expect(avviso, isNull);
    });

    test('se la formula del totale non include la riga nuova: avviso, nessuna modifica al totale', () async {
      final f = _foglio(autoTotale: false);
      final avviso = await _svc(f).aggiungiMovimento(nuovo);
      expect(avviso, contains('totale'));
      expect(f.tabs[_p.tabBilancio]!.last[2], 257.5); // totale mai toccato dall'app
    });

    test('riga di destinazione occupata nel frattempo: conflitto, nessuna sovrascrittura', () async {
      final f = _foglio();
      // Simula l'altro capo: dopo la lettura del tab, riempie la riga 7.
      var letture = 0;
      final originale = f.client;
      final svc = SheetsWriteService(
        client: SheetsClient(
          profilo: _p,
          token: () async => 't',
          httpClient: _Intercetta(originale, () {
            letture++;
            if (letture == 1) {
              f.tabs[_p.tabBilancio]![6] = ['Altro capo', 'Cibo', -5, '', 'Raksha'];
            }
          }),
        ),
        online: () async => true,
      );
      // Il primo GET (leggiTab) restituisce lo stato pre-modifica; poi la riga viene occupata.
      expect(svc.aggiungiMovimento(nuovo), throwsA(isA<ConflittoException>()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(f.tabs[_p.tabBilancio]![6][0], 'Altro capo');
      expect(f.scritture, isEmpty);
    });

    test('costruisciMovimento: validazione e segno', () {
      expect(costruisciMovimento(descrizione: '', importo: '5', uscita: true).errore, isNotNull);
      expect(costruisciMovimento(descrizione: 'a', importo: 'abc', uscita: true).errore, isNotNull);
      expect(costruisciMovimento(descrizione: 'a', importo: '-3', uscita: true).errore, isNotNull);
      expect(costruisciMovimento(descrizione: 'a', importo: '1', uscita: true, data: '31/02/2026').errore, isNotNull);
      expect(costruisciMovimento(descrizione: 'a', importo: '7,5', uscita: true).movimento!.importo, -7.5);
      expect(costruisciMovimento(descrizione: 'a', importo: '1.234,50', uscita: false).movimento!.importo, 1234.5);
    });
  });

  group('maschera di modifica', () {
    test('converti: telefoni come numeri, testi come testi, date come DateTime', () {
      expect(ModificaCampiPageStateAccess.converti(TipoCampo.numerico, '3331234567'), 3331234567);
      expect(ModificaCampiPageStateAccess.converti(TipoCampo.numerico, '0532 123'), '0532 123');
      expect(ModificaCampiPageStateAccess.converti(TipoCampo.testo, '  ciao '), 'ciao');
      expect(ModificaCampiPageStateAccess.converti(TipoCampo.testo, ''), '');
      expect(ModificaCampiPageStateAccess.converti(TipoCampo.data, '05/08/2017'), DateTime.utc(2017, 8, 5));
      expect(() => ModificaCampiPageStateAccess.converti(TipoCampo.data, '99/99/2017'), throwsFormatException);
    });
  });
}

/// Accesso al convertitore statico (privato per lo stato) per i test.
class ModificaCampiPageStateAccess {
  static Object? converti(TipoCampo t, String s) => convertiCampo(t, s);
}

/// Client che esegue un'azione dopo la prima richiesta GET (simula un altro capo).
class _Intercetta extends _Delegating {
  _Intercetta(super.inner, this.dopoPrimoGet);
  final void Function() dopoPrimoGet;
  bool _fatto = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = await super.send(request);
    if (!_fatto && request.method == 'GET') {
      _fatto = true;
      // La risposta è già stata costruita con lo stato pre-modifica: ora cambia il foglio.
      dopoPrimoGet();
    }
    return r;
  }
}

class _Delegating extends http.BaseClient {
  _Delegating(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => inner.send(request);
}
