import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/format.dart';
import '../common/scout_art.dart';
import '../common/scrittura.dart';
import '../common/widgets.dart';
import '../dati/dati_provider.dart';
import '../../theme/app_theme.dart';

/// Capi che possono fare spese: quelli nel tab "Capi", seguiti dai nomi già
/// usati in "Pagato da" nel Bilancio che nel tab non ci sono ancora.
({List<String> capi, List<String> soloBilancio}) elencoCapi(DatiState? dati) {
  if (dati == null) return (capi: const [], soloBilancio: const []);
  final capi = dati.data.capi;
  final visti = {for (final c in capi) c.toLowerCase()};
  final altri = <String>[];
  for (final m in dati.data.movimenti) {
    final n = m.pagatoDa;
    if (n != null && visti.add(n.toLowerCase())) altri.add(n);
  }
  altri.sort();
  return (capi: capi, soloBilancio: altri);
}

/// Chiede il nome e lo aggiunge al tab "Capi". Restituisce il nome inserito, o null.
Future<String?> chiediEAggiungiCapo(BuildContext context, WidgetRef ref, {String? suggerito}) async {
  if (!await controllaOnline(context, ref) || !context.mounted) return null;
  final nome = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctrl = TextEditingController(text: suggerito);
      return AlertDialog(
        title: const Text('Nuovo capo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nome (come lo scrivi in "Pagato da")',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Aggiungi')),
        ],
      );
    },
  );
  if (nome == null || nome.isEmpty || !context.mounted) return null;
  final ok = await eseguiModifica(
    context,
    ref,
    (_) async {
      await ref.read(scritturaProvider).aggiungiCapo(nome);
      return null;
    },
    conflittoSovrascrivibile: false,
  );
  return ok ? nome : null;
}

class CapiScreen extends ConsumerWidget {
  const CapiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dati = ref.watch(datiProvider).value;
    final e = elencoCapi(dati);
    final r = ref.watch(rimborsiPendentiProvider);
    final s = Theme.of(context).colorScheme;
    final tabCapi = ref.watch(profiloProvider).tabCapi;

    Widget riga(String nome, {required bool inElenco}) {
      final dovuto = r.rimborsiPerPersona[nome];
      return ListTile(
        leading: AvatarIniziali(nome, colore: s.primaryContainer, testo: s.onPrimaryContainer),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(dovuto == null ? (inElenco ? 'Nessun rimborso in sospeso' : 'Presente solo nel Bilancio') : 'Da rimborsare: ${euro(dovuto)}'),
        trailing: inElenco
            ? null
            : TextButton(
                onPressed: () => chiediEAggiungiCapo(context, ref, suggerito: nome),
                child: const Text('Aggiungi all\'elenco'),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Capi e spese')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => chiediEAggiungiCapo(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuovo capo'),
      ),
      body: ListaRefresh(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'I capi in elenco si possono scegliere come "Pagato da" quando registri una spesa. '
            'L\'elenco è salvato nel foglio, nel tab «$tabCapi».',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
        ),
        if (e.capi.isEmpty && e.soloBilancio.isEmpty)
          const StatoVuoto('Nessun capo in elenco', dettaglio: 'Aggiungi chi può anticipare o pagare le spese.')
        else ...[
          if (e.capi.isNotEmpty) ...[
            const Intestazione('In elenco'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                for (var i = 0; i < e.capi.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  riga(e.capi[i], inElenco: true),
                ],
              ]),
            ),
          ],
          if (e.soloBilancio.isNotEmpty) ...[
            const Intestazione('Già usati nel Bilancio'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Palette.giallo.withValues(alpha: 0.10),
              child: Column(children: [
                for (var i = 0; i < e.soloBilancio.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  riga(e.soloBilancio[i], inElenco: false),
                ],
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}
