# Branco – app per i capi

App Flutter (Android + iOS) per consultare e modificare il Google Sheet "BRANCO 2026_2027".
**Il foglio è l'unica fonte di verità**: l'app non ha backend né utenti propri; valgono i permessi
del foglio per l'account Google di ciascun capo.

## Comandi
```bash
flutter pub get
flutter analyze
flutter test
flutter run            # serve prima la configurazione Google (docs/CONFIGURAZIONE_GOOGLE.md)
```

## Foglio "copia" o "reale"
Si cambia UNA riga: `AppConfig.profiloAttivo` in [lib/config/app_config.dart](lib/config/app_config.dart).
Lo stesso file contiene ID e nomi dei tab dei due profili. Il profilo `reale` ha l'ID segnaposto
`DA_INSERIRE` e l'app lo rifiuta finché non lo compili.

## Struttura
```
lib/config/            configurazione (profili, scope, alias nomi)
lib/data/              client Sheets, parser per tab, unione per nome, cache, scrittura con conflitti
lib/models/            modelli dei 5 tab
lib/features/<sezione> schermate e logica (lupetti, sestiglie, censimenti, prede, bilancio, ...)
test/                  parser, unione nomi, client, scritture (foglio finto in memoria), schermate
```

## Come funziona (in breve)
- **Lettura:** una sola chiamata `batchGet` per tutti i tab (`UNFORMATTED_VALUE`). I tab si
  collegano per **nome normalizzato** (minuscolo, senza spazi né "_"). I nomi che non coincidono
  compaiono in *Menu → Controllo nomi*; per unirli a mano si aggiunge un alias in `AppConfig.aliasNomi`.
- **Cache:** l'ultima lettura è salvata sul telefono e mostrata offline. Si cancella con "Esci".
- **Scrittura:** prima si rilegge il tab, si ritrova la riga cercando il nome, si confronta ogni
  cella con il valore che l'app aveva caricato (se diverso → conflitto, il capo sceglie), poi si
  scrivono **solo** le celle modificate. Offline le modifiche sono bloccate.
- **Bilancio:** il saldo lo calcola l'app. Un movimento va nella prima riga libera sopra il totale;
  se non c'è spazio si inserisce una riga prima del totale. La formula del totale non viene mai scritta.

## Novità della grafica e delle funzioni
- **Tema scout:** testata notturna con tende e falò, sestiglie con il fazzolettone del loro colore.
  Colori e stili sono tutti in [lib/theme/app_theme.dart](lib/theme/app_theme.dart); le illustrazioni
  sono disegnate in codice ([scout_art.dart](lib/features/common/scout_art.dart)), senza immagini.
- **Collegamento al foglio:** il chip nella testata dice se l'app è collegata (e a quale foglio),
  sta aggiornando, è offline o ha perso l'accesso. Toccandolo si vede il nome del file, l'ultimo
  aggiornamento e si può aprire il foglio. L'app rilegge il foglio da sola ogni 30 secondi mentre è aperta.
- **Capi e rimborsi (Bilancio):** i capi che possono fare spese stanno nel tab `Capi` del foglio
  (creato dall'app alla prima aggiunta). Una spesa si può segnare "anticipata": nel Bilancio compaiono
  le colonne `Da rimborsare` e `Rimborsata il` (create a destra dell'ultima colonna al primo uso),
  il promemoria con quanto spetta a ciascun capo, il badge sulla scheda Bilancio e la condivisione su WhatsApp.
- **Nuovo lupetto:** si aggiunge a Dati e recapiti, Sestiglie, Censimenti e Prede in un colpo solo.
- **Anteprima senza login:** `flutter run -t tool/preview_main.dart -d <simulatore>` mostra l'app con dati finti.

## Limiti noti
- Due capi che scrivono nello stesso istante: il controllo conflitti protegge dalle modifiche fatte
  *dopo* il caricamento, non da una gara di pochi millisecondi tra due scritture.
- Le date si scrivono come numeri di data di Google Sheets: se una cella "Data" non ha il formato
  data, nel foglio comparirà il numero. Va verificato una volta sulla copia.
- La cache locale non è cifrata (contiene dati personali).
