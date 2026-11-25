import '../config/app_config.dart';
import '../models/models.dart';
import 'parsers/cell_utils.dart';
import 'parsers/parsers.dart';

/// Tutti i dati letti dal foglio, già interpretati.
class BrancoData {
  const BrancoData({
    required this.dati,
    required this.censimenti,
    required this.prede,
    required this.sestiglie,
    required this.movimenti,
    this.capi = const [],
  });
  final List<DatiRecapiti> dati;
  final List<Censimento> censimenti;
  final List<PredeSpecialita> prede;
  final SestiglieTab sestiglie;
  final List<Movimento> movimenti;

  /// Capi che possono fare spese (tab opzionale "Capi").
  final List<String> capi;

  /// [tab] = risultato di SheetsClient.batchGet (nome tab → righe).
  factory BrancoData.daTab(SheetProfile p, Map<String, List<Riga>> tab) {
    return BrancoData(
      dati: parseDati(tab[p.tabDati] ?? const []),
      censimenti: parseCensimenti(tab[p.tabCensimenti] ?? const []),
      prede: parsePrede(tab[p.tabPrede] ?? const []),
      sestiglie: parseSestiglie(tab[p.tabSestiglie] ?? const []),
      movimenti: parseBilancio(tab[p.tabBilancio] ?? const []),
      capi: parseCapi(tab[p.tabCapi] ?? const []),
    );
  }
}

class UnioneRisultato {
  const UnioneRisultato(this.lupetti, this.report);
  final List<Lupetto> lupetti;
  final ReportNomi report;
}

/// Unisce i 4 tab per lupetto usando il nome normalizzato come chiave.
/// Non esegue abbinamenti "furbi": i casi dubbi finiscono nel report.
UnioneRisultato unisciPerNome(
  BrancoData d, {
  Map<String, String> alias = AppConfig.aliasNomi,
}) {
  String chiave(String nome) {
    final k = normalizeName(nome);
    return alias[k] ?? k;
  }

  const nomiTab = ['Dati e recapiti', 'Censimenti', 'Prede e specialità', 'Sestiglie'];
  final duplicati = <(String, String)>[];

  Map<String, T> indicizza<T>(List<T> lista, String Function(T) nome, String tab) {
    final m = <String, T>{};
    for (final x in lista) {
      final k = chiave(nome(x));
      if (m.containsKey(k)) {
        duplicati.add((tab, nome(x)));
      } else {
        m[k] = x;
      }
    }
    return m;
  }

  final iDati = indicizza(d.dati, (x) => x.nome, nomiTab[0]);
  final iCens = indicizza(d.censimenti, (x) => x.nome, nomiTab[1]);
  final iPrede = indicizza(d.prede, (x) => x.nome, nomiTab[2]);
  final iSest = indicizza(d.sestiglie.righe, (x) => x.nome, nomiTab[3]);

  // Ordine di apparizione: prima i tab "principali", poi gli altri.
  final chiavi = <String>{
    ...iDati.keys,
    ...iCens.keys,
    ...iPrede.keys,
    ...iSest.keys,
  };

  // Nome da mostrare: il primo senza segnaposto "_" (es. "Diego ____").
  String nomeVisibile(String k) {
    final candidati = <String>[
      if (iDati[k] != null) iDati[k]!.nome,
      if (iSest[k] != null) iSest[k]!.nome,
      if (iCens[k] != null) iCens[k]!.nome,
      if (iPrede[k] != null) iPrede[k]!.nome,
    ];
    return candidati.firstWhere((n) => !n.contains('_'), orElse: () => candidati.first).trim();
  }

  final lupetti = <Lupetto>[];
  final mancanti = <String, List<String>>{};
  for (final k in chiavi) {
    final l = Lupetto(
      chiave: k,
      nome: nomeVisibile(k),
      dati: iDati[k],
      censimento: iCens[k],
      prede: iPrede[k],
      sestiglie: iSest[k],
    );
    lupetti.add(l);
    final mancaIn = <String>[
      if (l.dati == null) nomiTab[0],
      if (l.censimento == null) nomiTab[1],
      if (l.prede == null) nomiTab[2],
      if (l.sestiglie == null) nomiTab[3],
    ];
    if (mancaIn.isNotEmpty) mancanti[l.nome] = mancaIn;
  }

  // Suggerimenti: due chiavi diverse di cui una è l'inizio dell'altra e che non
  // compaiono negli stessi tab ("diego" vs "diegociccolini").
  final suggerimenti = <(String, String)>[];
  final lista = lupetti.toList();
  for (var i = 0; i < lista.length; i++) {
    for (var j = i + 1; j < lista.length; j++) {
      final a = lista[i], b = lista[j];
      final corto = a.chiave.length <= b.chiave.length ? a : b;
      final lungo = identical(corto, a) ? b : a;
      if (corto.chiave.isNotEmpty && lungo.chiave.startsWith(corto.chiave)) {
        suggerimenti.add((corto.nome, lungo.nome));
      }
    }
  }

  lupetti.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  return UnioneRisultato(
    lupetti,
    ReportNomi(mancanti: mancanti, suggerimenti: suggerimenti, duplicati: duplicati),
  );
}
