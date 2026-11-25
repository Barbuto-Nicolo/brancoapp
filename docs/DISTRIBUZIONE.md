# Distribuzione dell'app ai capi

Prerequisito comune: i client ID Google configurati come in [CONFIGURAZIONE_GOOGLE.md](CONFIGURAZIONE_GOOGLE.md)
e gli utenti di test (o l'app pubblicata) nella schermata di consenso OAuth.

> **Profilo del foglio.** Prima di distribuire, controlla `AppConfig.profiloAttivo` in
> `lib/config/app_config.dart`. Per passare al foglio reale si cambia SOLO quella riga e si
> compila l'ID del foglio reale nello stesso file. Fallo solo quando sei pronto e con la
> copia già provata.

## Android

**Requisiti:** Flutter installato, Android SDK (lo installa Android Studio), JDK 17 (quello
incluso in Android Studio va bene). Non serve un Mac.

### 1. Chiave di firma (una volta sola, da conservare per sempre)
```bash
keytool -genkey -v -keystore ~/lupetti-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lupetti
```
Conserva il file `.jks` e le due password in un posto sicuro (es. gestore di password del gruppo).
**Se lo perdi non potrai più aggiornare l'app** già installata. Non metterlo mai nel repository.

Crea `android/key.properties` (è già escluso da git):
```properties
storePassword=LA_TUA_PASSWORD
keyPassword=LA_TUA_PASSWORD
keyAlias=lupetti
storeFile=/percorso/assoluto/lupetti-release.jks
```
Senza questo file la release viene firmata con la chiave di debug: va bene per provare,
ma **il login Google non funzionerà** se lo SHA-1 non è registrato (vedi punto 2).

### 2. Registra lo SHA-1 di rilascio in Google Cloud
```bash
keytool -list -v -keystore ~/lupetti-release.jks -alias lupetti
```
Copia lo SHA-1 e crea un secondo client ID Android (stesso package `it.branco.brancoapp`).
Se userai il Play Store con Play App Signing, aggiungi anche lo SHA-1 che Google mostra in
Play Console → Integrità dell'app.

### 3. Compila
Prima di ogni nuova versione aumenta `version:` in `pubspec.yaml` (es. `1.0.1+2`: il numero dopo
il `+` deve crescere sempre).
```bash
flutter build apk --release        # file unico da installare a mano
flutter build appbundle --release  # per il Play Store
```
Risultati: `build/app/outputs/flutter-apk/app-release.apk` e
`build/app/outputs/bundle/release/app-release.aab`.

### 4. Distribuisci
- **APK diretto (più semplice):** invia il file ai capi (Drive, WhatsApp). Sul telefono
  serve consentire "Installa app sconosciute" per l'app usata per aprirlo. Per aggiornare si
  reinstalla il nuovo APK sopra il vecchio (stessa firma).
- **Play Store (test interno):** serve un account sviluppatore Google Play (25 $ una tantum).
  Play Console → Test → Test interno → carica l'`.aab` → aggiungi le email dei capi come tester.
  Gli aggiornamenti arrivano automaticamente.

Versione minima Android: quella predefinita di Flutter (non modificata).

## iOS (TestFlight)

**Requisiti:** un Mac con Xcode aggiornato, un account **Apple Developer Program**
(99 $/anno; l'ID Apple gratuito non basta per TestFlight), un iPhone o simulatore per provare.

> **Versione minima iOS: 15.0** (richiesta dall'Xcode recente; esclude solo iPhone molto vecchi, 6s/7 non aggiornati).

### Passi
1. **Bundle ID:** `it.branco.brancoapp` (già nel progetto). Registralo su developer.apple.com →
   Identifiers e crea l'app in App Store Connect con lo stesso bundle ID.
2. **Google:** client ID iOS con quel bundle ID; incolla `GIDClientID` e lo schema URL invertito
   in `ios/Runner/Info.plist` (vedi CONFIGURAZIONE_GOOGLE.md).
3. **Firma:** apri `ios/Runner.xcworkspace` in Xcode → Runner → Signing & Capabilities →
   spunta "Automatically manage signing" e scegli il tuo Team.
4. **Compila e carica:**
   ```bash
   flutter build ipa --release
   ```
   Poi apri `build/ios/archive/Runner.xcarchive` in Xcode (Window → Organizer) → Distribute App →
   App Store Connect → Upload. In alternativa usa l'app *Transporter* con l'`.ipa`.
5. **TestFlight:** in App Store Connect → TestFlight, attendi l'elaborazione (10–30 min),
   crea un gruppo di **tester interni** (fino a 100 persone che hai invitato nel team, senza revisione
   Apple) oppure esterni (serve una breve revisione). I capi installano l'app TestFlight e accettano l'invito.
6. Ogni build di TestFlight scade dopo 90 giorni: ricarica una nuova versione prima.

Aumenta `version:` in `pubspec.yaml` per ogni nuovo caricamento.

## Controlli prima di consegnare ai capi
- `flutter analyze` e `flutter test` senza errori.
- Login con un account di test sul telefono vero, lettura dei 5 tab.
- Una modifica dall'app compare nella **copia** da browser, e viceversa (pull-to-refresh).
- Modalità aereo: l'app si apre e mostra i dati in cache; le modifiche sono bloccate con messaggio.
- Nel repository non ci sono `key.properties`, `.jks`, `GoogleService-Info.plist`, `google-services.json`.
