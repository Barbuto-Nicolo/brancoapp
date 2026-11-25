import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/parsers/parsers.dart';
import 'package:lupetti_app/data/sheets_client.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/censimenti/censimenti_logic.dart';
import 'package:lupetti_app/features/common/colori_sestiglie.dart';

import 'fake_sheets.dart';
import 'fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;
List<List<Object?>> _c(List<List<Object?>> t) => [for (final r in t) List<Object?>.from(r)];

FakeSheets _foglio({List<List<Object?>>? quote}) => FakeSheets({
  _p.tabDati: _c(fxDati),
  _p.tabCensimenti: _c(fxCensimenti),
  _p.tabPrede: _c(fxPrede),
  _p.tabSestiglie: _c(fxSestiglie),
  _p.tabBilancio: _c(fxBilancio),
  _p.tabQuote: ?quote,
});

SheetsWriteService _svc(FakeSheets f) => SheetsWriteService(
  client: SheetsClient(profilo: _p, token: () async => 't', httpClient: f.client),
  online: () async => true,
);

void main() {
  group('quote: importi e quote extra', () {
    test('primo importo: il tab "Quote" viene creato con intestazione', () async {
      final f = _foglio();
      await _svc(f).impostaImportoQuota('Quota SanFra', 25);
      expect(f.tabCreati, 1);
      expect(f.tabs['Quote']![0], ['Quota', 'Importo', 'Lupetto/a', 'Pagato il']);
      final q = parseQuote(f.tabs['Quote']!);
      expect(q.importoDi('quota sanfra'), 25);
      // Cambiare l'importo aggiorna la riga, non ne aggiunge una.
      await _svc(f).impostaImportoQuota('Quota SanFra', 30);
      expect(f.tabCreati, 1);
      expect(parseQuote(f.tabs['Quote']!).importoDi('Quota SanFra'), 30);
      expect(f.tabs['Quote']!.length, 2);
    });

    test('nuova quota extra: una riga per lupetto, poi paga e annulla', () async {
      final f = _foglio();
      final s = _svc(f);
      await s.creaQuotaExtra('Uscita di Natale', 12.5, ['Mario Rossi', 'Elena Verdi']);
      var q = parseQuote(f.tabs['Quote']!);
      expect(q.nomiExtra, ['Uscita di Natale']);
      expect(q.di('Uscita di Natale').map((r) => r.lupetto), ['Mario Rossi', 'Elena Verdi']);
      expect(q.di('Uscita di Natale').every((r) => r.importo == 12.5 && !r.pagata), isTrue);

      await s.segnaQuotaExtra(
        quota: 'Uscita di Natale',
        lupetto: 'mario  rossi',
        data: DateTime(2026, 12, 3),
        attesaPagata: false,
      );
      q = parseQuote(f.tabs['Quote']!);
      expect(q.di('Uscita di Natale').first.pagatoIl, DateTime.utc(2026, 12, 3));
      expect(q.di('Uscita di Natale').last.pagata, isFalse);

      await s.segnaQuotaExtra(quota: 'Uscita di Natale', lupetto: 'Mario Rossi', data: null, attesaPagata: true);
      expect(parseQuote(f.tabs['Quote']!).di('Uscita di Natale').first.pagata, isFalse);
    });

    test('quota extra già esistente: errore e nulla scritto', () async {
      final f = _foglio();
      final s = _svc(f);
      await s.creaQuotaExtra('Gita', 10, ['Mario Rossi']);
      final prima = f.numeroScritture;
      await expectLater(s.creaQuotaExtra(' gita ', 5, ['Elena Verdi']), throwsA(isA<QuotaEsistenteException>()));
      expect(f.numeroScritture, prima);
    });

    test('conflitto: un altro capo ha già segnato il pagamento', () async {
      final f = _foglio();
      final s = _svc(f);
      await s.creaQuotaExtra('Gita', 10, ['Mario Rossi']);
      await s.segnaQuotaExtra(quota: 'Gita', lupetto: 'Mario Rossi', data: DateTime(2026, 12, 1), attesaPagata: false);
      await expectLater(
        s.segnaQuotaExtra(quota: 'Gita', lupetto: 'Mario Rossi', data: DateTime(2026, 12, 2), attesaPagata: false),
        throwsA(isA<ConflittoException>()),
      );
      // Con "forza" si sovrascrive.
      await s.segnaQuotaExtra(
        quota: 'Gita',
        lupetto: 'Mario Rossi',
        data: DateTime(2026, 12, 2),
        attesaPagata: false,
        forza: true,
      );
      expect(parseQuote(f.tabs['Quote']!).di('Gita').single.pagatoIl, DateTime.utc(2026, 12, 2));
    });

    test('elimina quota: ok se nessuno ha pagato, bloccato altrimenti', () async {
      final f = _foglio();
      final s = _svc(f);
      await s.creaQuotaExtra('Gita', 10, ['Mario Rossi', 'Elena Verdi']);
      await s.creaQuotaExtra('Altra', 5, ['Mario Rossi']);
      await s.segnaQuotaExtra(quota: 'Altra', lupetto: 'Mario Rossi', data: DateTime(2026, 12, 1), attesaPagata: false);
      await expectLater(s.eliminaQuotaExtra('Altra'), throwsA(isA<QuotaConPagamentiException>()));
      await s.eliminaQuotaExtra('Gita');
      expect(parseQuote(f.tabs['Quote']!).nomiExtra, ['Altra']);
    });
  });

  group('incassi e storni in Bilancio', () {
    test('movimento di incasso: entrata positiva, categoria Quote', () {
      final m = movimentoIncasso('Quota SanFra', 'Mario Rossi', 25, DateTime(2026, 11, 20));
      expect(m.importo, 25);
      expect(m.categoria, 'Quote');
      expect(m.descrizione, 'Quota SanFra – Mario Rossi');
    });

    test('daStornare: entrate meno storni già fatti', () {
      final inc = movimentoIncasso('Gita', 'Mario Rossi', 10, DateTime(2026, 12, 1));
      expect(daStornare([inc], 'Gita', 'mario rossi'), 10);
      final sto = movimentoStorno('Gita', 'Mario Rossi', 10, DateTime(2026, 12, 2));
      expect(sto.importo, -10);
      expect(daStornare([inc, sto], 'Gita', 'Mario Rossi'), isNull); // già stornato
      expect(daStornare([inc, sto, inc], 'Gita', 'Mario Rossi'), 10); // pagato di nuovo
      expect(daStornare(const [], 'Gita', 'Mario Rossi'), isNull);
    });

    test('validaNuovaQuota', () {
      String? v({String nome = 'Gita', double? imp = 10, int n = 3, List<String> es = const []}) =>
          validaNuovaQuota(nome: nome, importo: imp, selezionati: n, esistenti: es);
      expect(v(), isNull);
      expect(v(nome: ' '), isNotNull);
      expect(v(nome: 'quota sanfra'), contains('Esiste già'));
      expect(v(es: ['GITA']), contains('Esiste già'));
      expect(v(imp: null), contains('Importo'));
      expect(v(imp: 0), contains('Importo'));
      expect(v(n: 0), contains('almeno un lupetto'));
    });
  });

  group('pezzati', () {
    test('bianchi con macchie nere', () {
      expect(haMacchie('Pezzati'), isTrue);
      expect(haMacchie('Fulvi'), isFalse);
      final c = coloreSestiglia('Pezzati');
      expect(HSLColor.fromColor(c).lightness, greaterThan(0.9));
    });
  });
}
