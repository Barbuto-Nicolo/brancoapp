import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/write_service.dart';
import '../../models/models.dart';
import '../common/format.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import 'censimenti_logic.dart';

class CensimentiScreen extends ConsumerStatefulWidget {
  const CensimentiScreen({super.key});
  @override
  ConsumerState<CensimentiScreen> createState() => _CensimentiScreenState();
}

class _CensimentiScreenState extends ConsumerState<CensimentiScreen> {
  VoceQuota _voce = VoceQuota.censimento;
  FiltroQuota _filtro = FiltroQuota.daPagare;

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
        VoceQuota.sanFra =>
          Campo(etichetta: 'Data SanFra', header: 'Quota SanFra', offset: 1, atteso: c.dataSanFra, nuovo: nuovo),
        VoceQuota.vdb => Campo(etichetta: 'Data VdB', header: 'Quota VdB', offset: 1, atteso: c.dataVdB, nuovo: nuovo),
        VoceQuota.sanitaria => null,
      };

  Future<void> _scrivi(Lupetto l, List<Campo> campi) => scriviCampiLupetto(context, ref,
      tab: ref.read(profiloProvider).tabCensimenti, nomeNelTab: l.censimento!.nome, campi: campi);

  // --- azioni ---------------------------------------------------------------

  /// "Segna come pagato" (o "consegnata" per la scheda sanitaria).
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
    await _scrivi(l, [_campoStato(c, 'pagato'), ?_campoData(c, data)]);
  }

  Future<void> _cambiaData(Lupetto l) async {
    final c = l.censimento!;
    if (!await controllaOnline(context, ref) || !mounted) return;
    final data = await chiediData(context, '${_voce.etichetta}: data del pagamento', dataVoce(c, _voce) ?? DateTime.now());
    if (data == null || !mounted) return;
    await _scrivi(l, [?_campoData(c, data)]);
  }

  /// Per correggere un errore: torna a "non pagato" e cancella la data.
  Future<void> _annulla(Lupetto l) async {
    final c = l.censimento!;
    if (!await controllaOnline(context, ref) || !mounted) return;
    final ok = await chiediConferma(
      context,
      l.nome,
      _sanitaria
          ? 'Segnare la scheda sanitaria come NON consegnata?'
          : '${_voce.etichetta}: segnare come NON pagato? La data del pagamento verrà cancellata.',
    );
    if (!ok || !mounted) return;
    if (_sanitaria) {
      await _scrivi(l, [_campoStato(c, false)]);
    } else {
      await _scrivi(l, [_campoStato(c, 'non pagato'), if (dataVoce(c, _voce) != null) ?_campoData(c, '')]);
    }
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(l.nome, style: Theme.of(ctx).textTheme.titleLarge),
            subtitle: Text('${_voce.etichetta}: ${switch (stato) {
              StatoVoce.pagato => _siTesto.toLowerCase(),
              StatoVoce.daPagare => _noTesto.toLowerCase(),
              StatoVoce.nonDovuto => 'non dovuta',
            }}'),
          ),
          if (stato != StatoVoce.pagato)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(stato == StatoVoce.nonDovuto
                  ? 'Segna come ${_sanitaria ? 'da consegnare' : 'da pagare'}'
                  : (_sanitaria ? 'Segna come consegnata' : 'Segna come pagato')),
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
        ]),
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

  @override
  Widget build(BuildContext context) {
    final tutti = ref.watch(lupettiProvider);
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final elenco = perVoce(tutti, _voce, _filtro);
    final n = conteggi(tutti, _voce);
    final totale = n.pagati + n.daPagare;

    return ListaRefresh(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          for (final v in VoceQuota.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${v.etichetta} (${conteggi(tutti, v).daPagare})'),
                selected: _voce == v,
                onSelected: (_) => setState(() => _voce = v),
              ),
            ),
        ]),
      ),
      // Riepilogo: quanti hanno già sistemato la voce.
      Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  totale == 0
                      ? '${_voce.etichetta}: nessuno interessato'
                      : '${n.pagati} su $totale ${_sanitaria ? 'consegnate' : 'in regola'}',
                  style: t.titleMedium,
                ),
              ),
              if (n.daPagare > 0)
                Text('${n.daPagare} ${_sanitaria ? 'mancano' : 'da pagare'}',
                    style: t.labelLarge?.copyWith(color: s.error, fontWeight: FontWeight.w800)),
            ]),
            if (totale > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: n.pagati / totale,
                  minHeight: 10,
                  backgroundColor: s.errorContainer,
                  color: s.primary,
                ),
              ),
            ],
          ]),
        ),
      ),
      Padding(
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
      ),
      if (elenco.isEmpty)
        StatoVuoto(
          _filtro == FiltroQuota.daPagare ? 'Tutto a posto' : 'Nessun lupetto in questo elenco',
          dettaglio: _filtro == FiltroQuota.daPagare ? 'Nessuno da sollecitare per questa voce.' : null,
        )
      else
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < elenco.length; i++) ...[
              if (i > 0) const Divider(indent: 72),
              _riga(elenco[i], s),
            ],
          ]),
        ),
    ]);
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
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      ]),
      trailing: stato == StatoVoce.daPagare
          ? FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _segnaPagato(l),
              child: Text(_sanitaria ? 'Consegnata' : 'Pagato'),
            )
          : IconButton(
              tooltip: 'Modifica',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _opzioni(l),
            ),
    );
  }
}
