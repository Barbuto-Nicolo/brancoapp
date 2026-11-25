/// Funzioni di basso livello per leggere le celle di Google Sheets.
///
/// Con valueRenderOption=UNFORMATTED_VALUE una cella può arrivare come
/// String, num, bool o null; le righe possono essere più corte delle colonne
/// (Sheets elimina le celle vuote in coda).
library;

typedef Riga = List<Object?>;

/// Cella in posizione [i], o null se la riga è più corta.
Object? cellaAt(Riga riga, int i) => (i >= 0 && i < riga.length) ? riga[i] : null;

/// Testo "pulito": trim; vuoto e "/" diventano null; numeri interi senza ".0".
String? cellText(Object? v) {
  if (v == null) return null;
  String s;
  if (v is num) {
    s = (v is double && v == v.truncateToDouble()) ? v.toInt().toString() : v.toString();
  } else {
    s = v.toString();
  }
  s = s.replaceAll(' ', ' ').trim();
  if (s.isEmpty || s == '/') return null;
  return s;
}

bool? cellBool(Object? v) {
  if (v is bool) return v;
  final s = cellText(v)?.toLowerCase();
  if (s == 'true' || s == 'vero' || s == 'si' || s == 'sì') return true;
  if (s == 'false' || s == 'falso' || s == 'no') return false;
  return null;
}

/// Numero da num oppure da stringa italiana ("-7,5", "-€ 7,50", "1.234,56").
double? cellNumber(Object? v) {
  if (v is num) return v.toDouble();
  var s = cellText(v);
  if (s == null) return null;
  s = s
      .replaceAll('€', '')
      .replaceAll('−', '-') // meno tipografico
      .replaceAll(RegExp(r'\s'), '');
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(s);
}

/// Data da numero seriale di Sheets (giorni dal 30/12/1899) o da "gg/mm/aaaa".
DateTime? cellDate(Object? v) {
  if (v is num) {
    return DateTime.utc(1899, 12, 30).add(Duration(days: v.floor()));
  }
  final s = cellText(v);
  if (s == null) return null;
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  // Rifiuta date impossibili (es. 31/02): DateTime le "scivola" al mese dopo.
  return (dt.month == mo && dt.day == d) ? dt : null;
}

/// Numero seriale di Sheets per una data (per scrivere/confrontare celle data).
int dateToSerial(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1899, 12, 30)).inDays;

/// Intestazione normalizzata: minuscolo, spazi multipli/finali eliminati.
String normHeader(Object? v) =>
    (v?.toString() ?? '').replaceAll(' ', ' ').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Nome normalizzato per l'unione tra i tab: minuscolo, spazi e "_" ignorati.
String normalizeName(String nome) =>
    nome.toLowerCase().replaceAll(RegExp(r'[\s_ ]+'), '');

/// Anno di cammino da "4° anno" → 4.
int? annoCammino(String? s) {
  if (s == null) return null;
  final m = RegExp(r'\d+').firstMatch(s);
  return m == null ? null : int.parse(m.group(0)!);
}

/// Indice colonna 0-based → lettera A1 (0→A, 25→Z, 26→AA).
String colLetter(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}
