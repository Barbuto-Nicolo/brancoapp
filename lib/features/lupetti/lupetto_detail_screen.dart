import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../common/format.dart';
import '../common/modifica_campi_page.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import '../prede/prede_widgets.dart';
import '../common/colori_sestiglie.dart';
import '../common/scout_art.dart';
import 'contatti.dart';

/// Scheda di dettaglio: unisce i dati di tutti i tab (sola lettura in Fase 2).
class LupettoDetailScreen extends ConsumerWidget {
  const LupettoDetailScreen({super.key, required this.chiave});
  final String chiave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(lupettiProvider).where((x) => x.chiave == chiave).firstOrNull;
    if (l == null) {
      return Scaffold(appBar: AppBar(), body: const StatoVuoto('Lupetto non trovato. Torna indietro e aggiorna.'));
    }
    final annoSest = ref.watch(datiProvider).value?.data.sestiglie.annoDefault;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.nome),
        actions: [
          if (l.dati != null)
            IconButton(
              tooltip: 'Modifica dati e recapiti',
              icon: const Icon(Icons.edit),
              onPressed: () => _modifica(context, ref, l.dati!),
            ),
          PopupMenuButton<String>(
            tooltip: 'Altre azioni',
            onSelected: (v) {
              if (v == 'elimina') _elimina(context, ref, l);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'elimina',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Elimina lupetto', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Testata(l, annoSest),
          _Sezione('Dati anagrafici', l.dati == null ? null : _anagrafica(l.dati!), 'Dati e recapiti'),
          if (l.dati != null) ...[
            _genitore(context, 'Madre', l.dati!.madre),
            _genitore(context, 'Padre', l.dati!.padre),
          ],
          _Sezione('Censimento e quote', l.censimento == null ? null : _quote(l.censimento!), 'Censimenti e quote'),
          _Sezione('Prede e specialità', l.prede == null ? null : PredeContenuto(l.prede!), 'Prede e specialità'),
          _Sezione('Sestiglie', l.sestiglie == null ? null : _sestiglie(l.sestiglie!, annoSest), 'Sestiglie'),
        ],
      ),
    );
  }

  /// Elimina le righe del lupetto da tutti i tab in cui compare (non il Bilancio).
  Future<void> _elimina(BuildContext context, WidgetRef ref, Lupetto l) async {
    if (!await controllaOnline(context, ref) || !context.mounted) return;
    final p = ref.read(profiloProvider);
    final nomi = <String, String>{
      if (l.dati != null) p.tabDati: l.dati!.nome,
      if (l.sestiglie != null) p.tabSestiglie: l.sestiglie!.nome,
      if (l.censimento != null) p.tabCensimenti: l.censimento!.nome,
      if (l.prede != null) p.tabPrede: l.prede!.nome,
    };
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: s.error, size: 32),
          title: Text('Eliminare ${l.nome}?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('La sua riga verrà cancellata dal foglio, in questi tab:'),
                const SizedBox(height: 8),
                for (final t in nomi.keys) Text('• $t', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text(
                  'Le spese nel Bilancio non cambiano. Dall\'app non si può annullare: '
                  'nel foglio puoi tornare indietro da File → Cronologia versioni.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: s.error, foregroundColor: s.onError),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (conferma != true || !context.mounted) return;
    final ok = await eseguiModifica(context, ref, (_) async {
      final e = await ref.read(scritturaProvider).eliminaLupetto(nomi);
      if (e.saltati.isEmpty) return '${l.nome} eliminato dal foglio.';
      final saltati = e.saltati.entries.map((x) => '${x.key} (${x.value})').join(', ');
      return '${l.nome} eliminato, ma non in: $saltati.';
    }, conflittoSovrascrivibile: false);
    if (ok && context.mounted) Navigator.pop(context);
  }

  Future<void> _modifica(BuildContext context, WidgetRef ref, DatiRecapiti d) async {
    if (!await controllaOnline(context, ref) || !context.mounted) return;
    CampoForm t(String e, String h, Object? v, {int off = 0, String? sez, TipoCampo tipo = TipoCampo.testo}) =>
        CampoForm(etichetta: e, header: h, offset: off, tipo: tipo, iniziale: v, sezione: sez);
    final campi = [
      t('Anno di cammino (es. 3° anno)', 'Anno', d.anno, sez: 'Anagrafica'),
      t('Codice censimento', 'Cod. Cens.', d.codCens, tipo: TipoCampo.numerico, sez: 'Anagrafica'),
      t('Nato/a a', 'Nato/a a', d.natoA, sez: 'Anagrafica'),
      t('Data di nascita', 'il', d.dataNascita, tipo: TipoCampo.data, sez: 'Anagrafica'),
      t('Codice fiscale', 'C.F.', d.codiceFiscale, sez: 'Anagrafica'),
      t('Residenza', 'Residenza', d.residenza, sez: 'Anagrafica'),
      t('Nome', 'Madre', d.madre?.nome, sez: 'Madre'),
      t('Telefono', 'Madre', d.madre?.telefono, off: 1, tipo: TipoCampo.numerico, sez: 'Madre'),
      t('Email', 'Madre', d.madre?.email, off: 2, sez: 'Madre'),
      t('Nome', 'Padre', d.padre?.nome, sez: 'Padre'),
      t('Telefono', 'Padre', d.padre?.telefono, off: 1, tipo: TipoCampo.numerico, sez: 'Padre'),
      t('Email', 'Padre', d.padre?.email, off: 2, sez: 'Padre'),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ModificaCampiPage(titolo: d.nome, tab: ref.read(profiloProvider).tabDati, nomeNelTab: d.nome, campi: campi),
      ),
    );
  }

  Widget _anagrafica(DatiRecapiti d) => Column(
    children: [
      CampoRiga('Anno di cammino', d.anno),
      CampoRiga('Codice censimento', d.codCens),
      CampoRiga('Nato/a a', d.natoA),
      CampoRiga('Data di nascita', dataIt(d.dataNascita)),
      CampoRiga('Codice fiscale', d.codiceFiscale),
      CampoRiga('Residenza', d.residenza),
    ],
  );

  Widget _genitore(BuildContext context, String ruolo, Genitore? g) {
    if (g == null) return const SizedBox.shrink();
    return _Sezione(
      ruolo,
      Column(
        children: [
          CampoRiga('Nome', g.nome),
          CampoRiga(
            'Telefono',
            g.telefono,
            icona: Icons.call,
            onTap: g.telefono == null ? null : () => mostraAzioniTelefono(context, g.nome ?? ruolo, g.telefono!),
          ),
          CampoRiga(
            'Email',
            g.email,
            icona: Icons.mail_outline,
            onTap: g.email == null ? null : () => scriviMail(context, g.email!),
          ),
        ],
      ),
      ruolo,
    );
  }

  Widget _quote(Censimento c) => Column(
    children: [
      CampoRiga('Dati censimento', c.datiCens),
      CampoRiga('Scheda sanitaria', c.sanitaria == null ? null : (c.sanitaria! ? 'Consegnata' : 'Non consegnata')),
      CampoRiga(
        'Censimento',
        [c.censimento, if (c.dataCensimento != null) dataIt(c.dataCensimento)].whereType<String>().join(' · '),
      ),
      CampoRiga(
        'Quota SanFra',
        [c.quotaSanFra, if (c.dataSanFra != null) dataIt(c.dataSanFra)].whereType<String>().join(' · '),
      ),
      CampoRiga('Quota VdB', [c.quotaVdB, if (c.dataVdB != null) dataIt(c.dataVdB)].whereType<String>().join(' · ')),
      CampoRiga('Note', c.note),
    ],
  );

  Widget _sestiglie(SestigliaRiga s, int? annoDefault) => Column(
    children: [
      for (final e in s.perAnno.entries) CampoRiga(e.key == annoDefault ? '${e.key} (attuale)' : '${e.key}', e.value),
    ],
  );
}

class _Testata extends StatelessWidget {
  const _Testata(this.l, this.annoSest);
  final Lupetto l;
  final int? annoSest;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final sest = l.sestiglie?.perAnno[annoSest];
    final colore = sest == null ? s.primaryContainer : coloreSestiglia(sest);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          AvatarIniziali(
            l.nome,
            colore: colore,
            testo: sest == null ? s.onPrimaryContainer : testoSu(colore),
            size: 68,
            macchie: sest != null && haMacchie(sest),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.nome, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (l.annoNumero != null)
                      Chip(visualDensity: VisualDensity.compact, label: Text('${l.annoNumero}° anno')),
                    if (sest != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: CircleAvatar(backgroundColor: colore, radius: 8),
                        label: Text(sest),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sezione extends StatelessWidget {
  const _Sezione(this.titolo, this.contenuto, this.tab);
  final String titolo;
  final Widget? contenuto;
  final String tab;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                titolo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            contenuto ??
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('Non presente nel tab "$tab" (nome diverso o assente).'),
                ),
          ],
        ),
      ),
    );
  }
}
