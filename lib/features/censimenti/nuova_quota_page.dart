import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/cell_utils.dart';
import '../common/scrittura.dart';
import '../dati/dati_provider.dart';
import 'censimenti_logic.dart';

/// Crea una quota extra (uscita, gita, materiale...) da incassare dai lupetti.
/// Chiude restituendo il nome della quota creata.
class NuovaQuotaPage extends ConsumerStatefulWidget {
  const NuovaQuotaPage({super.key});
  @override
  ConsumerState<NuovaQuotaPage> createState() => _NuovaQuotaPageState();
}

class _NuovaQuotaPageState extends ConsumerState<NuovaQuotaPage> {
  final _nome = TextEditingController();
  final _importo = TextEditingController();
  Set<String>? _scelti; // null = tutti (default alla prima apertura)
  String? _errore;

  @override
  void dispose() {
    _nome.dispose();
    _importo.dispose();
    super.dispose();
  }

  Future<void> _salva(List<String> tutti) async {
    final scelti = _scelti ?? tutti.toSet();
    final quote = ref.read(datiProvider).value?.data.quote;
    final errore = validaNuovaQuota(
      nome: _nome.text,
      importo: cellNumber(_importo.text.trim()),
      selezionati: scelti.length,
      esistenti: quote?.nomiExtra ?? const [],
    );
    if (errore != null) {
      setState(() => _errore = errore);
      return;
    }
    final nome = _nome.text.trim();
    final importo = cellNumber(_importo.text.trim())!;
    final elenco = [
      for (final n in tutti)
        if (scelti.contains(n)) n,
    ];
    final ok = await eseguiModifica(context, ref, (_) async {
      await ref.read(scritturaProvider).creaQuotaExtra(nome, importo, elenco);
      return 'Quota creata per ${elenco.length} lupetti.';
    });
    if (ok && mounted) Navigator.of(context).pop(nome);
  }

  @override
  Widget build(BuildContext context) {
    final tutti = [for (final l in ref.watch(lupettiProvider)) l.nome]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final scelti = _scelti ?? tutti.toSet();
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova quota')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
            onPressed: () => _salva(tutti),
            child: Text('Crea quota (${scelti.length} lupetti)'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome (es. Uscita di Natale)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _importo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quota a lupetto', suffixText: '€'),
          ),
          if (_errore != null) ...[const SizedBox(height: 12), Text(_errore!, style: TextStyle(color: s.error))],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('Chi deve pagare', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => setState(() => _scelti = tutti.toSet()), child: const Text('Tutti')),
              TextButton(onPressed: () => setState(() => _scelti = <String>{}), child: const Text('Nessuno')),
            ],
          ),
          for (final n in tutti)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(n),
              value: scelti.contains(n),
              onChanged: (v) => setState(() {
                final x = {...scelti};
                v == true ? x.add(n) : x.remove(n);
                _scelti = x;
              }),
            ),
        ],
      ),
    );
  }
}
