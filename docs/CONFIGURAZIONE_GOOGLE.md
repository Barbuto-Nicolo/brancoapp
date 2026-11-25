# Dove inserire gli ID client Google

Nessuno di questi valori è un segreto (sono identificatori pubblici), ma vanno copiati
dalla console Google Cloud (API e servizi → Credenziali). NON servono mai "client secret",
chiavi API o service account.

| Dove | Cosa | Client ID da usare |
|---|---|---|
| `lib/config/app_config.dart` → `googleServerClientId` | ID che finisce nella stringa `'...apps.googleusercontent.com'` | Tipo **Applicazione web** (serve a Android) |
| `lib/config/app_config.dart` → `googleBrowserClientId` | ID del client per il browser | Tipo **Applicazione web** (secondo client, solo per GitHub Pages) |
| `ios/Runner/Info.plist` → `GIDClientID` | ID client completo | Tipo **iOS** |
| `ios/Runner/Info.plist` → `CFBundleURLSchemes` | lo stesso ID iOS **invertito**: `com.googleusercontent.apps.<parte-prima-di-.apps...>` | Tipo **iOS** |
| Console Google Cloud (nessun file) | Client Android con package `it.branco.brancoapp` + SHA-1 | Tipo **Android** |

Il client Android non compare nel codice: Google lo riconosce da package name e SHA-1.
Il SHA-1 di debug si ottiene con:

```bash
cd android && ./gradlew signingReport
```


## Far entrare tutti i capi (senza elencare le email)
In **Google Auth Platform → Pubblico** premi **Pubblica app**: lo stato passa da "Test" a "In produzione".
Da quel momento non servono più gli utenti di test e il login non scade ogni 7 giorni.

- Al primo accesso Google mostra "app non verificata": **Avanzate → Vai a BrancoApp (non sicuro)**.
- Fino a 100 utenti non serve la verifica di Google.
- Chi accede vede comunque solo i fogli a cui è stato dato accesso: la condivisione si gestisce in
  Google Drive (**Condividi → Editor**), non qui.
