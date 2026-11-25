import '../../models/models.dart';

class GruppoSestiglia {
  GruppoSestiglia(this.nome, this.membri, this.perAnnoCammino, this.senzaAnno);
  final String nome;
  final List<Lupetto> membri;

  /// anno di cammino (2, 3, 4) → quanti lupetti.
  final Map<int, int> perAnnoCammino;

  /// Lupetti di cui l'anno di cammino non è noto (non presenti in Dati/Censimenti).
  final int senzaAnno;
}

/// Compone le sestiglie di un anno con il conteggio per anno di cammino.
List<GruppoSestiglia> gruppiSestiglie(List<Lupetto> tutti, int anno) {
  final per = <String, List<Lupetto>>{};
  for (final l in tutti) {
    final s = l.sestiglie?.perAnno[anno];
    if (s != null) per.putIfAbsent(s, () => []).add(l);
  }
  final nomi = per.keys.toList()..sort();
  return [
    for (final n in nomi)
      () {
        final membri = per[n]!..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        final conteggio = <int, int>{2: 0, 3: 0, 4: 0};
        var senza = 0;
        for (final m in membri) {
          final a = m.annoNumero;
          if (a == null) {
            senza++;
          } else {
            conteggio.update(a, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        return GruppoSestiglia(n, membri, conteggio, senza);
      }(),
  ];
}
