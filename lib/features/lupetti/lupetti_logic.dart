import '../../data/parsers/cell_utils.dart';
import '../../models/models.dart';

/// Filtra l'elenco: ricerca per nome (ignora maiuscole/spazi), anno di cammino,
/// sestiglia dell'anno [annoSestiglia].
List<Lupetto> filtraLupetti(
  List<Lupetto> tutti, {
  String query = '',
  int? anno,
  String? sestiglia,
  int? annoSestiglia,
}) {
  final q = normalizeName(query);
  return tutti.where((l) {
    if (q.isNotEmpty && !normalizeName(l.nome).contains(q)) return false;
    if (anno != null && l.annoNumero != anno) return false;
    if (sestiglia != null && l.sestiglie?.perAnno[annoSestiglia] != sestiglia) return false;
    return true;
  }).toList();
}

/// Nomi delle sestiglie presenti in un anno, in ordine alfabetico.
List<String> nomiSestiglie(List<Lupetto> tutti, int? anno) {
  if (anno == null) return [];
  final s = <String>{
    for (final l in tutti)
      if (l.sestiglie?.perAnno[anno] != null) l.sestiglie!.perAnno[anno]!,
  };
  return s.toList()..sort();
}

/// Anni di cammino presenti, ordinati (es. [2, 3, 4]).
List<int> anniCammino(List<Lupetto> tutti) =>
    ({for (final l in tutti) if (l.annoNumero != null) l.annoNumero!}.toList()..sort());
