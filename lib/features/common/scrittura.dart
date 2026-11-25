import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_service.dart';
import '../../data/branco_repository.dart' show RetePersaException;
import '../../data/parsers/cell_utils.dart';
import '../../data/sheets_client.dart';
import '../../data/write_service.dart';
import '../dati/dati_provider.dart';
import 'format.dart';

const _msgOffline = 'Sei offline: le modifiche sono bloccate finché non torni online.';

/// Controlla la rete prima di aprire una maschera di modifica.
Future<bool> controllaOnline(BuildContext context, WidgetRef ref) async {
  final ok = await ref.read(controlloOnlineProvider)();
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(_msgOffline)));
  }
  return ok;
}

String messaggioErrore(Object e) {
  if (e is OfflineException) return _msgOffline;
  if (e is RetePersaException) return 'Connessione assente o instabile: modifica NON salvata. Riprova.';
  if (e is NonAutenticatoException) return 'Sessione scaduta: accedi di nuovo.';
  if (e is LupettoNonTrovatoException) {
    return 'Nel tab "${e.tab}" non trovo più questo nome: è stato cambiato o cancellato nel foglio. Aggiorna e riprova.';
  }
  if (e is NomeAmbiguoException) return 'Nel tab "${e.tab}" il nome compare più volte: non so quale riga modificare.';
  if (e is NomeEsistenteException) {
    return 'Nel tab "${e.tab}" c\'è già un lupetto con questo nome. Controlla di non averlo già inserito.';
  }
  if (e is QuotaEsistenteException) return 'Esiste già una quota chiamata "${e.nome}".';
  if (e is QuotaConPagamentiException) {
    return 'Qualcuno ha già pagato questa quota: prima annulla i pagamenti, poi potrai eliminarla.';
  }
  if (e is CapoGiaPresenteException) return '${e.nome} è già nell\'elenco dei capi.';
  if (e is StrutturaException) return 'Il foglio ha una struttura diversa dal previsto: ${e.dettaglio}';
  if (e is SheetsException) return e.message;
  return 'Errore imprevisto: modifica non salvata.';
}

String _mostra(Object? v) {
  if (v is bool) return v ? 'sì' : 'no';
  final t = cellText(v);
  return t ?? '(vuoto)';
}

/// Esegue una scrittura con attesa, gestione errori e gestione dei conflitti.
/// [azione] riceve `forza`; restituisce un eventuale avviso da mostrare.
/// Restituisce true se la modifica è stata scritta.
Future<bool> eseguiModifica(
  BuildContext context,
  WidgetRef ref,
  Future<String?> Function(bool forza) azione, {
  bool conflittoSovrascrivibile = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  Future<({bool ok, String? avviso, Object? errore})> prova(bool forza) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
    );
    try {
      final avviso = await azione(forza);
      return (ok: true, avviso: avviso, errore: null);
    } catch (e) {
      return (ok: false, avviso: null, errore: e);
    } finally {
      navigator.pop();
    }
  }

  var r = await prova(false);
  if (!r.ok && r.errore is ConflittoException && context.mounted) {
    final conflitti = (r.errore as ConflittoException).conflitti;
    final scelta = await _dialogoConflitto(context, conflitti, conflittoSovrascrivibile);
    if (scelta == _Scelta.sovrascrivi) {
      r = await prova(true);
    } else {
      // Tiene il valore del foglio (o annulla): si aggiorna per mostrarlo.
      await ref.read(datiProvider.notifier).aggiorna();
      return false;
    }
  }
  if (!r.ok) {
    messenger.showSnackBar(SnackBar(content: Text(messaggioErrore(r.errore!))));
    if (r.errore is LupettoNonTrovatoException || r.errore is ConflittoException) {
      await ref.read(datiProvider.notifier).aggiorna();
    }
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(r.avviso ?? 'Salvato nel foglio.')));
  await ref.read(datiProvider.notifier).aggiorna();
  return true;
}

enum _Scelta { tieniFoglio, sovrascrivi }

Future<_Scelta?> _dialogoConflitto(BuildContext context, List<Conflitto> conflitti, bool sovrascrivibile) {
  return showDialog<_Scelta>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Un altro capo ha modificato il foglio'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in conflitti) ...[
              Text(c.etichetta, style: Theme.of(ctx).textTheme.titleSmall),
              Text('Nel foglio ora: ${_mostra(c.attuale)}'),
              Text('Tu avevi visto: ${_mostra(c.atteso)}'),
              Text('Tuo valore: ${c.nuovo is DateTime ? dataIt(c.nuovo as DateTime) : _mostra(c.nuovo)}'),
              const SizedBox(height: 12),
            ],
            const Text('Quale valore vuoi tenere?'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _Scelta.tieniFoglio),
          child: Text(sovrascrivibile ? 'Tieni quello del foglio' : 'Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, _Scelta.sovrascrivi),
          child: Text(sovrascrivibile ? 'Sovrascrivi con il mio' : 'Riprova'),
        ),
      ],
    ),
  );
}

/// Scrittura di campi di una riga-lupetto (nessun avviso finale).
Future<bool> scriviCampiLupetto(
  BuildContext context,
  WidgetRef ref, {
  required String tab,
  required String nomeNelTab,
  required List<Campo> campi,
}) => eseguiModifica(context, ref, (forza) async {
  await ref.read(scritturaProvider).scriviCampi(tab: tab, nomeNelTab: nomeNelTab, campi: campi, forza: forza);
  return null;
});

/// Chiede una data (gg/mm/aaaa, precompilata con [iniziale]). null se annullato.
Future<DateTime?> chiediData(BuildContext context, String titolo, DateTime iniziale) {
  final ctrl = TextEditingController(text: dataIt(iniziale));
  String? errore;
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(titolo),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.datetime,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Data (gg/mm/aaaa)', errorText: errore),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () {
              final d = cellDate(ctrl.text.trim());
              if (d == null) {
                setState(() => errore = 'Data non valida');
              } else {
                Navigator.pop(ctx, d);
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    ),
  );
}

Future<bool> chiediConferma(BuildContext context, String titolo, String testo) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titolo),
      content: Text(testo),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Conferma')),
      ],
    ),
  );
  return r ?? false;
}

/// Chiede un importo in euro. null = annullato; ''= "salta" (solo se [consentiSalta]).
Future<String?> chiediImporto(
  BuildContext context,
  String titolo,
  String testo, {
  bool consentiSalta = false,
  double? iniziale,
}) {
  final ctrl = TextEditingController(text: iniziale == null ? '' : iniziale.toString().replaceAll('.', ','));
  String? errore;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(titolo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(testo),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Importo in euro (es. 25,00)', suffixText: '€', errorText: errore),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          if (consentiSalta) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Non registrare')),
          FilledButton(
            onPressed: () {
              final v = cellNumber(ctrl.text.trim());
              if (v == null || v <= 0) {
                setState(() => errore = 'Importo non valido');
              } else {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('Conferma'),
          ),
        ],
      ),
    ),
  );
}
