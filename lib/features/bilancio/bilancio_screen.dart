import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../common/scout_art.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import 'nuovo_movimento_page.dart';

enum _Vista { movimenti, categoria, pagatoDa }

/// Testo del promemoria dei rimborsi (da condividere, ad esempio su WhatsApp).
String testoPromemoria(RiepilogoBilancio r) {
  final b = StringBuffer('Promemoria BrancoApp: spese anticipate da rimborsare (${euro(r.totaleDaRimborsare)}).\n');
  for (final e in r.rimborsiPerPersona.entries) {
    b.writeln('\n${e.key}: ${euro(e.value)}');
    for (final m in r.daRimborsare.where((m) => (m.pagatoDa ?? 'Non indicato') == e.key)) {
      b.writeln('• ${m.descrizione} ${euro(m.importo.abs())}${m.data == null ? '' : ' (${dataIt(m.data)})'}');
    }
  }
  return b.toString().trimRight();
}

class BilancioScreen extends ConsumerStatefulWidget {
  const BilancioScreen({super.key});
  @override
  ConsumerState<BilancioScreen> createState() => _BilancioScreenState();
}

class _BilancioScreenState extends ConsumerState<BilancioScreen> {
  _Vista _vista = _Vista.movimenti;

  Color _colore(BuildContext c, double v) =>
      v < 0 ? Theme.of(c).colorScheme.error : Theme.of(c).colorScheme.primary;

  Future<void> _rimborsa(List<Movimento> spese, String chi) async {
    if (!await controllaOnline(context, ref) || !mounted) return;
    final totale = spese.fold<double>(0, (a, m) => a + m.importo.abs());
    final data = await chiediData(context, 'Rimborsato a $chi (${euro(totale)}) il', DateTime.now());
    if (data == null || !mounted) return;
    await eseguiModifica(
      context,
      ref,
      (_) async {
        await ref.read(scritturaProvider).segnaRimborsati(spese, data);
        return null;
      },
      conflittoSovrascrivibile: false,
    );
  }

  Future<void> _condividi(RiepilogoBilancio r) async {
    final uri = Uri.parse('https://wa.me/').replace(queryParameters: {'text': testoPromemoria(r)});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Non riesco ad aprire WhatsApp su questo telefono.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dati = ref.watch(datiProvider).value;
    if (dati == null) return const SizedBox.shrink();
    final r = RiepilogoBilancio(dati.data.movimenti);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!await controllaOnline(context, ref) || !context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NuovoMovimentoPage()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuova spesa'),
      ),
      body: ListaRefresh(children: [
        _SaldoCard(r),
        if (r.daRimborsare.isNotEmpty) _RimborsiCard(r, onRimborsa: _rimborsa, onCondividi: () => _condividi(r)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_Vista>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Vista.movimenti, label: Text('Movimenti')),
              ButtonSegment(value: _Vista.categoria, label: Text('Categoria')),
              ButtonSegment(value: _Vista.pagatoDa, label: Text('Pagato da')),
            ],
            selected: {_vista},
            onSelectionChanged: (s) => setState(() => _vista = s.first),
          ),
        ),
        if (r.movimenti.isEmpty)
          const StatoVuoto('Nessun movimento', dettaglio: 'Registra la prima spesa con il pulsante giallo.')
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              if (_vista == _Vista.movimenti)
                for (var i = 0; i < r.movimenti.length; i++) ...[
                  if (i > 0) const Divider(indent: 68),
                  _MovimentoTile(r.movimenti[r.movimenti.length - 1 - i]),
                ]
              else
                for (final e in (_vista == _Vista.categoria ? r.perCategoria : r.perPagatoDa).entries.indexed) ...[
                  if (e.$1 > 0) const Divider(),
                  ListTile(
                    title: Text(e.$2.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: Text(euro(e.$2.value),
                        style: TextStyle(color: _colore(context, e.$2.value), fontWeight: FontWeight.w800)),
                  ),
                ],
            ]),
          ),
      ]),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  const _SaldoCard(this.r);
  final RiepilogoBilancio r;

  @override
  Widget build(BuildContext context) {
    final entrate = r.movimenti.where((m) => m.importo > 0).fold<double>(0, (a, m) => a + m.importo);
    final uscite = r.movimenti.where((m) => m.importo < 0).fold<double>(0, (a, m) => a + m.importo);
    TextStyle piccolo(Color c) => TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.bosco, Palette.prato],
        ),
      ),
      child: Stack(children: [
        Positioned(
          right: -8,
          bottom: -6,
          child: Opacity(
            opacity: 0.20,
            child: SizedBox(
              width: 130,
              height: 96,
              child: CustomPaint(
                painter: TendaPainter(
                  tela: Palette.tela,
                  ombra: const Color(0xFFD9C58C),
                  porta: Palette.boscoNotte,
                  terreno: Colors.transparent,
                  pino: Palette.boscoNotte,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Saldo di cassa', style: piccolo(Colors.white70)),
            const SizedBox(height: 2),
            Text(
              euro(r.saldo),
              style: TextStyle(
                color: r.saldo < 0 ? const Color(0xFFFFB4A8) : Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 18, children: [
              Text('Entrate ${euro(entrate)}', style: piccolo(const Color(0xFFB8F0C8))),
              Text('Uscite ${euro(uscite.abs())}', style: piccolo(const Color(0xFFFFD0C8))),
            ]),
            const SizedBox(height: 2),
            Text('${r.movimenti.length} movimenti', style: piccolo(Colors.white60)),
          ]),
        ),
      ]),
    );
  }
}

class _RimborsiCard extends StatelessWidget {
  const _RimborsiCard(this.r, {required this.onRimborsa, required this.onCondividi});
  final RiepilogoBilancio r;
  final Future<void> Function(List<Movimento>, String) onRimborsa;
  final VoidCallback onCondividi;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final oggi = DateTime.now();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: s.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.giallo, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(children: [
            Icon(Icons.notifications_active_outlined, color: s.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Da rimborsare', style: t.titleMedium?.copyWith(color: s.onSecondaryContainer)),
                Text(
                  '${euro(r.totaleDaRimborsare)} anticipati dai capi · ${r.daRimborsare.length} spese',
                  style: t.bodySmall?.copyWith(color: s.onSecondaryContainer),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Condividi il promemoria',
              icon: Icon(Icons.share_outlined, color: s.onSecondaryContainer),
              onPressed: onCondividi,
            ),
          ]),
        ),
        for (final e in r.rimborsiPerPersona.entries)
          _PersonaRimborso(
            chi: e.key,
            totale: e.value,
            spese: [for (final m in r.daRimborsare) if ((m.pagatoDa ?? 'Non indicato') == e.key) m],
            oggi: oggi,
            onRimborsa: onRimborsa,
          ),
        const SizedBox(height: 10),
      ]),
    );
  }
}

class _PersonaRimborso extends StatelessWidget {
  const _PersonaRimborso({
    required this.chi,
    required this.totale,
    required this.spese,
    required this.oggi,
    required this.onRimborsa,
  });
  final String chi;
  final double totale;
  final List<Movimento> spese;
  final DateTime oggi;
  final Future<void> Function(List<Movimento>, String) onRimborsa;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final date = [for (final m in spese) if (m.data != null) m.data!]..sort();
    final giorni = date.isEmpty ? null : oggi.difference(date.first).inDays;
    final urgente = giorni != null && giorni > 30;
    final su = s.onSecondaryContainer;
    final scuro = s.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: scuro ? Colors.black.withValues(alpha: 0.30) : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarIniziali(chi,
              colore: scuro ? s.surfaceContainerHigh : Colors.white, testo: scuro ? s.onSurface : Palette.boscoNotte),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chi, style: t.titleMedium?.copyWith(color: su)),
              Text(
                [
                  '${spese.length} ${spese.length == 1 ? 'spesa' : 'spese'}',
                  if (giorni != null) giorni == 0 ? 'da oggi' : 'da $giorni giorni',
                ].join(' · '),
                style: TextStyle(
                  color: urgente ? s.error : su,
                  fontWeight: urgente ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ]),
          ),
          Text(euro(totale), style: t.titleLarge?.copyWith(color: su)),
        ]),
        if (spese.length > 1)
          for (final m in spese)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 2),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${m.descrizione}${m.data == null ? '' : ' · ${dataIt(m.data)}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: su, fontSize: 13.5),
                  ),
                ),
                Text(euro(m.importo.abs()), style: TextStyle(color: su, fontWeight: FontWeight.w700, fontSize: 13.5)),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(52, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => onRimborsa([m], chi),
                  child: const Text('Fatto'),
                ),
              ]),
            )
        else
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Text(
              '${spese.first.descrizione}${spese.first.data == null ? '' : ' · ${dataIt(spese.first.data)}'}',
              style: TextStyle(color: su, fontSize: 13.5),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onRimborsa(spese, chi),
            icon: const Icon(Icons.check),
            label: Text(spese.length > 1 ? 'Rimborsato tutto a $chi' : 'Rimborsato a $chi'),
          ),
        ),
      ]),
    );
  }
}

class _MovimentoTile extends StatelessWidget {
  const _MovimentoTile(this.m);
  final Movimento m;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final uscita = m.importo < 0;
    final dettagli = [
      m.categoria,
      if (m.data != null) dataIt(m.data),
      if (m.pagatoDa != null) 'pagato da ${m.pagatoDa}',
      m.note,
    ].whereType<String>().join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: uscita ? s.errorContainer : s.primaryContainer,
        child: Icon(uscita ? Icons.north_east : Icons.south_west,
            size: 20, color: uscita ? s.onErrorContainer : s.onPrimaryContainer),
      ),
      title: Text(m.descrizione, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (dettagli.isNotEmpty) Text(dettagli),
        if (m.daRimborsare)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: m.rimborsataIl == null ? s.secondaryContainer : s.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                m.rimborsataIl == null ? 'Da rimborsare' : 'Rimborsata il ${dataIt(m.rimborsataIl)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: m.rimborsataIl == null ? s.onSecondaryContainer : s.onPrimaryContainer,
                ),
              ),
            ),
          ),
      ]),
      trailing: Text(
        euro(m.importo),
        style: TextStyle(color: uscita ? s.error : s.primary, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
