import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/colori_sestiglie.dart';
import '../common/scout_art.dart';
import '../../models/models.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import '../sestiglie/nuovo_lupetto_page.dart';
import 'lupetti_logic.dart';
import 'lupetto_detail_screen.dart';

class LupettiScreen extends ConsumerStatefulWidget {
  const LupettiScreen({super.key});
  @override
  ConsumerState<LupettiScreen> createState() => _LupettiScreenState();
}

class _LupettiScreenState extends ConsumerState<LupettiScreen> {
  String _query = '';
  int? _anno;
  String? _sestiglia;

  @override
  Widget build(BuildContext context) {
    final dati = ref.watch(datiProvider).value;
    if (dati == null) return const SizedBox.shrink();
    final tutti = dati.lupetti;
    final annoSest = dati.data.sestiglie.annoDefault;
    final elenco = filtraLupetti(tutti,
        query: _query, anno: _anno, sestiglia: _sestiglia, annoSestiglia: annoSest);

    final s = Theme.of(context).colorScheme;
    final nomiAnno = nomiSestiglie(tutti, annoSest);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: annoSest == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (!await controllaOnline(context, ref) || !context.mounted) return;
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => NuovoLupettoPage(anno: annoSest, sestiglie: nomiAnno),
                ));
              },
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Nuovo lupetto'),
            ),
      body: ListaRefresh(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SearchBar(
          hintText: 'Cerca lupetto',
          leading: const Icon(Icons.search),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          for (final a in anniCammino(tutti))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('$a° anno'),
                selected: _anno == a,
                onSelected: (s) => setState(() => _anno = s ? a : null),
              ),
            ),
          for (final s in nomiSestiglie(tutti, annoSest))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(s),
                selected: _sestiglia == s,
                onSelected: (v) => setState(() => _sestiglia = v ? s : null),
              ),
            ),
        ]),
      ),
      if (annoSest != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Sestiglie $annoSest · ${elenco.length} lupetti',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: s.onSurfaceVariant)),
        ),
      if (elenco.isEmpty)
        const StatoVuoto('Nessun lupetto trovato', dettaglio: 'Cambia la ricerca o togli i filtri.')
      else
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < elenco.length; i++) ...[
              if (i > 0) const Divider(indent: 72),
              _RigaLupetto(elenco[i], annoSest),
            ],
          ]),
        ),
    ]),
    );
  }
}

class _RigaLupetto extends StatelessWidget {
  const _RigaLupetto(this.l, this.annoSest);
  final Lupetto l;
  final int? annoSest;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final sest = l.sestiglie?.perAnno[annoSest];
    final colore = sest == null ? s.primaryContainer : coloreSestiglia(sest);
    final c = l.censimento;
    final daPagare = c != null && (c.censimentoDaPagare || c.sanFraDaPagare || c.vdbDaPagare);
    final sanitaria = c != null && c.sanitariaMancante;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
      leading: AvatarIniziali(l.nome, colore: colore, testo: sest == null ? s.onPrimaryContainer : testoSu(colore)),
      title: Text(l.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        if (l.annoNumero != null) '${l.annoNumero}° anno',
        ?sest,
      ].join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (daPagare) Icon(Icons.euro, size: 18, color: s.error, semanticLabel: 'Quote da pagare'),
        if (sanitaria) Icon(Icons.medical_services_outlined, size: 18, color: s.secondary, semanticLabel: 'Scheda sanitaria mancante'),
        const Icon(Icons.chevron_right),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LupettoDetailScreen(chiave: l.chiave),
      )),
    );
  }
}
