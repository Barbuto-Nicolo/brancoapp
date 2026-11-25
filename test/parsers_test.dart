import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/data/parsers/cell_utils.dart';
import 'package:lupetti_app/data/parsers/parsers.dart';
import 'package:lupetti_app/models/models.dart';

import 'fixtures/fixtures.dart';

void main() {
  group('cell_utils', () {
    test('cellText: vuoto, "/" e numeri', () {
      expect(cellText(null), isNull);
      expect(cellText('  '), isNull);
      expect(cellText('/'), isNull);
      expect(cellText(3000000001), '3000000001');
      expect(cellText(12.0), '12');
      expect(cellText(' ciao '), 'ciao');
    });
    test('cellNumber: numeri e stringhe valuta italiane', () {
      expect(cellNumber(-7.5), -7.5);
      expect(cellNumber('-7,5'), -7.5);
      expect(cellNumber('-€ 7,50'), -7.5);
      expect(cellNumber('€ 1.234,50'), 1234.5);
      expect(cellNumber('abc'), isNull);
      expect(cellNumber(''), isNull);
    });
    test('cellDate: seriale e testo; date impossibili rifiutate', () {
      expect(cellDate(s(2015, 5, 19)), DateTime.utc(2015, 5, 19));
      expect(cellDate('03/11/2026'), DateTime.utc(2026, 11, 3));
      expect(cellDate('31/02/2026'), isNull);
      expect(cellDate(''), isNull);
    });
    test('normalizeName ignora maiuscole, spazi e "_"', () {
      expect(normalizeName('Diego ____'), 'diego');
      expect(normalizeName(' Maria  Rosa '), 'mariarosa');
    });
  });

  group('parseDati', () {
    final dati = parseDati(fxDati);
    test('trova l\'intestazione anche se non è la riga 1 e salta righe vuote', () {
      expect(dati.map((d) => d.nome), ['Mario Rossi', 'Giulia Bianchi', 'Diego ____', 'Elena Verdi']);
    });
    test('mappa recapito/mail per posizione dopo Madre e Padre', () {
      final m = dati.first;
      expect(m.madre!.nome, 'Anna Rossi');
      expect(m.madre!.telefono, '3000000001'); // numero → stringa
      expect(m.madre!.email, 'anna@example.test');
      expect(m.padre!.telefono, '3000000002');
      expect(m.padre!.email, 'luca@example.test');
      expect(m.dataNascita, DateTime.utc(2015, 5, 19));
      expect(m.annoNumero, 4);
    });
    test('"/" e celle vuote diventano null', () {
      final g = dati[1];
      expect(g.madre!.email, isNull);
      expect(g.padre!.telefono, isNull);
      expect(g.padre!.email, 'stefano@example.test');
      expect(g.natoA, isNull);
    });
    test('riga corta (segnaposto) non rompe', () {
      final d = dati[2];
      expect(d.anno, isNull);
      expect(d.madre, isNull);
      expect(d.padre, isNull);
    });
    test('tab senza àncora → lista vuota', () {
      expect(parseDati([['x', 'y']]), isEmpty);
      expect(parseDati([]), isEmpty);
    });
  });

  group('parseCensimenti', () {
    final c = parseCensimenti(fxCensimenti);
    test('righe, checkbox e stati', () {
      expect(c.length, 4);
      expect(c[0].sanitaria, false);
      expect(c[0].sanitariaMancante, true);
      expect(c[0].censimentoDaPagare, true);
      expect(c[0].quotaSanFra, isNull); // "/" = non dovuta
    });
    test('quote e date posizionali ("in data" duplicato)', () {
      expect(c[1].censimentoPagato, true);
      expect(c[1].dataCensimento, DateTime.utc(2026, 10, 5));
      expect(c[1].sanFraDaPagare, true);
      expect(c[1].dataSanFra, isNull);
      expect(c[1].vdbPagata, true);
      expect(c[1].dataVdB, DateTime.utc(2026, 10, 20));
      expect(c[1].note, 'Paga a rate');
    });
  });

  group('parsePrede', () {
    final p = parsePrede(fxPrede);
    test('caccia con asterisco e specialità acquisite', () {
      expect(p[0].cacciaPer, 'Lupo Anziano');
      expect(p[0].cacciaAsterisco, true);
      expect(p[0].specialitaAcquisite, ['Musicista', 'Atleta', 'Cuoco']);
      expect(p[0].stato, 'Non assegnata');
      expect(p[0].impegni.length, 3);
      expect(p[0].impegni.every((i) => i.vuoto), true);
    });
    test('blocco impegno 1 popolato', () {
      final i = p[1].impegni[0];
      expect(i.specialita, 'Fotografo');
      expect(i.impegno, 'Scattare 5 foto');
      expect(i.conChi, 'Bagheera');
      expect(i.stato, 'In corso');
      expect(p[1].prede, 'Preda X');
      expect(p[1].conChi, 'Akela');
    });
    test('colonna extra "Colonna 1" ignorata', () {
      expect(p.length, 5);
    });
  });

  group('parseSestiglie', () {
    final t = parseSestiglie(fxSestiglie);
    test('anni numerici e anno di default = ultima colonna con dati', () {
      expect(t.anni, [2024, 2025, 2026, 2027]);
      expect(t.annoDefault, 2027);
    });
    test('anno di default salta colonne vuote in fondo', () {
      final solo = parseSestiglie([
        ['Lupetto/a', 2026, 2027],
        ['A B', 'Neri', ''],
        ['C D', '/', null],
      ]);
      expect(solo.annoDefault, 2026);
    });
    test('"/" e vuoto → null', () {
      final g = t.righe[1];
      expect(g.perAnno[2024], isNull);
      expect(g.perAnno[2027], 'Bianchi');
      expect(t.righe[2].perAnno[2025], isNull);
    });
  });

  group('parseBilancio + riepilogo', () {
    final m = parseBilancio(fxBilancio);
    test('ignora righe vuote e riga del totale', () {
      expect(m.length, 5);
      expect(m.map((x) => x.descrizione), isNot(contains('')));
    });
    test('saldo calcolato dall\'app, non letto dalla cella del totale', () {
      final r = RiepilogoBilancio(m);
      expect(r.saldo, closeTo(257.5, 1e-9));
    });
    test('totali per categoria e per pagatore', () {
      final r = RiepilogoBilancio(m);
      expect(r.perCategoria['Attività'], closeTo(-32.5, 1e-9));
      expect(r.perCategoria['Senza categoria'], 73); // categoria "/"
      expect(r.perPagatoDa['Bagheera'], closeTo(48, 1e-9));
      expect(r.perPagatoDa['Non indicato'], 235);
    });
    test('importi in formato valuta (stringhe) letti come numeri', () {
      final v = parseBilancio(fxBilancioValuta);
      expect(v.length, 2);
      expect(v[0].importo, -50);
      expect(v[0].data, DateTime.utc(2026, 10, 10));
      expect(v[1].importo, 1234.5);
    });
  });
}
