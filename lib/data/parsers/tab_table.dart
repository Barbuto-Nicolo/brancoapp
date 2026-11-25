import 'cell_utils.dart';

/// Un tab con la riga di intestazione individuata cercando una cella-àncora
/// (es. "Lupetto/a"), invece di assumere che sia la riga 1.
class TabTable {
  TabTable._(this.headerRow, this.headers, this.rows);

  /// Indice (0-based) della riga di intestazione nel foglio.
  final int headerRow;

  /// Intestazioni normalizzate (minuscolo, trim).
  final List<String> headers;

  /// Righe sotto l'intestazione.
  final List<Riga> rows;

  /// Restituisce null se l'àncora non esiste (tab vuoto o struttura cambiata).
  static TabTable? trova(List<Riga> valori, String ancora) {
    final a = normHeader(ancora);
    for (var r = 0; r < valori.length; r++) {
      final riga = valori[r];
      if (riga.any((c) => normHeader(c) == a)) {
        return TabTable._(r, riga.map(normHeader).toList(), valori.sublist(r + 1));
      }
    }
    return null;
  }

  /// Indice della prima colonna con questa intestazione, -1 se manca.
  int col(String nome, {int da = 0}) {
    final n = normHeader(nome);
    for (var i = da; i < headers.length; i++) {
      if (headers[i] == n) return i;
    }
    return -1;
  }

  /// Numero di riga A1 (1-based) della riga dati [indiceRiga] (0-based in [rows]).
  int numeroRigaA1(int indiceRiga) => headerRow + 2 + indiceRiga;
}
