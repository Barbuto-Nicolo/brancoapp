import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'parsers/cell_utils.dart';

/// Errore di Sheets. Il messaggio NON contiene mai dati delle celle.
class SheetsException implements Exception {
  SheetsException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  bool get nonAutorizzato => statusCode == 401;
  bool get accessoNegato => statusCode == 403;
  @override
  String toString() => 'SheetsException($statusCode): $message';
}

/// Fornisce il token OAuth del capo (Fase 2: Google Sign-In). Il client non
/// conosce né salva credenziali.
typedef TokenProvider = Future<String> Function();

class SheetsClient {
  SheetsClient({required this.profilo, required this.token, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final SheetProfile profilo;
  final TokenProvider token;
  final http.Client _http;

  static const _base = 'https://sheets.googleapis.com/v4/spreadsheets';

  /// 'Nome tab' in A1: apici raddoppiati se presenti nel nome.
  static String quotaTab(String tab) => "'${tab.replaceAll("'", "''")}'";

  Future<Map<String, String>> _headers() async => {'Authorization': 'Bearer ${await token()}'};

  /// UNA sola chiamata per tutti i tab. Risultato: nome tab → righe.
  /// UNFORMATTED_VALUE + SERIAL_NUMBER: importi come numeri, date come seriali.
  ///
  /// Il tab "Capi" è opzionale: lo si chiede nella stessa chiamata e, se non
  /// esiste ancora (Google risponde 400 "range non valido"), si ripete la
  /// chiamata senza di lui.
  Future<Map<String, List<Riga>>> batchGet() async {
    // Tab opzionali ("Capi", "Quote"): se uno non esiste Google risponde 400,
    // quindi si riprova togliendo gli opzionali uno alla volta.
    final obbligatori = profilo.tuttiITab;
    final tentativi = <List<String>>[
      [...obbligatori, profilo.tabCapi, profilo.tabQuote],
      [...obbligatori, profilo.tabCapi],
      [...obbligatori, profilo.tabQuote],
      obbligatori,
    ];
    for (var i = 0; i < tentativi.length; i++) {
      try {
        return await _batchGet(tentativi[i]);
      } on SheetsException catch (e) {
        if (e.statusCode != 400 || i == tentativi.length - 1) rethrow;
      }
    }
    throw StateError('non raggiungibile');
  }

  Future<Map<String, List<Riga>>> _batchGet(List<String> tab) async {
    final uri = Uri.parse('$_base/${profilo.spreadsheetId}/values:batchGet').replace(
      queryParameters: {
        'ranges': [for (final t in tab) quotaTab(t)],
        'valueRenderOption': 'UNFORMATTED_VALUE',
        'dateTimeRenderOption': 'SERIAL_NUMBER',
        'majorDimension': 'ROWS',
      },
    );
    final res = await _http.get(uri, headers: await _headers());
    _controlla(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final ranges = (json['valueRanges'] as List?) ?? const [];
    // Un risultato per ogni tab richiesto (se ce ne sono di meno è una risposta anomala).
    if (ranges.length < tab.length) {
      throw SheetsException(res.statusCode, 'Risposta inattesa: numero di tab diverso dal previsto.');
    }
    final out = <String, List<Riga>>{};
    for (var i = 0; i < tab.length; i++) {
      final values = (ranges[i] as Map<String, dynamic>)['values'] as List?;
      out[tab[i]] = [for (final r in values ?? const []) List<Object?>.from(r as List)];
    }
    return out;
  }

  /// Crea un tab nuovo (usato solo per "Capi").
  Future<void> creaTab(String titolo) async {
    final uri = Uri.parse('$_base/${profilo.spreadsheetId}:batchUpdate');
    final res = await _http.post(
      uri,
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'addSheet': {
              'properties': {'title': titolo},
            },
          },
        ],
      }),
    );
    _controlla(res);
  }

  /// Legge un solo range A1 (per il controllo conflitti, Fase 3).
  Future<Riga?> leggiRange(String rangeA1) async {
    final uri = Uri.parse(
      '$_base/${profilo.spreadsheetId}/values/${Uri.encodeComponent(rangeA1)}',
    ).replace(queryParameters: {'valueRenderOption': 'UNFORMATTED_VALUE', 'dateTimeRenderOption': 'SERIAL_NUMBER'});
    final res = await _http.get(uri, headers: await _headers());
    _controlla(res);
    final values = (jsonDecode(res.body) as Map<String, dynamic>)['values'] as List?;
    if (values == null || values.isEmpty) return null;
    return List<Object?>.from(values.first as List);
  }

  /// Legge un intero tab (usato al momento della scrittura per ritrovare le righe).
  Future<List<Riga>> leggiTab(String tab) async {
    final uri = Uri.parse(
      '$_base/${profilo.spreadsheetId}/values/${Uri.encodeComponent(quotaTab(tab))}',
    ).replace(queryParameters: {'valueRenderOption': 'UNFORMATTED_VALUE', 'dateTimeRenderOption': 'SERIAL_NUMBER'});
    final res = await _http.get(uri, headers: await _headers());
    _controlla(res);
    final values = (jsonDecode(res.body) as Map<String, dynamic>)['values'] as List?;
    return [for (final r in values ?? const []) List<Object?>.from(r as List)];
  }

  /// Scrive SOLO le celle indicate (range A1 → valore). RAW: i numeri restano
  /// numeri, i booleani restano checkbox, nessuna interpretazione di "€" o date.
  Future<void> scriviCelle(List<(String, Object?)> celle) async {
    if (celle.isEmpty) return;
    final uri = Uri.parse('$_base/${profilo.spreadsheetId}/values:batchUpdate');
    final body = jsonEncode({
      'valueInputOption': 'RAW',
      'data': [
        for (final c in celle)
          {
            'range': c.$1,
            'majorDimension': 'ROWS',
            'values': [
              [c.$2],
            ],
          },
      ],
    });
    final res = await _http.post(uri, headers: {...await _headers(), 'Content-Type': 'application/json'}, body: body);
    _controlla(res);
  }

  /// sheetId numerico di un tab (serve per inserire righe).
  Future<int> sheetId(String tab) async {
    final uri = Uri.parse(
      '$_base/${profilo.spreadsheetId}',
    ).replace(queryParameters: {'fields': 'sheets.properties(sheetId,title)'});
    final res = await _http.get(uri, headers: await _headers());
    _controlla(res);
    final sheets = (jsonDecode(res.body) as Map<String, dynamic>)['sheets'] as List;
    for (final s in sheets) {
      final p = (s as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
      if (p['title'] == tab) return p['sheetId'] as int;
    }
    throw SheetsException(404, 'Tab "$tab" non trovato nel foglio.');
  }

  /// Inserisce una riga vuota alla posizione [indiceRiga0] (0-based), spingendo
  /// in basso le righe successive (e quindi il totale).
  Future<void> inserisciRiga(int sheetId, int indiceRiga0) async {
    final uri = Uri.parse('$_base/${profilo.spreadsheetId}:batchUpdate');
    final res = await _http.post(
      uri,
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'insertDimension': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'ROWS',
                'startIndex': indiceRiga0,
                'endIndex': indiceRiga0 + 1,
              },
              'inheritFromBefore': true,
            },
          },
        ],
      }),
    );
    _controlla(res);
  }

  /// Elimina la riga [indiceRiga0] (0-based) e fa salire le successive.
  Future<void> eliminaRiga(int sheetId, int indiceRiga0) async {
    final uri = Uri.parse('$_base/${profilo.spreadsheetId}:batchUpdate');
    final res = await _http.post(
      uri,
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'ROWS',
                'startIndex': indiceRiga0,
                'endIndex': indiceRiga0 + 1,
              },
            },
          },
        ],
      }),
    );
    _controlla(res);
  }

  void _controlla(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final msg = switch (res.statusCode) {
      401 => 'Sessione scaduta: accedi di nuovo.',
      403 => 'Non hai i permessi su questo foglio.',
      404 => 'Foglio non trovato: controlla il profilo in configurazione.',
      429 => 'Troppe richieste a Google: riprova tra un minuto.',
      _ => 'Errore di Google Sheets (${res.statusCode}).',
    };
    throw SheetsException(res.statusCode, msg);
  }

  void close() => _http.close();
}
