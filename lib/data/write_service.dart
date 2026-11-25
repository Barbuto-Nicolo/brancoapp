/// Scrittura sul foglio con controllo dei conflitti.
///
/// Regole:
/// - si scrivono SOLO le celle modificate (range A1 precisi), mai un tab intero;
/// - la riga si ritrova al momento della scrittura cercando il nome nella
///   colonna "Lupetto/a" (nessun indice salvato: il foglio può essere stato riordinato);
/// - prima di scrivere si rilegge il tab: se una cella ha un valore diverso da
///   quello che l'app aveva caricato, si lancia [ConflittoException];
/// - offline: nessuna scrittura, nessuna coda.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/models.dart';
import 'branco_repository.dart' show RetePersaException;
import 'parsers/cell_utils.dart';
import 'parsers/tab_table.dart';
import 'sheets_client.dart';

/// Offline: le modifiche sono bloccate.
class OfflineException implements Exception {
  @override
  String toString() => 'OfflineException';
}

class LupettoNonTrovatoException implements Exception {
  LupettoNonTrovatoException(this.tab);
  final String tab;
}

class NomeAmbiguoException implements Exception {
  NomeAmbiguoException(this.tab);
  final String tab;
}

/// Il nome che si vuole aggiungere esiste già in un tab.
class NomeEsistenteException implements Exception {
  NomeEsistenteException(this.tab);
  final String tab;
}

/// Il capo che si vuole aggiungere è già nell'elenco.
class CapoGiaPresenteException implements Exception {
  CapoGiaPresenteException(this.nome);
  final String nome;
}

/// Struttura del tab diversa dal previsto (intestazione o colonna mancante).
class StrutturaException implements Exception {
  StrutturaException(this.dettaglio);
  final String dettaglio;
}

class Campo {
  const Campo({
    required this.etichetta,
    required this.header,
    required this.nuovo,
    this.atteso,
    this.offset = 0,
  });

  /// Nome mostrato all'utente (es. "Quota SanFra").
  final String etichetta;

  /// Intestazione della colonna di riferimento (es. "Quota SanFra").
  final String header;

  /// Spostamento di colonne rispetto all'intestazione (per le intestazioni
  /// duplicate: "in data" = Quota SanFra + 1).
  final int offset;

  /// Valore che l'app aveva caricato (null = cella vuota o "/").
  final Object? atteso;

  /// Valore da scrivere: String, num, bool o DateTime (scritto come seriale).
  final Object? nuovo;
}

class Conflitto {
  const Conflitto(this.etichetta, this.attuale, this.atteso, this.nuovo);
  final String etichetta;
  final Object? attuale;
  final Object? atteso;
  final Object? nuovo;
}

class ConflittoException implements Exception {
  ConflittoException(this.conflitti);
  final List<Conflitto> conflitti;
}

class CellaDaScrivere {
  const CellaDaScrivere(this.range, this.valore);
  final String range;
  final Object? valore;
}

/// Forma canonica per confrontare "valore caricato" e "valore nel foglio".
String _forma(Object? v) {
  if (v is DateTime) return 'n:${dateToSerial(v)}';
  if (v is bool) return 'b:$v';
  if (v is num) return 'n:${v == v.truncate() ? v.truncate() : v}';
  final t = cellText(v);
  if (t == null) return 'vuoto';
  final b = cellBool(t);
  if (b != null) return 'b:$b';
  final d = cellDate(t);
  if (d != null) return 'n:${dateToSerial(d)}';
  final n = num.tryParse(t);
  if (n != null) return 'n:${n == n.truncate() ? n.truncate() : n}';
  return 's:$t';
}

bool stessoValore(Object? a, Object? b) => _forma(a) == _forma(b);

/// Valore pronto per il JSON: le date diventano numeri seriali.
Object? valorePerFoglio(Object? v) => v is DateTime ? dateToSerial(v) : v;

/// Parte PURA della scrittura: dato il contenuto fresco del tab, trova la riga,
/// controlla i conflitti e produce le celle da scrivere.
({List<CellaDaScrivere> celle, List<Conflitto> conflitti}) pianificaCampi({
  required String tab,
  required List<Riga> valori,
  required String nomeNelTab,
  required List<Campo> campi,
  bool forza = false,
  Map<String, String> alias = AppConfig.aliasNomi,
}) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) throw StrutturaException('Intestazione "Lupetto/a" non trovata nel tab "$tab".');
  final cNome = t.col('Lupetto/a');

  String k(String n) {
    final x = normalizeName(n);
    return alias[x] ?? x;
  }

  final chiave = k(nomeNelTab);
  final righe = <int>[];
  for (var i = 0; i < t.rows.length; i++) {
    final n = cellText(cellaAt(t.rows[i], cNome));
    if (n != null && k(n) == chiave) righe.add(i);
  }
  if (righe.isEmpty) throw LupettoNonTrovatoException(tab);
  if (righe.length > 1) throw NomeAmbiguoException(tab);
  final riga = t.rows[righe.single];
  final numeroRiga = t.numeroRigaA1(righe.single);

  final celle = <CellaDaScrivere>[];
  final conflitti = <Conflitto>[];
  for (final c in campi) {
    final base = t.col(c.header);
    if (base < 0) throw StrutturaException('Colonna "${c.header}" non trovata nel tab "$tab".');
    final col = base + c.offset;
    final attuale = cellaAt(riga, col);
    if (!forza && !stessoValore(attuale, c.atteso)) {
      conflitti.add(Conflitto(c.etichetta, attuale, c.atteso, c.nuovo));
      continue;
    }
    celle.add(CellaDaScrivere(
      '${SheetsClient.quotaTab(tab)}!${colLetter(col)}$numeroRiga',
      valorePerFoglio(c.nuovo),
    ));
  }
  return (celle: celle, conflitti: conflitti);
}

/// Piano per un nuovo movimento di bilancio.
class PianoMovimento {
  const PianoMovimento({
    required this.rigaA1,
    required this.serveInserimento,
    required this.indiceInserimento0,
    required this.colonne,
    this.totaleAtteso,
    this.rigaTotaleDopoA1,
    this.colonnaCosto,
    this.intestazioniNuove = const {},
    this.rigaIntestazioneA1 = 1,
  });

  /// Intestazioni da creare (testo → colonna 0-based) per le colonne dei
  /// rimborsi, quando il foglio non le ha ancora.
  final Map<String, int> intestazioniNuove;
  final int rigaIntestazioneA1;

  /// Riga (1-based) in cui scrivere il movimento.
  final int rigaA1;
  final bool serveInserimento;

  /// Indice 0-based in cui inserire la riga (solo se [serveInserimento]).
  final int indiceInserimento0;
  final Map<String, int> colonne;

  /// Totale attuale letto dalla riga del totale (per il controllo finale).
  final double? totaleAtteso;
  final int? rigaTotaleDopoA1;
  final int? colonnaCosto;
}

bool _vuota(Object? v) => v == null || (v is String && v.trim().isEmpty);

/// Parte PURA: sceglie dove mettere un nuovo movimento.
/// Il totale è l'ultima riga SENZA descrizione ma con un importo numerico:
/// non viene mai scritto né sovrascritto.
PianoMovimento pianificaMovimento(List<Riga> valori, {bool serveRimborso = false}) {
  final t = TabTable.trova(valori, 'Dettagli spese');
  if (t == null) throw StrutturaException('Intestazione "Dettagli spese" non trovata nel tab Bilancio.');
  final colonne = {
    'desc': t.col('Dettagli spese'),
    'cat': t.col('Categoria'),
    'costo': t.col('Costo'),
    'data': t.col('Data della transazione'),
    'pagato': t.col('Pagato da'),
    'note': t.col('Note'),
    'rimb': t.col('Da rimborsare'),
    'rimbData': t.col('Rimborsata il'),
  };
  if (colonne['desc']! < 0 || colonne['costo']! < 0) {
    throw StrutturaException('Colonne "Dettagli spese" o "Costo" non trovate nel tab Bilancio.');
  }
  final cDesc = colonne['desc']!, cCosto = colonne['costo']!;

  // Colonne dei rimborsi: se servono e mancano, si creano a destra del tutto
  // (prima colonna interamente vuota), con l'intestazione nella riga delle intestazioni.
  final nuove = <String, int>{};
  if (serveRimborso) {
    var da = t.headers.length;
    for (final r in t.rows) {
      if (r.length > da) da = r.length;
    }
    for (final e in const {'rimb': 'Da rimborsare', 'rimbData': 'Rimborsata il'}.entries) {
      if (colonne[e.key]! < 0) {
        colonne[e.key] = da;
        nuove[e.value] = da;
        da++;
      }
    }
  }

  // Riga del totale (indice in t.rows).
  int? iTot;
  for (var i = t.rows.length - 1; i >= 0; i--) {
    final r = t.rows[i];
    if (_vuota(cellaAt(r, cDesc)) && cellaAt(r, cCosto) is num) {
      iTot = i;
      break;
    }
  }
  // Ultima riga usata sopra il totale.
  final limite = iTot ?? t.rows.length;
  var ultimaUsata = -1;
  for (var i = 0; i < limite; i++) {
    if (t.rows[i].any((c) => !_vuota(c))) ultimaUsata = i;
  }
  final prossima = ultimaUsata + 1; // indice in t.rows della prima riga libera
  final serve = iTot != null && prossima >= iTot;
  final rigaA1 = t.numeroRigaA1(prossima);
  return PianoMovimento(
    rigaA1: rigaA1,
    serveInserimento: serve,
    // Indice 0-based del foglio = numero riga A1 - 1; si inserisce "prima del totale".
    indiceInserimento0: serve ? t.headerRow + 1 + iTot : 0,
    colonne: colonne,
    totaleAtteso: iTot == null ? null : (cellaAt(t.rows[iTot], cCosto) as num).toDouble(),
    rigaTotaleDopoA1: iTot == null ? null : t.numeroRigaA1(iTot) + (serve ? 1 : 0),
    colonnaCosto: cCosto,
    intestazioniNuove: nuove,
    rigaIntestazioneA1: t.headerRow + 1,
  );
}

/// Parte PURA: celle da scrivere per segnare come rimborsate delle spese.
/// Ogni spesa si ritrova per descrizione + importo + data + "Pagato da" tra le
/// righe ancora da rimborsare; se non si trova (cambiata o già rimborsata da un
/// altro capo) si lancia un conflitto e NON si scrive nulla.
List<CellaDaScrivere> pianificaRimborsi({
  required String tab,
  required List<Riga> valori,
  required List<Movimento> movimenti,
  required DateTime data,
}) {
  final t = TabTable.trova(valori, 'Dettagli spese');
  if (t == null) throw StrutturaException('Intestazione "Dettagli spese" non trovata nel tab "$tab".');
  final cDesc = t.col('Dettagli spese'), cCosto = t.col('Costo'), cData = t.col('Data della transazione');
  final cPag = t.col('Pagato da'), cRimb = t.col('Da rimborsare'), cRimbData = t.col('Rimborsata il');
  if (cDesc < 0 || cCosto < 0 || cRimb < 0 || cRimbData < 0) {
    throw StrutturaException('Colonne dei rimborsi non trovate nel tab "$tab".');
  }
  String? low(Object? v) => cellText(v)?.toLowerCase();

  final usate = <int>{};
  final celle = <CellaDaScrivere>[];
  final conflitti = <Conflitto>[];
  for (final m in movimenti) {
    int? trovata;
    for (var i = 0; i < t.rows.length; i++) {
      if (usate.contains(i)) continue;
      final r = t.rows[i];
      final costo = cellNumber(cellaAt(r, cCosto));
      if (costo == null || (costo - m.importo).abs() > 0.005) continue;
      if (low(cellaAt(r, cDesc)) != m.descrizione.toLowerCase().trim()) continue;
      if (low(cellaAt(r, cPag)) != m.pagatoDa?.toLowerCase().trim()) continue;
      if (!stessoValore(cellaAt(r, cData), m.data)) continue;
      if (!(cellBool(cellaAt(r, cRimb)) ?? false)) continue;
      if (cellText(cellaAt(r, cRimbData)) != null) continue; // già rimborsata
      trovata = i;
      break;
    }
    if (trovata == null) {
      conflitti.add(Conflitto(m.descrizione, 'cambiata o già rimborsata nel foglio', null, 'rimborsata'));
      continue;
    }
    usate.add(trovata);
    celle.add(CellaDaScrivere(
      '${SheetsClient.quotaTab(tab)}!${colLetter(cRimbData)}${t.numeroRigaA1(trovata)}',
      dateToSerial(data),
    ));
  }
  if (conflitti.isNotEmpty) throw ConflittoException(conflitti);
  return celle;
}

/// Parte PURA: dove scrivere un nuovo capo nel tab "Capi".
List<CellaDaScrivere> pianificaCapo({required String tab, required List<Riga> valori, required String nome}) {
  final q = SheetsClient.quotaTab(tab);
  final pulito = nome.trim();
  final t = TabTable.trova(valori, 'Capo/a');
  if (t == null) {
    if (valori.any((r) => r.any((c) => !_vuota(c)))) {
      throw StrutturaException('Il tab "$tab" deve avere l\'intestazione "Capo/a" nella prima riga.');
    }
    // Tab nuovo e vuoto: intestazione + primo nome.
    return [CellaDaScrivere('$q!A1', 'Capo/a'), CellaDaScrivere('$q!A2', pulito)];
  }
  final c = t.col('Capo/a');
  var ultima = -1;
  for (var i = 0; i < t.rows.length; i++) {
    final n = cellText(cellaAt(t.rows[i], c));
    if (n != null) {
      if (normalizeName(n) == normalizeName(pulito)) throw CapoGiaPresenteException(n);
      ultima = i;
    }
  }
  return [CellaDaScrivere('$q!${colLetter(c)}${t.numeroRigaA1(ultima + 1)}', pulito)];
}

/// Piano per aggiungere una riga a un tab con colonna "Lupetto/a".
class PianoRigaNuova {
  const PianoRigaNuova(this.celle, this.serveInserimento, this.indiceInserimento0);
  final List<CellaDaScrivere> celle;
  final bool serveInserimento;
  final int indiceInserimento0;
}

/// Parte PURA: trova la prima riga libera sotto l'ultimo nome. Se subito sotto
/// c'è altro contenuto (note, totali) si inserisce una riga invece di scrivere
/// sopra. [campi] = (intestazione, spostamento, valore).
/// Lancia [NomeEsistenteException] se il nome c'è già.
PianoRigaNuova pianificaRigaNuova({
  required String tab,
  required List<Riga> valori,
  required String nome,
  required List<(String, int, Object?)> campi,
  Map<String, String> alias = AppConfig.aliasNomi,
}) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) throw StrutturaException('Intestazione "Lupetto/a" non trovata nel tab "$tab".');
  final cNome = t.col('Lupetto/a');
  String k(String n) {
    final x = normalizeName(n);
    return alias[x] ?? x;
  }

  final chiave = k(nome);
  var ultima = -1;
  for (var i = 0; i < t.rows.length; i++) {
    final n = cellText(cellaAt(t.rows[i], cNome));
    if (n == null) continue;
    if (k(n) == chiave) throw NomeEsistenteException(tab);
    ultima = i;
  }
  final prossima = ultima + 1;
  final occupata = prossima < t.rows.length && t.rows[prossima].any((c) => !_vuota(c));
  final rigaA1 = t.numeroRigaA1(prossima);
  final q = SheetsClient.quotaTab(tab);
  final celle = <CellaDaScrivere>[CellaDaScrivere('$q!${colLetter(cNome)}$rigaA1', nome.trim())];
  for (final (header, offset, valore) in campi) {
    final base = t.col(header);
    if (base < 0) continue; // colonna assente in questo foglio: si salta
    celle.add(CellaDaScrivere('$q!${colLetter(base + offset)}$rigaA1', valorePerFoglio(valore)));
  }
  return PianoRigaNuova(celle, occupata, t.headerRow + 1 + prossima);
}

/// Piano per eliminare la riga di un lupetto da un tab.
class PianoEliminazione {
  const PianoEliminazione(this.indiceRiga0, this.rigaA1, this.celleNome);
  final int indiceRiga0;
  final int rigaA1;

  /// Range della cella del nome, da rileggere subito prima di eliminare.
  final String celleNome;
}

/// Parte PURA: trova la riga del lupetto [nomeNelTab]. Lancia
/// [LupettoNonTrovatoException] se non c'è e [NomeAmbiguoException] se compare più volte
/// (in quel caso non si elimina nulla: non si sa quale riga sia).
PianoEliminazione pianificaEliminazione({
  required String tab,
  required List<Riga> valori,
  required String nomeNelTab,
  Map<String, String> alias = AppConfig.aliasNomi,
}) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) throw StrutturaException('Intestazione "Lupetto/a" non trovata nel tab "$tab".');
  final cNome = t.col('Lupetto/a');
  String k(String n) {
    final x = normalizeName(n);
    return alias[x] ?? x;
  }

  final chiave = k(nomeNelTab);
  final righe = <int>[];
  for (var i = 0; i < t.rows.length; i++) {
    final n = cellText(cellaAt(t.rows[i], cNome));
    if (n != null && k(n) == chiave) righe.add(i);
  }
  if (righe.isEmpty) throw LupettoNonTrovatoException(tab);
  if (righe.length > 1) throw NomeAmbiguoException(tab);
  final a1 = t.numeroRigaA1(righe.single);
  return PianoEliminazione(a1 - 1, a1, '${SheetsClient.quotaTab(tab)}!${colLetter(cNome)}$a1');
}

/// Interfaccia usata dalla UI (sostituibile nei test).
abstract class ScritturaService {
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  });

  /// Restituisce un avviso testuale se, dopo la scrittura, il totale del foglio
  /// non risulta coerente (es. la formula non include la nuova riga).
  Future<String?> aggiungiMovimento(Movimento m);

  /// Segna come rimborsate (alla data indicata) spese anticipate da un capo.
  Future<void> segnaRimborsati(List<Movimento> movimenti, DateTime data);

  /// Aggiunge un capo al tab "Capi" (lo crea se manca).
  Future<void> aggiungiCapo(String nome);

  /// Aggiunge un lupetto nuovo a tutti i tab (Dati, Sestiglie, Censimenti, Prede).
  Future<EsitoNuovoLupetto> aggiungiLupetto(NuovoLupetto n);

  /// Elimina le righe di un lupetto dai tab in cui compare. [nomiPerTab] = tab → nome
  /// con cui il lupetto compare in quel tab. Il Bilancio non viene toccato.
  Future<EsitoEliminazione> eliminaLupetto(Map<String, String> nomiPerTab);
}

typedef ControlloOnline = Future<bool> Function();

class SheetsWriteService implements ScritturaService {
  SheetsWriteService({required this.client, required this.online});

  final SheetsClient client;
  final ControlloOnline online;

  SheetProfile get _p => client.profilo;

  Future<T> _rete<T>(Future<T> Function() f, {int secondi = 25}) async {
    if (!await online()) throw OfflineException();
    try {
      return await f().timeout(Duration(seconds: secondi));
    } on SocketException {
      throw RetePersaException();
    } on http.ClientException {
      throw RetePersaException();
    } on TimeoutException {
      throw RetePersaException();
    }
  }

  @override
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  }) =>
      _rete(() async {
        // 1) rilettura fresca del tab, 2) ricerca riga per nome, 3) conflitti.
        final valori = await client.leggiTab(tab);
        final piano = pianificaCampi(
          tab: tab,
          valori: valori,
          nomeNelTab: nomeNelTab,
          campi: campi,
          forza: forza,
        );
        if (piano.conflitti.isNotEmpty) throw ConflittoException(piano.conflitti);
        // 4) scrittura delle sole celle modificate, in un'unica chiamata.
        await client.scriviCelle([for (final c in piano.celle) (c.range, c.valore)]);
      });

  @override
  Future<String?> aggiungiMovimento(Movimento m) => _rete(() async {
        final tab = _p.tabBilancio;
        final piano = pianificaMovimento(await client.leggiTab(tab), serveRimborso: m.daRimborsare);
        var riga = piano.rigaA1;

        if (piano.serveInserimento) {
          final id = await client.sheetId(tab);
          await client.inserisciRiga(id, piano.indiceInserimento0);
        } else {
          // Rilettura mirata della riga di destinazione subito prima di scrivere:
          // se nel frattempo un altro capo l'ha riempita, ci si ferma.
          final fresca = await client.leggiRange(
            '${SheetsClient.quotaTab(tab)}!A$riga:${colLetter(piano.colonne.values.reduce((a, b) => a > b ? a : b))}$riga',
          );
          if (fresca != null && fresca.any((c) => !_vuota(c))) {
            throw ConflittoException([
              Conflitto('Riga $riga del Bilancio', 'occupata da un altro capo', null, m.descrizione),
            ]);
          }
        }

        final c = piano.colonne;
        String a1(String chiave) => '${SheetsClient.quotaTab(tab)}!${colLetter(c[chiave]!)}$riga';
        final celle = <(String, Object?)>[
          // Intestazioni dei rimborsi, create solo la prima volta che servono.
          for (final e in piano.intestazioniNuove.entries)
            ('${SheetsClient.quotaTab(tab)}!${colLetter(e.value)}${piano.rigaIntestazioneA1}', e.key),
          (a1('desc'), m.descrizione),
          (a1('costo'), m.importo), // numero, mai stringa con "€"
          if (m.categoria != null && c['cat']! >= 0) (a1('cat'), m.categoria),
          if (m.data != null && c['data']! >= 0) (a1('data'), dateToSerial(m.data!)),
          if (m.pagatoDa != null && c['pagato']! >= 0) (a1('pagato'), m.pagatoDa),
          if (m.note != null && c['note']! >= 0) (a1('note'), m.note),
          if (m.daRimborsare) (a1('rimb'), 'sì'),
        ];
        await client.scriviCelle(celle);

        // Controllo finale (sola lettura): il totale deve essere salito dell'importo.
        if (piano.totaleAtteso != null && piano.rigaTotaleDopoA1 != null) {
          final tot = await client.leggiRange(
            '${SheetsClient.quotaTab(tab)}!${colLetter(piano.colonnaCosto!)}${piano.rigaTotaleDopoA1}',
          );
          final nuovo = (tot != null && tot.isNotEmpty && tot.first is num) ? (tot.first as num).toDouble() : null;
          if (nuovo == null || (nuovo - (piano.totaleAtteso! + m.importo)).abs() > 0.005) {
            return 'Movimento aggiunto, ma il totale nel foglio non risulta aggiornato: '
                'controlla che la formula del totale comprenda la nuova riga.';
          }
        }
        return null;
      });

  @override
  Future<void> segnaRimborsati(List<Movimento> movimenti, DateTime data) => _rete(() async {
        final tab = _p.tabBilancio;
        final celle = pianificaRimborsi(
          tab: tab,
          valori: await client.leggiTab(tab),
          movimenti: movimenti,
          data: data,
        );
        await client.scriviCelle([for (final c in celle) (c.range, c.valore)]);
      });

  @override
  Future<void> aggiungiCapo(String nome) => _rete(() async {
        final tab = _p.tabCapi;
        List<Riga>? valori;
        try {
          valori = await client.leggiTab(tab);
        } on SheetsException catch (e) {
          if (e.statusCode != 400) rethrow; // 400 = il tab non esiste ancora
        }
        if (valori == null) {
          await client.creaTab(tab);
          valori = const [];
        }
        final celle = pianificaCapo(tab: tab, valori: valori, nome: nome);
        await client.scriviCelle([for (final c in celle) (c.range, c.valore)]);
      });

  @override
  Future<EsitoNuovoLupetto> aggiungiLupetto(NuovoLupetto n) => _rete(() async {
        // (tab, campi da scrivere oltre al nome). L'ordine è anche l'ordine di scrittura.
        final lavori = <(String, List<(String, int, Object?)>, bool)>[
          (_p.tabDati, [('Anno', 0, '${n.annoCammino}° anno')], true),
          (_p.tabSestiglie, [('${n.annoSestiglia}', 0, n.sestiglia)], true),
          (_p.tabCensimenti, [
            ('Anno', 0, '${n.annoCammino}° anno'),
            ('sanitaria', 0, false),
            ('Censimento', 0, 'non pagato'),
          ], false),
          (_p.tabPrede, [('Prede', 2, 'Non assegnata')], false),
        ];

        // 1) Si legge e si pianifica TUTTO prima di scrivere: i problemi sui tab
        // essenziali (nome già presente, struttura strana) fermano l'operazione senza toccare nulla.
        final piani = <String, PianoRigaNuova>{};
        final saltati = <String, String>{};
        for (final (tab, campi, essenziale) in lavori) {
          try {
            piani[tab] = pianificaRigaNuova(
                tab: tab, valori: await client.leggiTab(tab), nome: n.nome, campi: campi);
          } on NomeEsistenteException {
            if (essenziale) rethrow;
            saltati[tab] = 'nome già presente';
          } on StrutturaException catch (e) {
            if (essenziale) rethrow;
            saltati[tab] = e.dettaglio;
          }
        }

        // 2) Scrittura, un tab alla volta.
        final scritti = <String>[];
        for (final (tab, _, _) in lavori) {
          final piano = piani[tab];
          if (piano == null) continue;
          try {
            if (piano.serveInserimento) {
              await client.inserisciRiga(await client.sheetId(tab), piano.indiceInserimento0);
            }
            await client.scriviCelle([for (final c in piano.celle) (c.range, c.valore)]);
            scritti.add(tab);
          } catch (e) {
            if (scritti.isEmpty) rethrow; // nulla scritto: errore normale
            saltati[tab] = 'errore di scrittura';
          }
        }
        return EsitoNuovoLupetto(scritti, saltati);
      }, secondi: 60);

  @override
  Future<EsitoEliminazione> eliminaLupetto(Map<String, String> nomiPerTab) => _rete(() async {
        // 1) Si legge e si pianifica TUTTO: nome ambiguo o struttura strana fermano l'operazione.
        final piani = <String, PianoEliminazione>{};
        final saltati = <String, String>{};
        for (final e in nomiPerTab.entries) {
          try {
            piani[e.key] = pianificaEliminazione(
                tab: e.key, valori: await client.leggiTab(e.key), nomeNelTab: e.value);
          } on LupettoNonTrovatoException {
            saltati[e.key] = 'non presente';
          } on NomeAmbiguoException {
            throw NomeAmbiguoException(e.key);
          } on StrutturaException catch (x) {
            saltati[e.key] = x.dettaglio;
          }
        }
        if (piani.isEmpty) throw LupettoNonTrovatoException(nomiPerTab.keys.first);

        // 2) Eliminazione, un tab alla volta. Subito prima di ogni eliminazione si
        // rilegge la cella del nome: se la riga si è spostata (un altro capo ha
        // inserito o tolto righe) non si tocca nulla in quel tab.
        final eliminati = <String>[];
        for (final e in piani.entries) {
          final tab = e.key;
          final nome = normalizeName(nomiPerTab[tab]!);
          final ancora = await client.leggiRange(e.value.celleNome);
          final letto = (ancora == null || ancora.isEmpty) ? null : cellText(ancora.first);
          if (letto == null || normalizeName(letto) != nome) {
            saltati[tab] = 'la riga è cambiata nel frattempo';
            continue;
          }
          await client.eliminaRiga(await client.sheetId(tab), e.value.indiceRiga0);
          eliminati.add(tab);
        }
        return EsitoEliminazione(eliminati, saltati);
      }, secondi: 60);
}
