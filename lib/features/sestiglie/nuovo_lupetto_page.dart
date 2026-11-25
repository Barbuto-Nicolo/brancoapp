import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/cell_utils.dart';
import '../../models/models.dart';
import '../common/colori_sestiglie.dart';
import '../common/scrittura.dart';
import '../dati/dati_provider.dart';

/// Controlla i dati del modulo "Nuovo lupetto". null = tutto a posto.
String? validaNuovoLupetto({
  required String nome,
  required int? anno,
  required String sestiglia,
  required Iterable<String> nomiEsistenti,
}) {
  final n = nome.trim();
  if (n.length < 3 || !n.contains(' ')) return 'Scrivi nome e cognome.';
  if (anno == null) return 'Scegli l\'anno di cammino.';
  if (sestiglia.trim().isEmpty) return 'Scegli o scrivi la sestiglia.';
  final k = normalizeName(n);
  if (nomiEsistenti.any((e) => normalizeName(e) == k)) {
    return 'Esiste già un lupetto con questo nome.';
  }
  return null;
}

/// Aggiunge un lupetto completamente nuovo a tutti i tab del foglio.
class NuovoLupettoPage extends ConsumerStatefulWidget {
  const NuovoLupettoPage({super.key, required this.anno, required this.sestiglie});

  /// Anno (colonna) della tab Sestiglie in cui assegnarlo.
  final int anno;

  /// Sestiglie già esistenti in quell'anno.
  final List<String> sestiglie;

  @override
  ConsumerState<NuovoLupettoPage> createState() => _NuovoLupettoPageState();
}

class _NuovoLupettoPageState extends ConsumerState<NuovoLupettoPage> {
  final _nome = TextEditingController();
  final _altra = TextEditingController();
  int? _annoCammino;
  String? _sestiglia; // null con _altraAttiva = scrittura libera
  bool _altraAttiva = false;
  String? _errore;

  @override
  void dispose() {
    _nome.dispose();
    _altra.dispose();
    super.dispose();
  }

  String get _sestigliaScelta => _altraAttiva ? _altra.text.trim() : (_sestiglia ?? '');

  Future<void> _salva() async {
    final esistenti = ref.read(lupettiProvider).map((l) => l.nome);
    final err = validaNuovoLupetto(
      nome: _nome.text,
      anno: _annoCammino,
      sestiglia: _sestigliaScelta,
      nomiEsistenti: esistenti,
    );
    setState(() => _errore = err);
    if (err != null) return;
    if (!await controllaOnline(context, ref) || !mounted) return;

    final nuovo = NuovoLupetto(
      nome: _nome.text.trim(),
      annoCammino: _annoCammino!,
      sestiglia: _sestigliaScelta,
      annoSestiglia: widget.anno,
    );
    final ok = await eseguiModifica(
      context,
      ref,
      (_) async {
        final esito = await ref.read(scritturaProvider).aggiungiLupetto(nuovo);
        if (esito.completo) return '${nuovo.nome} aggiunto al foglio.';
        final saltati = esito.saltati.entries.map((e) => '${e.key} (${e.value})').join(', ');
        return '${nuovo.nome} aggiunto, ma non in: $saltati.';
      },
      conflittoSovrascrivibile: false,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo lupetto')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _salva,
            icon: const Icon(Icons.check),
            label: const Text('Aggiungi al foglio'),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        TextField(
          controller: _nome,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome e cognome'),
        ),
        const SizedBox(height: 24),
        Text('Anno di cammino', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final a in const [2, 3, 4])
            ChoiceChip(
              label: Text('$a° anno'),
              selected: _annoCammino == a,
              onSelected: (_) => setState(() => _annoCammino = a),
            ),
        ]),
        const SizedBox(height: 24),
        Text('Sestiglia ${widget.anno}', style: t.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final n in widget.sestiglie)
            ChoiceChip(
              avatar: CircleAvatar(backgroundColor: coloreSestiglia(n), radius: 8),
              label: Text(n),
              selected: !_altraAttiva && _sestiglia == n,
              onSelected: (_) => setState(() {
                _altraAttiva = false;
                _sestiglia = n;
              }),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Altra sestiglia'),
            selected: _altraAttiva,
            onSelected: (_) => setState(() => _altraAttiva = true),
          ),
        ]),
        if (_altraAttiva) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _altra,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome della sestiglia (es. Bianchi)'),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: s.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, color: s.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Il lupetto viene aggiunto a tutti i tab del foglio: Dati e recapiti, Sestiglie, '
                'Censimenti e Prede. Genitori, recapiti e data di nascita li inserisci dopo, '
                'dalla sua scheda.',
                style: t.bodyMedium,
              ),
            ),
          ]),
        ),
        if (_errore != null) ...[
          const SizedBox(height: 12),
          Text(_errore!, style: TextStyle(color: s.error, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}
