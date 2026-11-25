import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lupetti_app/data/parsers/cell_utils.dart';

/// Mini-Google-Sheets in memoria: legge/scrive range A1, inserisce righe.
/// Serve a verificare ranges e valori delle scritture senza toccare un foglio vero.
class FakeSheets {
  FakeSheets(this.tabs, {this.autoTotale = true});

  /// nome tab → righe (come le restituisce Sheets).
  final Map<String, List<List<Object?>>> tabs;

  /// Simula la formula del totale: ricalcola la somma sopra la riga del totale.
  final bool autoTotale;

  final List<http.Request> richieste = [];
  final List<Map<String, dynamic>> scritture = []; // corpi di values:batchUpdate
  int inserimenti = 0;
  int tabCreati = 0;
  int eliminazioni = 0;

  int get numeroScritture => scritture.length + inserimenti + eliminazioni;

  MockClient get client => MockClient((req) async {
        richieste.add(req);
        final path = Uri.decodeFull(req.url.path);
        if (req.method == 'GET') {
          if (path.contains('/values/')) {
            final range = path.split('/values/').last;
            final nomeTab = range.contains('!') ? _tabERange(range).$1 : range.replaceAll("'", '');
            if (!tabs.containsKey(nomeTab)) {
              // Come Google per un tab inesistente.
              return http.Response('{"error":{"message":"Unable to parse range"}}', 400);
            }
            return _json({'values': _leggi(range)});
          }
          // spreadsheets.get?fields=sheets.properties
          return _json({
            'sheets': [
              for (var i = 0; i < tabs.keys.length; i++)
                {'properties': {'sheetId': 100 + i, 'title': tabs.keys.elementAt(i)}},
            ],
          });
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (path.endsWith('/values:batchUpdate')) {
          scritture.add(body);
          for (final d in body['data'] as List) {
            final m = d as Map<String, dynamic>;
            _scrivi(m['range'] as String, ((m['values'] as List).first as List).first);
          }
          _ricalcolaTotali();
          return _json({});
        }
        // spreadsheets:batchUpdate (addSheet / insertDimension)
        for (final r in body['requests'] as List) {
          if ((r as Map).containsKey('addSheet')) {
            tabs[(r['addSheet']['properties'] as Map)['title'] as String] = [];
            tabCreati++;
            continue;
          }
          if (r.containsKey('deleteDimension')) {
            final rd = r['deleteDimension']['range'] as Map;
            final tabD = tabs.keys.elementAt((rd['sheetId'] as int) - 100);
            tabs[tabD]!.removeAt(rd['startIndex'] as int);
            eliminazioni++;
            continue;
          }
          final range = r['insertDimension']['range'] as Map;
          final tab = tabs.keys.elementAt((range['sheetId'] as int) - 100);
          tabs[tab]!.insert(range['startIndex'] as int, <Object?>[]);
          inserimenti++;
        }
        _ricalcolaTotali();
        return _json({});
      });

  http.Response _json(Object o) => http.Response(jsonEncode(o), 200, headers: {'content-type': 'application/json'});

  static (String, String) _tabERange(String a1) {
    final i = a1.lastIndexOf('!');
    var tab = a1.substring(0, i);
    if (tab.startsWith("'")) tab = tab.substring(1, tab.length - 1).replaceAll("''", "'");
    return (tab, a1.substring(i + 1));
  }

  static (int, int) _cella(String s) {
    final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(s)!;
    var c = 0;
    for (final ch in m.group(1)!.codeUnits) {
      c = c * 26 + (ch - 64);
    }
    return (c - 1, int.parse(m.group(2)!) - 1); // (colonna0, riga0)
  }

  List<List<Object?>> _leggi(String a1) {
    final (tab, r) = a1.contains('!') ? _tabERange(a1) : (a1.replaceAll("'", ''), '');
    final righe = tabs[tab]!;
    if (r.isEmpty) return righe.map((x) => List<Object?>.from(x)).toList();
    final parti = r.split(':');
    final (c1, r1) = _cella(parti[0]);
    final (c2, r2) = _cella(parti.length > 1 ? parti[1] : parti[0]);
    final out = <List<Object?>>[];
    for (var i = r1; i <= r2; i++) {
      final riga = i < righe.length ? righe[i] : <Object?>[];
      final fetta = <Object?>[for (var c = c1; c <= c2; c++) c < riga.length ? riga[c] : null];
      while (fetta.isNotEmpty && (fetta.last == null || fetta.last == '')) {
        fetta.removeLast(); // Sheets taglia le celle vuote in coda
      }
      out.add(fetta);
    }
    return out;
  }

  void _scrivi(String a1, Object? v) {
    final (tab, r) = _tabERange(a1);
    final (c, ri) = _cella(r);
    final righe = tabs[tab]!;
    while (righe.length <= ri) {
      righe.add(<Object?>[]);
    }
    final riga = righe[ri];
    while (riga.length <= c) {
      riga.add(null);
    }
    riga[c] = v;
  }

  void _ricalcolaTotali() {
    if (!autoTotale) return;
    final righe = tabs['Bilancio'];
    if (righe == null) return;
    int? tot;
    for (var i = righe.length - 1; i >= 0; i--) {
      final r = righe[i];
      if (cellaAt(r, 0) == null || cellaAt(r, 0) == '') {
        if (cellaAt(r, 2) is num) {
          tot = i;
          break;
        }
      }
    }
    if (tot == null) return;
    var somma = 0.0;
    for (var i = 1; i < tot; i++) {
      final v = cellaAt(righe[i], 2);
      if (v is num) somma += v;
    }
    righe[tot][2] = somma;
  }
}
