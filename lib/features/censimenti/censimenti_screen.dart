import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/cell_utils.dart';
import '../../data/write_service.dart';
import '../../models/models.dart';
import '../common/format.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import 'censimenti_logic.dart';
import 'nuova_quota_page.dart';

class CensimentiScreen extends ConsumerStatefulWidget {
  const CensimentiScreen({super.key});
  @override
  ConsumerState<CensimentiScreen> createState() => _CensimentiScreenState();
}

class _CensimentiScreenState extends ConsumerState<CensimentiScreen> {
  VoceQuota _voce = VoceQuota.censimento;
  FiltroQuota _filtro = FiltroQuota.daPagare;

  /// Quota extra selezionata (null = una delle voci fisse).
  String? _extra;

  bool get _sanitaria => _voce == VoceQuota.sanitaria;
  String get _siTesto => _sanitaria ? 'Consegnata' : 'Pagato';
  String get _noTesto => _sanitaria ? 'Non consegnata' : 'Da pagare';

  // --- campi del foglio per la voce scelta --------------------------------

  Campo _campoStato(Censimento c, Object? nuovo) => switch (_voce) {
    VoceQuota.censimento => Campo(etichetta: 'Censimento', header: 'Censimento', atteso: c.censimento, nuovo: nuovo),
    VoceQuota.sanFra => Campo(etichetta: 'Quota SanFra', header: 'Quota SanFra', atteso: c.quotaSanFra, nuovo: nuovo),
    VoceQuota.vdb => Campo(etichetta: 'Quota VdB', header: 'Quota VdB', atteso: c.quotaVdB, nuovo: nuovo),
    VoceQuota.sanitaria => Campo(etichetta: 'Scheda sanitaria', header: 'sanitaria', atteso: c.sanitaria, nuovo: nuovo),
  };

  Campo? _campoData(Censimento c, Object? nuovo) => switch (_voce) {
    VoceQuota.censimento => Campo(etichetta: 'Data censimento', header: 'Data', atteso: c.dataCensimento, nuovo: nuovo),
    VoceQuota.sanFra => Campo(
      etichetta: 'Data SanFra',
      header: 'Quota SanFra',
      offset: 1,
      atteso: c.dataSanFra,
      nuovo: nuovo,
    ),
    VoceQuota.vdb => Campo(etichetta: 'Data VdB', header: 'Quota VdB', offset: 1, atteso: c.dataVdB, nuovo: nuovo),
    VoceQuota.sanitaria => null,
  };

  Future<void> _scrivi(Lupetto l, List<Campo> campi) => scriviCampiLupetto(
    context,
    ref,
    tab: ref.read(profiloProvider).tabCensimenti,
    nomeNelTab: l.censimento!.nome,
    campi: campi,
  );

  // --- azioni ---------------------------------------------------------------

  QuoteTab get _quote => ref.read(datiProvider).value?.data.quote ?? const QuoteTab();
  List<Movimento> get _movimenti => ref.read(datiProvider).value?.data.movimenti ?? const [];

  /// "Segna come pagato" (o "consegnata" per la scheda sanitaria). Se la quota ha un
  /// importo, il pagamento viene registrato anche come entrata nel Bilancio; se
  /// l'importo non si conosce ancora, lo si chiede e lo si ricorda.
  Future<void> _segnaPagato(Lupetto l) async {
    final c = l.censimento!;
    if (!await controllaOnline(context, ref) || !mounted) return;
    if (_sanitaria) {
      final ok = await chiediConferma(context, l.nome, 'Segnare la scheda sanitaria come consegnata?');
      if (!ok || !mounted) return;
      await _scrivi(l, [_campoStato(c, true)]);
      return;
    }
    final data = await chiediData(context, '${_voce.etichetta}: pagato il', DateTime.now());
    if (data == null || !mounted) return;
    var importo = _quote.importoDi(_voce.etichetta);
    var nuovoImporto = false;
    if (importo == null) {
      final txt = await chiediImporto(
        context,
        '${_voce.etichetta}: quanto costa?',
        'Scrivi la quota di un lupetto: verrà registrata come entrata nel Bilancio e ricordata per i prossimi pagamenti.',
        consentiSalta: true,
      );
      if (txt == null || !mounted) return;
      if (txt.isNotEmpty) {
        importo = cellNumber(txt);
        nuovoImporto = true;
      }
    }
    final voce = _voce.etichetta;
    final quota = importo;
    await eseguiModifica(context, ref, (forza) async {
      final w = ref.read(scritturaProvider);
      if (nuovoImporto) await w.impostaImportoQuota(voce, quota!);
      await w.scriviCampi(
        tab: ref.read(profiloProvider).tabCensimenti,
        nomeNelTab: c.nome,
        campi: [_campoStato(c, 'pagato'), ?_campoData(c, data)],
        forza: forza,
      );
      if (quota == null) return null;
      final avviso = await w.aggiungiMovimento(movimentoIncasso(voce, l.nome, quota, data));
      return avviso ?? 'Pagato. Registrati ${euro(quota)} come entrata nel Bilancio.';
    });
  }

  Future<void> _cambiaData(Lupetto l) async {
    final c = l.censimento!;
    if (!await controllaOnline(context, ref) || !mounted) return;
    final data = await chiediData(
      context,
      '${_voce.etichetta}: data del pagamento',
      dataVoce(c, _voce) ?? DateTime.now(),
    );
    if (data == null || !mounted) return;
    await _scrivi(l, [?_campoData(c, data)]);
  }

  /// Per correggere un errore: torna a "non pagato" e cancella la data. Se il pagamento
  /// era stato registrato nel Bilancio, si aggiunge uno storno dello stesso importo.
  Future<void> _annulla(Lupetto l) async {
    final c = l.censimento!;
    if (!await controllaOnline(context, ref) || !mounted) return;
    final voce = _voce.etichetta;
    final storno = _sanitaria ? null : daStornare(_movimenti, voce, l.nome);
    final ok = await chiediConferma(
      context,
      l.nome,
      _sanitaria
          ? 'Segnare la scheda sanitaria come NON consegnata?'
          : '$voce: segnare come NON pagato? La data del pagamento verrà cancellata.'
                '${storno == null ? '' : ' Nel Bilancio verrà registrato uno storno di ${euro(storno)}.'}',
    );
    if (!ok || !mounted) return;
    if (_sanitaria) {
      await _scrivi(l, [_campoStato(c, false)]);
      return;
    }
    await eseguiModifica(context, ref, (forza) async {
      final w = ref.read(scritturaProvider);
      await w.scriviCampi(
        tab: ref.read(profiloProvider).tabCensimenti,
        nomeNelTab: c.nome,
        campi: [_campoStato(c, 'non pagato'), if (dataVoce(c, _voce) != null) ?_campoData(c, '')],
        forza: forza,
      );
      if (storno == null) return null;
      final avviso = await w.aggiungiMovimento(movimentoStorno(voce, l.nome, storno, DateTime.now()));
      return avviso ?? 'Annullato. Nel Bilancio è stato registrato uno storno di ${euro(storno)}.';
    });
  }

  /// Per chi risultava "non dovuto" ma deve pagare.
  Future<void> _segnaDaPagare(Lupetto l) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    await _scrivi(l, [_campoStato(l.censimento!, _sanitaria ? false : 'non pagato')]);
  }

  Future<void> _opzioni(Lupetto l) async {
    final c = l.censimento!;
    final stato = statoVoce(c, _voce);
    final azione = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l.nome, style: Theme.of(ctx).textTheme.titleLarge),
              subtitle: Text(
                '${_voce.etichetta}: ${switch (stato) {
                  StatoVoce.pagato => _siTesto.toLowerCase(),
                  StatoVoce.daPagare => _noTesto.toLowerCase(),
                  StatoVoce.nonDovuto => 'non dovuta',
                }}',
              ),
            ),
            if (stato != StatoVoce.pagato)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(
                  stato == StatoVoce.nonDovuto
                      ? 'Segna come ${_sanitaria ? 'da consegnare' : 'da pagare'}'
                      : (_sanitaria ? 'Segna come consegnata' : 'Segna come pagato'),
                ),
                onTap: () => Navigator.pop(ctx, stato == StatoVoce.nonDovuto ? 'dovuta' : 'pagato'),
              ),
            if (stato == StatoVoce.pagato && !_sanitaria)
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Cambia la data del pagamento'),
                onTap: () => Navigator.pop(ctx, 'data'),
              ),
            if (stato == StatoVoce.pagato)
              ListTile(
                leading: Icon(Icons.undo, color: Theme.of(ctx).colorScheme.error),
                title: Text(_sanitaria ? 'Ho sbagliato: non consegnata' : 'Ho sbagliato: NON ha pagato'),
                onTap: () => Navigator.pop(ctx, 'annulla'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (azione == null || !mounted) return;
    switch (azione) {
      case 'pagato':
        await _segnaPagato(l);
      case 'data':
        await _cambiaData(l);
      case 'annulla':
        await _annulla(l);
      case 'dovuta':
        await _segnaDaPagare(l);
    }
  }

  // --- interfaccia ----------------------------------------------------------

  String _dettaglio(Lupetto l) {
    final c = l.censimento!;
    final d = dataVoce(c, _voce);
    return switch (statoVoce(c, _voce)) {
      StatoVoce.pagato => d == null ? _siTesto : '$_siTesto il ${dataIt(d)}',
      StatoVoce.daPagare => _noTesto,
      StatoVoce.nonDovuto => _sanitaria ? 'Non richiesta' : 'Non dovuta',
    };
  }

  // --- quote fisse: importo ---------------------------------------------------

  Future<void> _impostaImporto() async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final voce = _voce.etichetta;
    final txt = await chiediImporto(
      context,
      '$voce: importo',
      'Quanto paga ogni lupetto? Vale per i prossimi pagamenti (quelli già registrati nel Bilancio non cambiano).',
      iniziale: _quote.importoDi(voce),
    );
    if (txt == null || !mounted) return;
    final v = cellNumber(txt)!;
    await eseguiModifica(context, ref, (_) async {
      await ref.read(scritturaProvider).impostaImportoQuota(voce, v);
      return 'Importo salvato: ${euro(v)}.';
    });
  }

  // --- quote extra ---------------------------------------------------------------

  Future<void> _nuovaQuota() async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final nome = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const NuovaQuotaPage()));
    if (nome != null && mounted) setState(() => _extra = nome);
  }

  Future<void> _segnaPagatoExtra(QuotaExtraRiga r) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final data = await chiediData(context, '${r.quota}: pagato il', DateTime.now());
    if (data == null || !mounted) return;
    await eseguiModifica(context, ref, (forza) async {
      final w = ref.read(scritturaProvider);
      await w.segnaQuotaExtra(quota: r.quota, lupetto: r.lupetto, data: data, attesaPagata: false, forza: forza);
      final imp = r.importo;
      if (imp == null || imp <= 0) return null;
      final avviso = await w.aggiungiMovimento(movimentoIncasso(r.quota, r.lupetto, imp, data));
      return avviso ?? 'Pagato. Registrati ${euro(imp)} come entrata nel Bilancio.';
    });
  }

  Future<void> _cambiaDataExtra(QuotaExtraRiga r) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final data = await chiediData(context, '${r.quota}: data del pagamento', r.pagatoIl ?? DateTime.now());
    if (data == null || !mounted) return;
    await eseguiModifica(context, ref, (forza) async {
      await ref
          .read(scritturaProvider)
          .segnaQuotaExtra(quota: r.quota, lupetto: r.lupetto, data: data, attesaPagata: true, forza: forza);
      return null;
    });
  }

  Future<void> _annullaExtra(QuotaExtraRiga r) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final storno = daStornare(_movimenti, r.quota, r.lupetto);
    final ok = await chiediConferma(
      context,
      r.lupetto,
      '${r.quota}: segnare come NON pagato? La data verrà cancellata.'
      '${storno == null ? '' : ' Nel Bilancio verrà registrato uno storno di ${euro(storno)}.'}',
    );
    if (!ok || !mounted) return;
    await eseguiModifica(context, ref, (forza) async {
      final w = ref.read(scritturaProvider);
      await w.segnaQuotaExtra(quota: r.quota, lupetto: r.lupetto, data: null, attesaPagata: true, forza: forza);
      if (storno == null) return null;
      final avviso = await w.aggiungiMovimento(movimentoStorno(r.quota, r.lupetto, storno, DateTime.now()));
      return avviso ?? 'Annullato. Nel Bilancio è stato registrato uno storno di ${euro(storno)}.';
    });
  }

  Future<void> _eliminaQuota(String quota) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final ok = await chiediConferma(
      context,
      'Eliminare "$quota"?',
      'Spariscono dal foglio tutte le righe di questa quota. Si può fare solo se nessuno ha ancora pagato.',
    );
    if (!ok || !mounted) return;
    final fatto = await eseguiModifica(context, ref, (_) async {
      await ref.read(scritturaProvider).eliminaQuotaExtra(quota);
      return 'Quota eliminata.';
    });
    if (fatto && mounted) setState(() => _extra = null);
  }

  Future<void> _opzioniExtra(QuotaExtraRiga r) async {
    final azione = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(r.lupetto, style: Theme.of(ctx).textTheme.titleLarge),
              subtitle: Text('${r.quota}: ${r.pagata ? 'pagato' : 'da pagare'}'),
            ),
            if (!r.pagata)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Segna come pagato'),
                onTap: () => Navigator.pop(ctx, 'pagato'),
              ),
            if (r.pagata)
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Cambia la data del pagamento'),
                onTap: () => Navigator.pop(ctx, 'data'),
              ),
            if (r.pagata)
              ListTile(
                leading: Icon(Icons.undo, color: Theme.of(ctx).colorScheme.error),
                title: const Text('Ho sbagliato: NON ha pagato'),
                onTap: () => Navigator.pop(ctx, 'annulla'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (azione == null || !mounted) return;
    switch (azione) {
      case 'pagato':
        await _segnaPagatoExtra(r);
      case 'data':
        await _cambiaDataExtra(r);
      case 'annulla':
        await _annullaExtra(r);
    }
  }

  // --- interfaccia ----------------------------------------------------------

  /// Carta con avanzamento: "N su M in regola", barra e (se noto) incassato.
  Widget _riepilogo({
    required String titolo,
    required int pagati,
    required int daPagare,
    required String etichettaMancano,
    String? importoTesto,
    Widget? azione,
  }) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final totale = pagati + daPagare;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(titolo, style: t.titleMedium)),
                if (daPagare > 0)
                  Text(
                    '$daPagare $etichettaMancano',
                    style: t.labelLarge?.copyWith(color: s.error, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            if (totale > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pagati / totale,
                  minHeight: 10,
                  backgroundColor: s.errorContainer,
                  color: s.primary,
                ),
              ),
            ],
            if (importoTesto != null || azione != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (importoTesto != null) Expanded(child: Text(importoTesto, style: t.bodyMedium)),
                  ?azione,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filtri() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: SegmentedButton<FiltroQuota>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: FiltroQuota.daPagare, label: Text(_sanitaria ? 'Mancanti' : 'Da pagare')),
        ButtonSegment(value: FiltroQuota.pagati, label: Text(_sanitaria ? 'Consegnate' : 'Pagati')),
        const ButtonSegment(value: FiltroQuota.tutti, label: Text('Tutti')),
      ],
      selected: {_filtro},
      onSelectionChanged: (v) => setState(() => _filtro = v.first),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tutti = ref.watch(lupettiProvider);
    final quote = ref.watch(datiProvider).value?.data.quote ?? const QuoteTab();
    final s = Theme.of(context).colorScheme;
    final extra = _extra != null && quote.nomiExtra.any((n) => n.toLowerCase() == _extra!.toLowerCase())
        ? quote.nomiExtra.firstWhere((n) => n.toLowerCase() == _extra!.toLowerCase())
        : null;

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final v in VoceQuota.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${v.etichetta} (${conteggi(tutti, v).daPagare})'),
                selected: extra == null && _voce == v,
                onSelected: (_) => setState(() {
                  _voce = v;
                  _extra = null;
                }),
              ),
            ),
          for (final n in quote.nomiExtra)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text('$n (${conteggiExtra(quote.di(n)).daPagare})'),
                selected: extra == n,
                onSelected: (_) => setState(() => _extra = n),
              ),
            ),
          ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Nuova quota'), onPressed: _nuovaQuota),
        ],
      ),
    );

    if (extra != null) {
      final righe = quote.di(extra);
      final n = conteggiExtra(righe);
      final imp = righe.map((r) => r.importo).whereType<double>().fold<double?>(null, (a, b) => b);
      final elenco = [
        for (final r in righe)
          if (switch (_filtro) {
            FiltroQuota.daPagare => !r.pagata,
            FiltroQuota.pagati => r.pagata,
            FiltroQuota.tutti => true,
          })
            r,
      ]..sort((a, b) => a.lupetto.toLowerCase().compareTo(b.lupetto.toLowerCase()));
      final incassato = righe.where((r) => r.pagata).fold<double>(0, (a, r) => a + (r.importo ?? 0));
      return ListaRefresh(
        children: [
          chips,
          _riepilogo(
            titolo: '${n.pagati} su ${righe.length} hanno pagato',
            pagati: n.pagati,
            daPagare: n.daPagare,
            etichettaMancano: 'da pagare',
            importoTesto: imp == null
                ? null
                : 'Quota ${euro(imp)} a testa · incassati ${euro(incassato)} su ${euro(righe.fold<double>(0, (a, r) => a + (r.importo ?? 0)))}',
            azione: PopupMenuButton<String>(
              tooltip: 'Altre azioni',
              onSelected: (_) => _eliminaQuota(extra),
              itemBuilder: (_) => const [PopupMenuItem(value: 'elimina', child: Text('Elimina questa quota'))],
            ),
          ),
          _filtri(),
          if (elenco.isEmpty)
            StatoVuoto(_filtro == FiltroQuota.daPagare ? 'Tutti hanno pagato' : 'Nessun lupetto in questo elenco')
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < elenco.length; i++) ...[
                    if (i > 0) const Divider(indent: 72),
                    _rigaExtra(elenco[i], s),
                  ],
                ],
              ),
            ),
        ],
      );
    }

    final elenco = perVoce(tutti, _voce, _filtro);
    final n = conteggi(tutti, _voce);
    final totale = n.pagati + n.daPagare;
    final importo = _sanitaria ? null : quote.importoDi(_voce.etichetta);
    return ListaRefresh(
      children: [
        chips,
        _riepilogo(
          titolo: totale == 0
              ? '${_voce.etichetta}: nessuno interessato'
              : '${n.pagati} su $totale ${_sanitaria ? 'consegnate' : 'in regola'}',
          pagati: n.pagati,
          daPagare: n.daPagare,
          etichettaMancano: _sanitaria ? 'mancano' : 'da pagare',
          importoTesto: _sanitaria
              ? null
              : importo == null
              ? 'Importo non impostato: te lo chiedo al primo pagamento.'
              : 'Quota ${euro(importo)} a testa · incassati ${euro(importo * n.pagati)}',
          azione: _sanitaria
              ? null
              : TextButton(onPressed: _impostaImporto, child: Text(importo == null ? 'Imposta' : 'Cambia')),
        ),
        _filtri(),
        if (elenco.isEmpty)
          StatoVuoto(
            _filtro == FiltroQuota.daPagare ? 'Tutto a posto' : 'Nessun lupetto in questo elenco',
            dettaglio: _filtro == FiltroQuota.daPagare ? 'Nessuno da sollecitare per questa voce.' : null,
          )
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < elenco.length; i++) ...[if (i > 0) const Divider(indent: 72), _riga(elenco[i], s)],
              ],
            ),
          ),
      ],
    );
  }

  Widget _rigaExtra(QuotaExtraRiga r, ColorScheme s) {
    return ListTile(
      onTap: () => _opzioniExtra(r),
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: CircleAvatar(
        backgroundColor: r.pagata ? s.primaryContainer : s.errorContainer,
        child: Icon(
          r.pagata ? Icons.check_rounded : Icons.hourglass_bottom_rounded,
          color: r.pagata ? s.onPrimaryContainer : s.onErrorContainer,
        ),
      ),
      title: Text(r.lupetto, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        r.pagata ? 'Pagato il ${dataIt(r.pagatoIl)}' : 'Da pagare',
        style: TextStyle(fontWeight: FontWeight.w700, color: r.pagata ? s.primary : s.error),
      ),
      trailing: r.pagata
          ? IconButton(tooltip: 'Modifica', icon: const Icon(Icons.edit_outlined), onPressed: () => _opzioniExtra(r))
          : FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _segnaPagatoExtra(r),
              child: const Text('Pagato'),
            ),
    );
  }

  Widget _riga(Lupetto l, ColorScheme s) {
    final stato = statoVoce(l.censimento!, _voce);
    final (sfondo, icona, colore) = switch (stato) {
      StatoVoce.pagato => (s.primaryContainer, Icons.check_rounded, s.onPrimaryContainer),
      StatoVoce.daPagare => (s.errorContainer, Icons.hourglass_bottom_rounded, s.onErrorContainer),
      StatoVoce.nonDovuto => (s.surfaceContainerHigh, Icons.remove_rounded, s.onSurfaceVariant),
    };
    final extra = [
      if (l.annoNumero != null) '${l.annoNumero}° anno',
      if (l.censimento!.note != null) l.censimento!.note!,
    ].join(' · ');
    return ListTile(
      onTap: () => _opzioni(l),
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: CircleAvatar(
        backgroundColor: sfondo,
        child: Icon(icona, color: colore, semanticLabel: _dettaglio(l)),
      ),
      title: Text(l.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dettaglio(l),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: switch (stato) {
                StatoVoce.pagato => s.primary,
                StatoVoce.daPagare => s.error,
                StatoVoce.nonDovuto => s.onSurfaceVariant,
              },
            ),
          ),
          if (extra.isNotEmpty) Text(extra),
        ],
      ),
      trailing: stato == StatoVoce.daPagare
          ? FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _segnaPagato(l),
              child: Text(_sanitaria ? 'Consegnata' : 'Pagato'),
            )
          : IconButton(tooltip: 'Modifica', icon: const Icon(Icons.edit_outlined), onPressed: () => _opzioni(l)),
    );
  }
}
