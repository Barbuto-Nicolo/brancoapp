# Versione web su GitHub Pages

L'app funziona anche nel browser, così i capi con iPhone non hanno bisogno di cavo, Mac o
account Apple a pagamento. Indirizzo finale:

**https://barbuto-nicolo.github.io/brancoapp/**

## Una volta sola

### 1. Google Cloud (già fatto)
Il client "Applicazione web" ha come origine JavaScript autorizzata `https://barbuto-nicolo.github.io`
(senza barra finale e senza il nome del repository). Il suo ID è in
`lib/config/app_config.dart` → `googleBrowserClientId`.

### 2. GitHub: attivare Pages
Sul repository `brancoapp` → **Settings → Pages → Build and deployment → Source: GitHub Actions**.

### 3. Caricare il codice
Il repository deve essere **pubblico** (Pages gratuito non funziona sui privati).
Dalla cartella del progetto:

```bash
git init -b main
git add .
git status
```
Controlla l'elenco: non devono comparire file `.jks`, `key.properties` o PDF personali
(sono già esclusi). Poi:

```bash
git commit -m "BrancoApp"
git remote add origin https://github.com/Barbuto-Nicolo/brancoapp.git
git push -u origin main
```

### 4. Aspettare la pubblicazione
Su GitHub → scheda **Actions**: parte "Pubblica la versione web" (circa 3-5 minuti). Quando è
verde l'app è online all'indirizzo qui sopra. Ogni successivo `git push` la aggiorna da solo.

## Per i capi con iPhone
1. Aprire l'indirizzo in **Safari**.
2. Toccare **Condividi → Aggiungi alla schermata Home**.
3. Aprire l'icona BrancoApp, toccare "Accedi con Google".

Su Android si apre in Chrome e si installa con **⋮ → Installa app**.

## Cose da sapere
- **Accesso di un'ora:** nel browser Google dà un permesso che dura circa un'ora. L'app prova a
  rinnovarlo da sola; se non ci riesce compare "Accedi" e basta un tocco.
- **Dati sul telefono:** l'ultima lettura resta nella memoria del browser (non cifrata) e si cancella con
  "Esci". Non usare l'app web su computer condivisi.
- **Il foglio:** ogni capo deve avere accesso come **Editor** al foglio Google, con l'account che usa per
  accedere.
- **Il repository è pubblico:** il codice non contiene password. Contiene però l'ID del foglio. Quando
  userete il foglio reale, conviene non scriverlo nel codice ma passarlo alla compilazione.
- **Aggiornamenti:** dopo una nuova pubblicazione il browser può mostrare ancora la versione vecchia
  fino alla riapertura dell'app (a volte due).
