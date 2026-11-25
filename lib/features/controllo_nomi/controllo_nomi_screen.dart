import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets.dart';
import '../dati/dati_provider.dart';

/// Report dei nomi che non coincidono tra i tab (utile a chi cura il foglio).
class ControlloNomiScreen extends ConsumerWidget {
  const ControlloNomiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(datiProvider).value?.unione.report;
    return Scaffold(
      appBar: AppBar(title: const Text('Controllo nomi')),
      body: r == null
          ? const StatoVuoto('Nessun dato.')
          : ListView(children: [
              if (r.pulito) const StatoVuoto('Tutti i nomi corrispondono tra i tab.'),
              if (r.suggerimenti.isNotEmpty) ...[
                const Intestazione('Probabilmente la stessa persona (non uniti)'),
                for (final s in r.suggerimenti) ListTile(title: Text('${s.$1}  ≈  ${s.$2}')),
              ],
              if (r.mancanti.isNotEmpty) ...[
                const Intestazione('Mancano in questi tab'),
                for (final e in r.mancanti.entries)
                  ListTile(title: Text(e.key), subtitle: Text(e.value.join(', '))),
              ],
              if (r.duplicati.isNotEmpty) ...[
                const Intestazione('Nomi ripetuti nello stesso tab'),
                for (final d in r.duplicati) ListTile(title: Text(d.$2), subtitle: Text(d.$1)),
              ],
            ]),
    );
  }
}
