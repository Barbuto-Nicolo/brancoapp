/// Un parser per tab. Ognuno prende le righe grezze di batchGet e restituisce
/// modelli. Non fallisce mai su celle vuote/"/"; se la struttura è irriconoscibile
/// (àncora mancante) restituisce una lista vuota.
library;

import '../../models/models.dart';
import 'cell_utils.dart';
import 'tab_table.dart';

String? _at(Riga r, int i) => i < 0 ? null : cellText(cellaAt(r, i));

List<DatiRecapiti> parseDati(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) return [];
  final cNome = t.col('Lupetto/a');
  final cMadre = t.col('Madre');
  final cPadre = t.col('Padre');

  // Recapito / @ Mail sono duplicati: si leggono per POSIZIONE dopo Madre/Padre.
  Genitore? genitore(Riga r, int cNomeGen) {
    if (cNomeGen < 0) return null;
    final g = Genitore(nome: _at(r, cNomeGen), telefono: _at(r, cNomeGen + 1), email: _at(r, cNomeGen + 2));
    return g.vuoto ? null : g;
  }

  final out = <DatiRecapiti>[];
  for (final r in t.rows) {
    final nome = _at(r, cNome);
    if (nome == null) continue;
    final anno = _at(r, t.col('Anno'));
    out.add(
      DatiRecapiti(
        nome: nome,
        anno: anno,
        annoNumero: annoCammino(anno),
        codCens: _at(r, t.col('Cod. Cens.')),
        natoA: _at(r, t.col('Nato/a a')),
        dataNascita: cellDate(cellaAt(r, t.col('il'))),
        codiceFiscale: _at(r, t.col('C.F.')),
        residenza: _at(r, t.col('Residenza')),
        madre: genitore(r, cMadre),
        padre: genitore(r, cPadre),
      ),
    );
  }
  return out;
}

List<Censimento> parseCensimenti(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) return [];
  final cNome = t.col('Lupetto/a');
  final cCens = t.col('Censimento');
  final cSan = t.col('Quota SanFra');
  final cVdb = t.col('Quota VdB');
  // "Data" e i due "in data" sono nella colonna subito dopo il loro valore.
  final cDataCens = t.col('Data');

  final out = <Censimento>[];
  for (final r in t.rows) {
    final nome = _at(r, cNome);
    if (nome == null) continue;
    out.add(
      Censimento(
        nome: nome,
        anno: _at(r, t.col('Anno')),
        datiCens: _at(r, t.col('dati cens.')),
        sanitaria: cellBool(cellaAt(r, t.col('sanitaria'))),
        censimento: _at(r, cCens),
        dataCensimento: cellDate(cellaAt(r, cDataCens)),
        quotaSanFra: _at(r, cSan),
        dataSanFra: cSan < 0 ? null : cellDate(cellaAt(r, cSan + 1)),
        quotaVdB: _at(r, cVdb),
        dataVdB: cVdb < 0 ? null : cellDate(cellaAt(r, cVdb + 1)),
        note: _at(r, t.col('Note')),
      ),
    );
  }
  return out;
}

List<PredeSpecialita> parsePrede(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) return [];
  final cNome = t.col('Lupetto/a');
  final cCaccia = t.col('Caccia per');
  final cPrede = t.col('Prede');
  final cAcq = t.col('Specialità già acquisite');
  // Prede: "Con chi" e "Stato" subito dopo "Prede".
  final blocchi = [t.col('Specialità 1'), t.col('Specialità 2'), t.col('Specialità 3')];

  final out = <PredeSpecialita>[];
  for (final r in t.rows) {
    final nome = _at(r, cNome);
    if (nome == null) continue;
    final caccia = _at(r, cCaccia);
    final acquisite = (_at(r, cAcq) ?? '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    out.add(
      PredeSpecialita(
        nome: nome,
        cacciaPer: caccia?.replaceAll('*', '').trim(),
        cacciaAsterisco: caccia?.contains('*') ?? false,
        prede: _at(r, cPrede),
        conChi: cPrede < 0 ? null : _at(r, cPrede + 1),
        stato: cPrede < 0 ? null : _at(r, cPrede + 2),
        specialitaAcquisite: acquisite,
        impegni: [
          for (final b in blocchi)
            ImpegnoSpecialita(
              specialita: _at(r, b),
              impegno: b < 0 ? null : _at(r, b + 1),
              conChi: b < 0 ? null : _at(r, b + 2),
              stato: b < 0 ? null : _at(r, b + 3),
            ),
        ],
      ),
    );
  }
  return out;
}

SestiglieTab parseSestiglie(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Lupetto/a');
  if (t == null) return const SestiglieTab(anni: [], righe: []);
  final cNome = t.col('Lupetto/a');

  // Colonne anno: intestazioni numeriche (2024, 2025, ...).
  final colonneAnno = <int, int>{}; // anno → indice colonna
  for (var i = 0; i < t.headers.length; i++) {
    final a = int.tryParse(t.headers[i]);
    if (a != null && a > 1900) colonneAnno[a] = i;
  }
  final anni = colonneAnno.keys.toList()..sort();

  final righe = <SestigliaRiga>[];
  for (final r in t.rows) {
    final nome = _at(r, cNome);
    if (nome == null) continue;
    righe.add(SestigliaRiga(nome: nome, perAnno: {for (final a in anni) a: _at(r, colonneAnno[a]!)}));
  }
  return SestiglieTab(anni: anni, righe: righe);
}

/// Bilancio: un movimento è una riga con descrizione E importo numerico.
/// La riga del totale (importo senza descrizione) e le righe vuote sono ignorate.
List<Movimento> parseBilancio(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Dettagli spese');
  if (t == null) return [];
  final cDesc = t.col('Dettagli spese');
  final cCat = t.col('Categoria');
  final cCosto = t.col('Costo');
  final cData = t.col('Data della transazione');
  final cPag = t.col('Pagato da');
  final cRimb = t.col('Da rimborsare');
  final cRimbData = t.col('Rimborsata il');

  final out = <Movimento>[];
  for (final r in t.rows) {
    final desc = _at(r, cDesc);
    final importo = cellNumber(cellaAt(r, cCosto));
    if (desc == null || importo == null) continue;
    out.add(
      Movimento(
        descrizione: desc,
        importo: importo,
        categoria: _at(r, cCat),
        data: cellDate(cellaAt(r, cData)),
        pagatoDa: _at(r, cPag),
        note: _at(r, t.col('Note')),
        daRimborsare: cRimb >= 0 && (cellBool(cellaAt(r, cRimb)) ?? false),
        rimborsataIl: cRimbData < 0 ? null : cellDate(cellaAt(r, cRimbData)),
      ),
    );
  }
  return out;
}

/// Tab opzionale "Capi": un nome per riga sotto l'intestazione "Capo/a"
/// (se manca l'intestazione si leggono tutte le righe).
List<String> parseCapi(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Capo/a');
  final righe = t?.rows ?? valori;
  final c = t == null ? 0 : t.col('Capo/a');
  final out = <String>[];
  for (final r in righe) {
    final n = _at(r, c);
    if (n != null && !out.contains(n)) out.add(n);
  }
  return out;
}

/// Tab opzionale "Quote": Quota | Importo | Lupetto/a | Pagato il.
/// Riga senza lupetto = importo di una quota fissa; con lupetto = quota extra.
QuoteTab parseQuote(List<Riga> valori) {
  final t = TabTable.trova(valori, 'Quota');
  if (t == null) return const QuoteTab();
  final cQ = t.col('Quota');
  final cI = t.col('Importo');
  final cL = t.col('Lupetto/a');
  final cP = t.col('Pagato il');
  final importi = <String, double>{};
  final righe = <QuotaExtraRiga>[];
  for (final r in t.rows) {
    final q = _at(r, cQ);
    if (q == null) continue;
    final imp = cI < 0 ? null : cellNumber(cellaAt(r, cI));
    final l = _at(r, cL);
    if (l == null) {
      if (imp != null) importi[q] = imp;
    } else {
      righe.add(QuotaExtraRiga(quota: q, lupetto: l, importo: imp, pagatoIl: cP < 0 ? null : cellDate(cellaAt(r, cP))));
    }
  }
  return QuoteTab(importi: importi, righe: righe);
}
