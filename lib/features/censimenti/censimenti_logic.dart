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
  VoceQuota.censimento =>
    c.censimentoPagato
        ? StatoVoce.pagato
        : c.censimentoDaPagare
        ? StatoVoce.daPagare
        : StatoVoce.nonDovuto,
  VoceQuota.sanFra =>
    c.sanFraPagata
        ? StatoVoce.pagato
        : c.sanFraDaPagare
        ? StatoVoce.daPagare
        : StatoVoce.nonDovuto,
  VoceQuota.vdb =>
    c.vdbPagata
        ? StatoVoce.pagato
        : c.vdbDaPagare
        ? StatoVoce.daPagare
        : StatoVoce.nonDovuto,
  VoceQuota.sanitaria =>
    c.sanitaria == true
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

// ---------------------------------------------------------------------------
// Incassi in Bilancio e quote extra
// ---------------------------------------------------------------------------

const categoriaQuote = 'Quote';

String descrizioneIncasso(String quota, String nome) => '$quota – $nome';
String descrizioneStorno(String quota, String nome) => 'Storno $quota – $nome';

/// Entrata nel Bilancio per una quota pagata.
Movimento movimentoIncasso(String quota, String nome, double importo, DateTime data) =>
    Movimento(descrizione: descrizioneIncasso(quota, nome), importo: importo, categoria: categoriaQuote, data: data);

/// Uscita di compensazione quando un pagamento viene annullato.
Movimento movimentoStorno(String quota, String nome, double importo, DateTime data) =>
    Movimento(descrizione: descrizioneStorno(quota, nome), importo: -importo, categoria: categoriaQuote, data: data);

/// Importo ancora "incassato" in Bilancio per quel pagamento (entrate meno storni),
/// o null se non c'è nulla da stornare.
double? daStornare(List<Movimento> movimenti, String quota, String nome) {
  final inc = descrizioneIncasso(quota, nome).toLowerCase();
  final sto = descrizioneStorno(quota, nome).toLowerCase();
  var netto = 0.0;
  for (final m in movimenti) {
    final d = m.descrizione.toLowerCase().trim();
    if (d == inc || d == sto) netto += m.importo;
  }
  return netto > 0.005 ? netto : null;
}

/// Controlla il modulo "Nuova quota". null = tutto ok.
String? validaNuovaQuota({
  required String nome,
  required double? importo,
  required int selezionati,
  required Iterable<String> esistenti,
}) {
  final n = nome.trim();
  if (n.isEmpty) return 'Scrivi il nome della quota (es. Uscita di Natale).';
  final riservati = [for (final v in VoceQuota.values) v.etichetta.toLowerCase()];
  if (riservati.contains(n.toLowerCase()) || esistenti.any((e) => e.toLowerCase() == n.toLowerCase())) {
    return 'Esiste già una quota con questo nome.';
  }
  if (importo == null || importo <= 0) return 'Importo non valido: scrivi un numero positivo (es. 12,50).';
  if (selezionati == 0) return 'Scegli almeno un lupetto.';
  return null;
}

/// Quante quote extra sono pagate / da pagare.
({int pagati, int daPagare}) conteggiExtra(List<QuotaExtraRiga> righe) =>
    (pagati: righe.where((r) => r.pagata).length, daPagare: righe.where((r) => !r.pagata).length);
