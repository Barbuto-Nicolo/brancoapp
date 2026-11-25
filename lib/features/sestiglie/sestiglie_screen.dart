import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/write_service.dart';
import '../../models/models.dart';
import '../common/colori_sestiglie.dart';
import '../common/scout_art.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import '../lupetti/lupetto_detail_screen.dart';
import 'nuovo_lupetto_page.dart';
import 'sestiglie_logic.dart';

class SestiglieScreen extends ConsumerStatefulWidget {
  const SestiglieScreen({super.key});
  @override
  ConsumerState<SestiglieScreen> createState() => _SestiglieScreenState();
}

class _SestiglieScreenState extends ConsumerState<SestiglieScreen> {
  int? _anno; // null = anno di default (ultima colonna con dati)

  Future<void> _sposta(Lupetto l, int anno, List<String> tutteLeSestiglie) async {
    final attuale = l.sestiglie!.perAnno[anno];
    if (!await controllaOnline(context, ref) || !mounted) return;
    final nuova = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('Sposta ${l.nome}', style: Theme.of(ctx).textTheme.titleLarge),
              subtitle: Text('Sestiglie $anno'),
            ),
            for (final s in tutteLeSestiglie)
              ListTile(
                leading: Fazzolettone(colore: coloreSestiglia(s), size: 34),
                title: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: s == attuale ? const Icon(Icons.check_circle) : null,
                enabled: s != attuale,
                onTap: () => Navigator.pop(ctx, s),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (nuova == null || !mounted) return;
    await scriviCampiLupetto(context, ref,
        tab: ref.read(profiloProvider).tabSestiglie,
        nomeNelTab: l.sestiglie!.nome,
        campi: [Campo(etichetta: 'Sestiglia $anno', header: '$anno', atteso: attuale, nuovo: nuova)]);
  }

  Future<void> _nuovo(int anno, List<String> nomi) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NuovoLupettoPage(anno: anno, sestiglie: nomi)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dati = ref.watch(datiProvider).value;
    if (dati == null) return const SizedBox.shrink();
    final anni = dati.data.sestiglie.anni;
    final anno = _anno ?? dati.data.sestiglie.annoDefault;
    if (anno == null) {
      return const ListaRefresh(children: [StatoVuoto('Nessun dato sulle sestiglie.')]);
    }
    final gruppi = gruppiSestiglie(dati.lupetti, anno);
    final nomi = ({
      for (final r in dati.data.sestiglie.righe)
        for (final v in r.perAnno.values) ?v,
    }.toList()
      ..sort());
    final nomiAnno = [for (final g in gruppi) g.nome];
    final totale = gruppi.fold<int>(0, (a, g) => a + g.membri.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nuovo(anno, nomiAnno.isEmpty ? nomi : nomiAnno),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuovo lupetto'),
      ),
      body: ListaRefresh(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final a in anni) ButtonSegment(value: a, label: Text('$a'))],
            selected: {anno},
            onSelectionChanged: (s) => setState(() => _anno = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            '$totale lupetti in ${gruppi.length} sestiglie',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        if (gruppi.isEmpty)
          StatoVuoto('Nessuna sestiglia nel $anno', dettaglio: 'Aggiungi il primo lupetto con il pulsante giallo.'),
        for (final g in gruppi)
          _SestigliaCard(
            gruppo: g,
            onSposta: (l) => _sposta(l, anno, nomi),
            onApri: (l) => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => LupettoDetailScreen(chiave: l.chiave)),
            ),
          ),
      ]),
    );
  }
}

class _SestigliaCard extends StatelessWidget {
  const _SestigliaCard({required this.gruppo, required this.onSposta, required this.onApri});
  final GruppoSestiglia gruppo;
  final void Function(Lupetto) onSposta;
  final void Function(Lupetto) onApri;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final colore = coloreSestiglia(gruppo.nome);
    final su = testoSu(colore);

    Widget conteggio(String etichetta, int n) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: n > 0 ? s.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: s.outlineVariant),
          ),
          child: Text(
            '$etichetta  $n',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: n > 0 ? s.onSurface : s.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: colore, width: 7))),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Fazzolettone(colore: colore, size: 46),
            title: Text(gruppo.nome, style: t.titleLarge),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in gruppo.perAnnoCammino.entries) conteggio('${e.key}°', e.value),
                if (gruppo.senzaAnno > 0) conteggio('n/d', gruppo.senzaAnno),
              ]),
            ),
            trailing: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colore, shape: BoxShape.circle, border: Border.all(color: s.outlineVariant)),
              child: Text('${gruppo.membri.length}', style: TextStyle(color: su, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            children: [
              for (final m in gruppo.membri)
                ListTile(
                  onTap: () => onApri(m),
                  contentPadding: const EdgeInsets.only(left: 16, right: 4),
                  leading: AvatarIniziali(m.nome, colore: colore, testo: su, size: 38),
                  title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: m.annoNumero == null ? null : Text('${m.annoNumero}° anno'),
                  trailing: IconButton(
                    tooltip: 'Sposta in un\'altra sestiglia',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => onSposta(m),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
