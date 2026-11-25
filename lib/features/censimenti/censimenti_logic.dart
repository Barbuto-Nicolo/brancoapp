import '../../models/models.dart';

enum VoceQuota {
  censimento('Censimento'),
  sanFra('Quota SanFra'),
  vdb('Quota VdB'),
  sanitaria('Scheda sanitaria');

  const VoceQuota(this.etichetta);
  final String etichetta;
}

/// Lupetti per cui la voce è ancora da sistemare.
/// - censimento / quote: stato "non pagato" ("/" = non dovuta, quindi escluso)
/// - sanitaria: checkbox FALSE
List<Lupetto> daSistemare(List<Lupetto> tutti, VoceQuota voce) {
  bool serve(Censimento c) => switch (voce) {
        VoceQuota.censimento => c.censimentoDaPagare,
        VoceQuota.sanFra => c.sanFraDaPagare,
        VoceQuota.vdb => c.vdbDaPagare,
        VoceQuota.sanitaria => c.sanitariaMancante,
      };
  return tutti.where((l) => l.censimento != null && serve(l.censimento!)).toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}

/// Stato di una voce (censimento, quota, scheda sanitaria) per un lupetto.
enum StatoVoce { pagato, daPagare, nonDovuto }

enum FiltroQuota { daPagare, pagati, tutti }

StatoVoce statoVoce(Censimento c, VoceQuota voce) => switch (voce) {
      VoceQuota.censimento => c.censimentoPagato
          ? StatoVoce.pagato
          : c.censimentoDaPagare
              ? StatoVoce.daPagare
              : StatoVoce.nonDovuto,
      VoceQuota.sanFra => c.sanFraPagata
          ? StatoVoce.pagato
          : c.sanFraDaPagare
              ? StatoVoce.daPagare
              : StatoVoce.nonDovuto,
      VoceQuota.vdb => c.vdbPagata
          ? StatoVoce.pagato
          : c.vdbDaPagare
              ? StatoVoce.daPagare
              : StatoVoce.nonDovuto,
      VoceQuota.sanitaria => c.sanitaria == true
          ? StatoVoce.pagato
          : c.sanitaria == false
              ? StatoVoce.daPagare
              : StatoVoce.nonDovuto,
    };

DateTime? dataVoce(Censimento c, VoceQuota voce) => switch (voce) {
      VoceQuota.censimento => c.dataCensimento,
      VoceQuota.sanFra => c.dataSanFra,
      VoceQuota.vdb => c.dataVdB,
      VoceQuota.sanitaria => null,
    };

/// Lupetti da mostrare per una voce, secondo il filtro. Chi non deve la voce ("/")
/// compare solo in "Tutti".
List<Lupetto> perVoce(List<Lupetto> tutti, VoceQuota voce, FiltroQuota filtro) {
  bool ok(StatoVoce s) => switch (filtro) {
        FiltroQuota.daPagare => s == StatoVoce.daPagare,
        FiltroQuota.pagati => s == StatoVoce.pagato,
        FiltroQuota.tutti => true,
      };
  return tutti.where((l) => l.censimento != null && ok(statoVoce(l.censimento!, voce))).toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
}

/// Quanti hanno già sistemato la voce e quanti no (esclusi i non dovuti).
({int pagati, int daPagare}) conteggi(List<Lupetto> tutti, VoceQuota voce) {
  var p = 0, d = 0;
  for (final l in tutti) {
    if (l.censimento == null) continue;
    switch (statoVoce(l.censimento!, voce)) {
      case StatoVoce.pagato:
        p++;
      case StatoVoce.daPagare:
        d++;
      case StatoVoce.nonDovuto:
        break;
    }
  }
  return (pagati: p, daPagare: d);
}
