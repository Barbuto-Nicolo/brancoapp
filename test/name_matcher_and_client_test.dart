import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/data/sheets_client.dart';

import 'fixtures/fixtures.dart';

BrancoData _data() => BrancoData.daTab(AppConfig.profili['copia']!, {
      'Dati e recapiti': fxDati,
      'Censimenti e quote campi 2526': fxCensimenti,
      'Prede e specialità 2526': fxPrede,
      'Sestiglie': fxSestiglie,
      'Bilancio': fxBilancio,
    });

void main() {
  group('unisciPerNome', () {
    final r = unisciPerNome(_data(), alias: const {});

    test('unisce per nome normalizzato', () {
      final mario = r.lupetti.firstWhere((l) => l.nome == 'Mario Rossi');
      expect(mario.dati, isNotNull);
      expect(mario.censimento, isNotNull);
      expect(mario.prede, isNotNull);
      expect(mario.sestiglie!.perAnno[2027], 'Pezzati');
    });

    test('lupetto presente in soli due tab: report dei tab mancanti', () {
      final linda = r.lupetti.firstWhere((l) => l.nome == 'Linda Neri');
      expect(linda.dati, isNull);
      expect(linda.censimento, isNull);
      expect(r.report.mancanti['Linda Neri'], ['Dati e recapiti', 'Censimenti']);
    });

    test('"Diego ____" e "Diego Ciccolini" restano separati ma suggeriti', () {
      expect(r.lupetti.where((l) => l.nome.startsWith('Diego')).length, 2);
      expect(r.report.suggerimenti, contains(('Diego ____'.trim(), 'Diego Ciccolini')));
    });

    test('nome visibile: preferisce quello senza segnaposto', () {
      final nomi = r.lupetti.map((l) => l.nome);
      expect(nomi, contains('Diego Ciccolini'));
    });

    test('alias in config unisce i due Diego e svuota i suggerimenti', () {
      final a = unisciPerNome(_data(), alias: {'diego': 'diegociccolini'});
      expect(a.lupetti.where((l) => l.nome.startsWith('Diego')).length, 1);
      final diego = a.lupetti.firstWhere((l) => l.nome == 'Diego Ciccolini');
      expect(diego.dati, isNotNull);
      expect(diego.sestiglie, isNotNull);
      expect(a.report.suggerimenti, isEmpty);
    });

    test('duplicati nello stesso tab segnalati', () {
      final d = BrancoData.daTab(AppConfig.profili['copia']!, {
        'Dati e recapiti': [
          ['Lupetto/a', 'Anno'],
          ['Mario Rossi', '2° anno'],
          ['mario  rossi', '3° anno'],
        ],
      });
      final u = unisciPerNome(d, alias: const {});
      expect(u.report.duplicati.length, 1);
      expect(u.lupetti.length, 1);
    });
  });

  group('SheetsClient.batchGet', () {
    test('UNA sola chiamata con tutti i tab e UNFORMATTED_VALUE', () async {
      final richieste = <http.Request>[];
      final mock = MockClient((req) async {
        richieste.add(req);
        final p = AppConfig.profili['copia']!;
        final tab = [...p.tuttiITab, p.tabCapi, p.tabQuote]; // "Capi" e "Quote" sono opzionali ma richiesti
        return http.Response(
          jsonEncode({
            'valueRanges': [
              for (final t in tab)
                {
                  'range': "'$t'!A1:B2",
                  if (t == 'Sestiglie')
                    'values': [
                      ['Lupetto/a', 2027],
                    ],
                  if (t == 'Capi')
                    'values': [
                      ['Capo/a'],
                      ['Akela'],
                    ],
                },
            ],
          }),
          200,
        );
      });
      final client = SheetsClient(
        profilo: AppConfig.profili['copia']!,
        token: () async => 'token-finto',
        httpClient: mock,
      );
      final out = await client.batchGet();

      expect(richieste.length, 1);
      final u = richieste.single.url;
      expect(u.path, endsWith('/values:batchGet'));
      expect(u.queryParametersAll['ranges']!.length, 7);
      expect(u.queryParameters['valueRenderOption'], 'UNFORMATTED_VALUE');
      expect(richieste.single.headers['Authorization'], 'Bearer token-finto');
      expect(out['Sestiglie']!.first, ['Lupetto/a', 2027]);
      expect(out['Bilancio'], isEmpty); // tab vuoto → lista vuota
      expect(out['Capi']!.last, ['Akela']);
    });

    test('tab opzionali inesistenti: si ripete la chiamata togliendoli', () async {
      final richieste = <http.Request>[];
      final p = AppConfig.profili['copia']!;
      final client = SheetsClient(
        profilo: p,
        token: () async => 't',
        httpClient: MockClient((req) async {
          richieste.add(req);
          final n = req.url.queryParametersAll['ranges']!.length;
          if (n > 5) return http.Response('{"error":{"message":"Unable to parse range: Capi"}}', 400);
          return http.Response(jsonEncode({'valueRanges': [for (var i = 0; i < n; i++) <String, dynamic>{}]}), 200);
        }),
      );
      final out = await client.batchGet();
      expect(richieste.length, 4); // 7, 6 (senza Quote), 6 (senza Capi), 5
      expect(out.containsKey('Capi'), isFalse);
      expect(out.length, 5);
    });

    test('errori HTTP → SheetsException senza dati nel messaggio', () async {
      final client = SheetsClient(
        profilo: AppConfig.profili['copia']!,
        token: () async => 't',
        httpClient: MockClient((_) async => http.Response('{"error":"x"}', 403)),
      );
      expect(
        client.batchGet(),
        throwsA(isA<SheetsException>().having((e) => e.accessoNegato, 'accessoNegato', true)),
      );
    });

    test('quotaTab raddoppia gli apici', () {
      expect(SheetsClient.quotaTab("L'anno"), "'L''anno'");
    });
  });

  group('AppConfig', () {
    test('profilo attivo di default: copia', () {
      expect(AppConfig.profiloAttivo, 'copia');
      expect(AppConfig.attivo.spreadsheetId, isNotEmpty);
    });
    test('il profilo reale non è utilizzabile finché non configurato', () {
      expect(AppConfig.profili['reale']!.configurato, false);
    });
  });
}
