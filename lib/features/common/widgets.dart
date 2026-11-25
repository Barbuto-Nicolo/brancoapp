import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dati/dati_provider.dart';
import 'scout_art.dart';

/// Lista scorrevole con pull-to-refresh (sempre scorrevole, anche se corta).
class ListaRefresh extends ConsumerWidget {
  const ListaRefresh({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(datiProvider.notifier).aggiorna(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        children: children,
      ),
    );
  }
}

class StatoVuoto extends StatelessWidget {
  const StatoVuoto(this.testo, {super.key, this.dettaglio, this.azione});
  final String testo;
  final String? dettaglio;
  final Widget? azione;
  @override
  Widget build(BuildContext context) => Center(child: TendaVuota(testo, dettaglio: dettaglio, azione: azione));
}

class Intestazione extends StatelessWidget {
  const Intestazione(this.testo, {super.key});
  final String testo;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(testo, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Riga "etichetta: valore" per le schede di dettaglio.
class CampoRiga extends StatelessWidget {
  const CampoRiga(this.etichetta, this.valore, {super.key, this.onTap, this.icona});
  final String etichetta;
  final String? valore;
  final VoidCallback? onTap;
  final IconData? icona;

  @override
  Widget build(BuildContext context) {
    if (valore == null || valore!.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(etichetta,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      subtitle: Text(valore!, style: Theme.of(context).textTheme.bodyLarge),
      trailing: icona == null ? null : Icon(icona),
      onTap: onTap,
    );
  }
}
