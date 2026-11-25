/// Modelli dati dei 5 tab. Tutti i campi opzionali sono null quando la cella
/// è vuota o contiene "/".
library;

class Genitore {
  const Genitore({this.nome, this.telefono, this.email});
  final String? nome;
  final String? telefono;
  final String? email;

  bool get vuoto => nome == null && telefono == null && email == null;
}

/// Tab "Dati e recapiti".
class DatiRecapiti {
  const DatiRecapiti({
    required this.nome,
    this.anno,
    this.annoNumero,
    this.codCens,
    this.natoA,
    this.dataNascita,
    this.codiceFiscale,
    this.residenza,
    this.madre,
    this.padre,
  });
  final String nome;
  final String? anno; // "4° anno"
  final int? annoNumero; // 4
  final String? codCens;
  final String? natoA;
  final DateTime? dataNascita;
  final String? codiceFiscale;
  final String? residenza;
  final Genitore? madre;
  final Genitore? padre;
}

/// Tab "Censimenti e quote campi".
class Censimento {
  const Censimento({
    required this.nome,
    this.anno,
    this.datiCens,
    this.sanitaria,
    this.censimento,
    this.dataCensimento,
    this.quotaSanFra,
    this.dataSanFra,
    this.quotaVdB,
    this.dataVdB,
    this.note,
  });
  final String nome;
  final String? anno;
  final String? datiCens;
  final bool? sanitaria; // true = scheda consegnata
  final String? censimento; // "pagato" / "non pagato"
  final DateTime? dataCensimento;
  final String? quotaSanFra; // null = "/" = non dovuta
  final DateTime? dataSanFra;
  final String? quotaVdB;
  final DateTime? dataVdB;
  final String? note;

  static bool _pagato(String? s) => s != null && s.toLowerCase() == 'pagato';
  static bool _nonPagato(String? s) => s != null && s.toLowerCase() == 'non pagato';

  bool get censimentoPagato => _pagato(censimento);
  bool get censimentoDaPagare => _nonPagato(censimento);
  bool get sanFraPagata => _pagato(quotaSanFra);
  bool get sanFraDaPagare => _nonPagato(quotaSanFra);
  bool get vdbPagata => _pagato(quotaVdB);
  bool get vdbDaPagare => _nonPagato(quotaVdB);
  bool get sanitariaMancante => sanitaria == false;
}

/// Un blocco "Specialità N / Impegno / Con chi / Stato".
class ImpegnoSpecialita {
  const ImpegnoSpecialita({this.specialita, this.impegno, this.conChi, this.stato});
  final String? specialita;
  final String? impegno;
  final String? conChi;
  final String? stato;
  bool get vuoto => specialita == null && impegno == null && conChi == null && stato == null;
}

/// Tab "Prede e specialità".
class PredeSpecialita {
  const PredeSpecialita({
    required this.nome,
    this.cacciaPer,
    this.cacciaAsterisco = false,
    this.prede,
    this.conChi,
    this.stato,
    this.specialitaAcquisite = const [],
    this.impegni = const [],
  });
  final String nome;
  final String? cacciaPer; // "Lupo Anziano" (senza "*")
  final bool cacciaAsterisco;
  final String? prede;
  final String? conChi;
  final String? stato; // "Non assegnata", ...
  final List<String> specialitaAcquisite;
  final List<ImpegnoSpecialita> impegni; // sempre 3 elementi
}

/// Tab "Sestiglie": una riga per lupetto, una colonna per anno.
class SestigliaRiga {
  const SestigliaRiga({required this.nome, required this.perAnno});
  final String nome;

  /// anno → nome sestiglia (null se vuoto o "/").
  final Map<int, String?> perAnno;
}

class SestiglieTab {
  const SestiglieTab({required this.anni, required this.righe});
  final List<int> anni;
  final List<SestigliaRiga> righe;

  /// Ultimo anno (colonna) che contiene almeno una sestiglia.
  int? get annoDefault {
    for (final a in anni.reversed) {
      if (righe.any((r) => r.perAnno[a] != null)) return a;
    }
    return anni.isEmpty ? null : anni.last;
  }
}

/// Tab "Bilancio": un movimento.
class Movimento {
  const Movimento({
    required this.descrizione,
    required this.importo,
    this.categoria,
    this.data,
    this.pagatoDa,
    this.note,
    this.daRimborsare = false,
    this.rimborsataIl,
  });
  final String descrizione;
  final double importo; // negativo = uscita
  final String? categoria;
  final DateTime? data;
  final String? pagatoDa;
  final String? note;

  /// Spesa anticipata da un capo con la persona che attende il rimborso
  /// ("Pagato da"). Colonne opzionali "Da rimborsare" / "Rimborsata il".
  final bool daRimborsare;
  final DateTime? rimborsataIl;

  /// Spesa anticipata e non ancora rimborsata.
  bool get rimborsoPendente => daRimborsare && rimborsataIl == null && importo < 0;
}

/// Calcoli di bilancio fatti dall'app (la cella del totale NON viene letta).
class RiepilogoBilancio {
  RiepilogoBilancio(this.movimenti);
  final List<Movimento> movimenti;

  double get saldo => movimenti.fold(0.0, (s, m) => s + m.importo);

  Map<String, double> get perCategoria =>
      _somma((m) => m.categoria ?? 'Senza categoria');
  Map<String, double> get perPagatoDa => _somma((m) => m.pagatoDa ?? 'Non indicato');

  /// Spese anticipate e non ancora rimborsate.
  List<Movimento> get daRimborsare => [for (final m in movimenti) if (m.rimborsoPendente) m];

  /// Chi deve ricevere soldi → importo totale (positivo).
  Map<String, double> get rimborsiPerPersona {
    final out = <String, double>{};
    for (final m in daRimborsare) {
      out.update(m.pagatoDa ?? 'Non indicato', (v) => v + m.importo.abs(), ifAbsent: () => m.importo.abs());
    }
    return out;
  }

  double get totaleDaRimborsare => rimborsiPerPersona.values.fold(0.0, (a, b) => a + b);

  Map<String, double> _somma(String Function(Movimento) chiave) {
    final out = <String, double>{};
    for (final m in movimenti) {
      out.update(chiave(m), (v) => v + m.importo, ifAbsent: () => m.importo);
    }
    return out;
  }
}

/// Vista unita di un lupetto su tutti i tab (qualunque parte può mancare).
class Lupetto {
  const Lupetto({
    required this.chiave,
    required this.nome,
    this.dati,
    this.censimento,
    this.prede,
    this.sestiglie,
  });
  final String chiave; // nome normalizzato
  final String nome; // nome da mostrare
  final DatiRecapiti? dati;
  final Censimento? censimento;
  final PredeSpecialita? prede;
  final SestigliaRiga? sestiglie;

  int? get annoNumero => dati?.annoNumero ?? annoCammino(censimento?.anno);
  static int? annoCammino(String? s) {
    if (s == null) return null;
    final m = RegExp(r'\d+').firstMatch(s);
    return m == null ? null : int.parse(m.group(0)!);
  }
}

/// Report dei nomi che non trovano corrispondenza tra i tab.
class ReportNomi {
  const ReportNomi({
    required this.mancanti,
    required this.suggerimenti,
    required this.duplicati,
  });

  /// nome da mostrare → tab in cui il lupetto NON compare.
  final Map<String, List<String>> mancanti;

  /// Coppie di nomi probabilmente uguali (uno è l'inizio dell'altro) che NON
  /// sono state unite: servono a decidere se aggiungere un alias in config.
  final List<(String, String)> suggerimenti;

  /// Nomi che compaiono più volte nello stesso tab: (tab, nome).
  final List<(String, String)> duplicati;

  bool get pulito => mancanti.isEmpty && suggerimenti.isEmpty && duplicati.isEmpty;
}

/// Dati per aggiungere un lupetto nuovo a tutti i tab.
class NuovoLupetto {
  const NuovoLupetto({
    required this.nome,
    required this.annoCammino,
    required this.sestiglia,
    required this.annoSestiglia,
  });
  final String nome;
  final int annoCammino;
  final String sestiglia;
  final int annoSestiglia;
}

/// Risultato dell'aggiunta di un lupetto: tab scritti e tab saltati (con motivo).
class EsitoNuovoLupetto {
  const EsitoNuovoLupetto(this.scritti, this.saltati);
  final List<String> scritti;
  final Map<String, String> saltati;
  bool get completo => saltati.isEmpty;
}

/// Risultato dell'eliminazione di un lupetto: tab ripuliti e tab saltati (con motivo).
class EsitoEliminazione {
  const EsitoEliminazione(this.eliminati, this.saltati);
  final List<String> eliminati;
  final Map<String, String> saltati;
}
