/// UNICO file di configurazione dell'app.
///
/// Per passare dal foglio "copia" al foglio "reale" basta cambiare
/// [AppConfig.profiloAttivo]. Nient'altro.
library;

/// Un profilo = un Google Sheet con i nomi dei suoi 5 tab.
class SheetProfile {
  const SheetProfile({
    required this.nome,
    required this.spreadsheetId,
    required this.tabDati,
    required this.tabCensimenti,
    required this.tabPrede,
    required this.tabSestiglie,
    required this.tabBilancio,
    this.tabCapi = 'Capi',
    this.titoloFoglio = 'BRANCO 2026_2027',
  });

  final String nome;
  final String spreadsheetId;
  final String tabDati;
  final String tabCensimenti;
  final String tabPrede;
  final String tabSestiglie;
  final String tabBilancio;

  /// Tab OPZIONALE con l'elenco dei capi che possono fare spese. Se non esiste
  /// viene creato dall'app la prima volta che si aggiunge un capo.
  final String tabCapi;

  /// Nome del file Google Sheets, mostrato nell'app (solo per informazione).
  final String titoloFoglio;

  /// Ordine fisso usato da batchGet: la risposta segue lo stesso ordine.
  List<String> get tuttiITab =>
      [tabDati, tabCensimenti, tabPrede, tabSestiglie, tabBilancio];

  /// Il foglio reale non è ancora stato autorizzato: finché l'ID è il
  /// segnaposto, l'app rifiuta di usarlo.
  bool get configurato => !spreadsheetId.startsWith('DA_INSERIRE');
}

class AppConfig {
  AppConfig._();

  /// >>> L'UNICA impostazione da cambiare per passare al foglio reale <<<
  /// Valori ammessi: 'copia' oppure 'reale'.
  static const String profiloAttivo = 'copia';

  static const Map<String, SheetProfile> profili = {
    'copia': SheetProfile(
      nome: 'copia',
      spreadsheetId: '1w4TS-ipQKUAiuvJRSXer45_xqe5APmbdbJl4YGFrAM8',
      tabDati: 'Dati e recapiti',
      tabCensimenti: 'Censimenti e quote campi 2526',
      tabPrede: 'Prede e specialità 2526',
      tabSestiglie: 'Sestiglie',
      tabBilancio: 'Bilancio',
    ),
    'reale': SheetProfile(
      nome: 'reale',
      // Da compilare SOLO dopo l'autorizzazione esplicita.
      spreadsheetId: 'DA_INSERIRE',
      tabDati: 'Dati e recapiti',
      tabCensimenti: 'Censimenti e quote campi 25/26',
      tabPrede: 'Prede e specialità 25/26',
      tabSestiglie: 'Sestiglie',
      tabBilancio: 'Bilancio',
    ),
  };

  static SheetProfile get attivo {
    final p = profili[profiloAttivo];
    if (p == null) {
      throw StateError('Profilo "$profiloAttivo" inesistente.');
    }
    if (!p.configurato) {
      throw StateError('Il profilo "$profiloAttivo" non è ancora configurato.');
    }
    return p;
  }

  /// Scope OAuth richiesto ai capi (lettura e scrittura dei fogli).
  static const String scopeSheets = 'https://www.googleapis.com/auth/spreadsheets';

  /// ID client OAuth. NON sono segreti (sono identificatori pubblici), ma vanno
  /// copiati dalla console Google Cloud. Vedi docs/CONFIGURAZIONE_GOOGLE.md.
  /// - Android: serve il client ID di tipo *Applicazione web* (serverClientId).
  /// - iOS: il client ID iOS è in ios/Runner/Info.plist (GIDClientID).
  static const String googleServerClientId =
      '346696487405-msbkc7t65lc20fc0kbjv83cgchgjgrqf.apps.googleusercontent.com';

  /// Client ID di tipo *Applicazione web* usato SOLO dalla versione per il browser
  /// (GitHub Pages). Nel client in Google Cloud l'origine JavaScript autorizzata
  /// deve essere https://barbuto-nicolo.github.io
  static const String googleBrowserClientId =
      '346696487405-clnn71qpdue38d5d4q5fc5eef700nslc.apps.googleusercontent.com';

  /// Alias opzionali per nomi che non coincidono tra i tab.
  /// Chiave e valore sono nomi NORMALIZZATI (minuscolo, senza spazi né "_"),
  /// es. {'diego': 'diegociccolini'}. Vuota di default: i casi dubbi
  /// compaiono nel report dei nomi senza corrispondenza.
  static const Map<String, String> aliasNomi = {};
}
