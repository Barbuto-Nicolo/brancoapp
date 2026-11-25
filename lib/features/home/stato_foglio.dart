import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../common/format.dart';
import '../dati/dati_provider.dart';

enum StatoConnessione { connesso, aggiornamento, offline, accessoScaduto, errore }

/// Stato del collegamento al foglio, ricavato dallo stato dei dati.
StatoConnessione calcolaStato({required DatiState? dati, required bool inCorso}) {
  if (inCorso) return StatoConnessione.aggiornamento;
  if (dati == null) return StatoConnessione.errore;
  if (dati.avvisoRichiedeLogin) return StatoConnessione.accessoScaduto;
  if (dati.offline) return StatoConnessione.offline;
  if (dati.avviso != null) return StatoConnessione.errore;
  return StatoConnessione.connesso;
}

/// Chip nella testata: dice se l'app è collegata al foglio e quando ha letto l'ultima volta.
class StatoFoglioChip extends ConsumerWidget {
  const StatoFoglioChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dati = ref.watch(datiProvider).value;
    final inCorso = ref.watch(inAggiornamentoProvider);
    final profilo = ref.watch(profiloProvider);
    final stato = calcolaStato(dati: dati, inCorso: inCorso);
    final ora = dati == null ? '' : oraIt(dati.aggiornatoAl);

    final (colore, testo) = switch (stato) {
      StatoConnessione.connesso => (const Color(0xFF7DDC8F), 'Collegato · foglio ${profilo.nome} · $ora'),
      StatoConnessione.aggiornamento => (Palette.giallo, 'Aggiorno dal foglio…'),
      StatoConnessione.offline => (Palette.giallo, 'Offline · dati delle $ora'),
      StatoConnessione.accessoScaduto => (const Color(0xFFFF8F7C), 'Accesso scaduto · tocca'),
      StatoConnessione.errore => (const Color(0xFFFF8F7C), 'Foglio non raggiungibile · tocca'),
    };

    return Semantics(
      button: true,
      label: 'Stato del collegamento al foglio: $testo',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => mostraDettaglioFoglio(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (stato == StatoConnessione.aggiornamento)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Palette.giallo),
              )
            else
              Container(width: 10, height: 10, decoration: BoxDecoration(color: colore, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(testo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Foglio di dettaglio: quale file è collegato, quando è stato letto, e i comandi.
Future<void> mostraDettaglioFoglio(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _DettaglioFoglio(),
  );
}

class _DettaglioFoglio extends ConsumerWidget {
  const _DettaglioFoglio();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dati = ref.watch(datiProvider).value;
    final inCorso = ref.watch(inAggiornamentoProvider);
    final profilo = ref.watch(profiloProvider);
    final stato = calcolaStato(dati: dati, inCorso: inCorso);
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final id = profilo.spreadsheetId;

    final (icona, colore, titolo, spiegazione) = switch (stato) {
      StatoConnessione.connesso => (Icons.cloud_done_outlined, s.primary, 'Collegato al foglio',
          'Le modifiche che fai qui vengono scritte direttamente su questo file.'),
      StatoConnessione.aggiornamento => (Icons.sync, s.tertiary, 'Aggiornamento in corso',
          'Sto leggendo i dati più recenti dal foglio.'),
      StatoConnessione.offline => (Icons.cloud_off_outlined, s.secondary, 'Sei offline',
          'Vedi gli ultimi dati salvati sul telefono. Le modifiche sono bloccate finché non torni online.'),
      StatoConnessione.accessoScaduto => (Icons.lock_outline, s.error, 'Accesso scaduto',
          'Accedi di nuovo con Google per leggere e modificare il foglio.'),
      StatoConnessione.errore => (Icons.error_outline, s.error, 'Foglio non raggiungibile',
          dati?.avviso ?? 'Non riesco a leggere il foglio. Riprova tra poco.'),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icona, color: colore, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(titolo, style: t.titleLarge)),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profilo.titoloFoglio, style: t.titleMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: profilo.nome == 'reale' ? s.errorContainer : s.secondaryContainer,
                  label: Text(profilo.nome == 'reale' ? 'Foglio reale' : 'Copia di prova'),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('ID …${id.length > 6 ? id.substring(id.length - 6) : id}'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Text(spiegazione, style: t.bodyMedium),
          const SizedBox(height: 12),
          if (dati != null)
            Text('Ultimo aggiornamento: ${dataOraIt(dati.aggiornatoAl)}', style: t.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Mentre l\'app è aperta rilegge il foglio da sola ogni ${intervalloAggiornamento.inSeconds} secondi.',
            style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: inCorso ? null : () => ref.read(datiProvider.notifier).aggiorna(),
                icon: const Icon(Icons.refresh),
                label: const Text('Aggiorna ora'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: profilo.configurato
                    ? () => launchUrl(Uri.parse('https://docs.google.com/spreadsheets/d/$id/edit'),
                        mode: LaunchMode.externalApplication)
                    : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Apri il foglio'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
