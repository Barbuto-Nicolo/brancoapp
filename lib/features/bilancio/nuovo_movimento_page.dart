import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/cell_utils.dart';
import '../../models/models.dart';
import '../common/format.dart';
import '../common/scrittura.dart';
import '../dati/dati_provider.dart';
import 'capi_screen.dart';

/// Costruisce un movimento dai testi del modulo; null + messaggio se non valido.
({Movimento? movimento, String? errore}) costruisciMovimento({
  required String descrizione,
  required String importo,
  required bool uscita,
  String categoria = '',
  String data = '',
  String pagatoDa = '',
  String note = '',
  bool daRimborsare = false,
}) {
  final d = descrizione.trim();
  if (d.isEmpty) return (movimento: null, errore: 'Scrivi una descrizione.');
  final v = cellNumber(importo.trim());
  if (v == null || v <= 0) return (movimento: null, errore: 'Importo non valido: scrivi un numero positivo (es. 7,50).');
  DateTime? dt;
  if (data.trim().isNotEmpty) {
    dt = cellDate(data.trim());
    if (dt == null) return (movimento: null, errore: 'Data non valida (gg/mm/aaaa).');
  }
  String? n(String s) => s.trim().isEmpty ? null : s.trim();
  final rimborso = daRimborsare && uscita;
  if (rimborso && pagatoDa.trim().isEmpty) {
    return (movimento: null, errore: 'Scegli chi ha anticipato i soldi in "Pagato da".');
  }
  return (
    movimento: Movimento(
      descrizione: d,
      importo: uscita ? -v : v,
      categoria: n(categoria),
      data: dt,
      pagatoDa: n(pagatoDa),
      note: n(note),
      daRimborsare: rimborso,
    ),
    errore: null,
  );
}

class NuovoMovimentoPage extends ConsumerStatefulWidget {
  const NuovoMovimentoPage({super.key});
  @override
  ConsumerState<NuovoMovimentoPage> createState() => _NuovoMovimentoPageState();
}

class _NuovoMovimentoPageState extends ConsumerState<NuovoMovimentoPage> {
  final _desc = TextEditingController();
  final _importo = TextEditingController();
  final _cat = TextEditingController();
  final _data = TextEditingController(text: dataIt(DateTime.now()));
  final _pagato = TextEditingController();
  final _note = TextEditingController();
  bool _uscita = true;
  bool _anticipata = false;
  String? _errore;

  @override
  void dispose() {
    for (final c in [_desc, _importo, _cat, _data, _pagato, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salva() async {
    final r = costruisciMovimento(
      descrizione: _desc.text,
      importo: _importo.text,
      uscita: _uscita,
      categoria: _cat.text,
      data: _data.text,
      pagatoDa: _pagato.text,
      note: _note.text,
      daRimborsare: _anticipata,
    );
    setState(() => _errore = r.errore);
    if (r.movimento == null) return;
    if (!await controllaOnline(context, ref) || !mounted) return;
    final ok = await eseguiModifica(
      context,
      ref,
      (_) => ref.read(scritturaProvider).aggiungiMovimento(r.movimento!),
      conflittoSovrascrivibile: false,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Widget _suggerimenti(List<String> valori, TextEditingController c) => Wrap(
        spacing: 8,
        children: [for (final v in valori) ActionChip(label: Text(v), onPressed: () => setState(() => c.text = v))],
      );

  Future<void> _nuovoCapo() async {
    final nome = await chiediEAggiungiCapo(context, ref);
    if (nome != null && mounted) setState(() => _pagato.text = nome);
  }

  @override
  Widget build(BuildContext context) {
    final mov = ref.watch(datiProvider).value?.data.movimenti ?? const <Movimento>[];
    final categorie = ({for (final m in mov) if (m.categoria != null) m.categoria!}.toList()..sort());
    final capi = elencoCapi(ref.watch(datiProvider).value);
    final pagatori = [...capi.capi, ...capi.soloBilancio];

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova spesa')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(onPressed: _salva, icon: const Icon(Icons.check), label: const Text('Salva')),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Uscita'), icon: Icon(Icons.arrow_upward)),
            ButtonSegment(value: false, label: Text('Entrata'), icon: Icon(Icons.arrow_downward)),
          ],
          selected: {_uscita},
          onSelectionChanged: (s) => setState(() => _uscita = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _desc,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Dettagli spesa', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _importo,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Importo in € (positivo)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder())),
        if (categorie.isNotEmpty) _suggerimenti(categorie, _cat),
        const SizedBox(height: 12),
        TextField(
          controller: _data,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(labelText: 'Data (gg/mm/aaaa)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pagato,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Pagato da (nome di caccia)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final v in pagatori)
            ChoiceChip(
              label: Text(v),
              selected: _pagato.text.trim().toLowerCase() == v.toLowerCase(),
              onSelected: (_) => setState(() => _pagato.text = v),
            ),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Nuovo capo'),
            onPressed: _nuovoCapo,
          ),
        ]),
        if (_uscita)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Anticipata da questo capo'),
            subtitle: const Text('La cassa gli deve il rimborso: comparirà nel promemoria di Bilancio.'),
            value: _anticipata,
            onChanged: (v) => setState(() => _anticipata = v),
          ),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder())),
        if (_errore != null) ...[
          const SizedBox(height: 12),
          Text(_errore!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ]),
    );
  }
}
