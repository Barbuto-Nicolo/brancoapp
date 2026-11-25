import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/cell_utils.dart';
import '../../data/write_service.dart';
import 'format.dart';
import 'scrittura.dart';

enum TipoCampo { testo, numerico, data }

/// Converte il testo nel tipo da scrivere. Lancia FormatException se non valido.
Object? convertiCampo(TipoCampo tipo, String testo) {
  final t = testo.trim();
  switch (tipo) {
    case TipoCampo.testo:
      return t;
    case TipoCampo.numerico:
      // Come nel foglio: sequenze di sole cifre (telefoni, codici) restano numeri.
      return RegExp(r'^[1-9]\d{0,14}$').hasMatch(t) ? int.parse(t) : t;
    case TipoCampo.data:
      if (t.isEmpty) return '';
      final d = cellDate(t);
      if (d == null) throw const FormatException('Data non valida (gg/mm/aaaa)');
      return d;
  }
}

class CampoForm {
  const CampoForm({
    required this.etichetta,
    required this.header,
    required this.tipo,
    this.iniziale,
    this.offset = 0,
    this.sezione,
  });
  final String etichetta;
  final String header;
  final int offset;
  final TipoCampo tipo;

  /// Valore caricato: String? (testo/numerico) o DateTime? (data).
  final Object? iniziale;

  /// Titolo di gruppo mostrato sopra il campo.
  final String? sezione;
}

/// Maschera generica: modifica più campi di UNA riga-lupetto e scrive solo
/// quelli cambiati.
class ModificaCampiPage extends ConsumerStatefulWidget {
  const ModificaCampiPage({
    super.key,
    required this.titolo,
    required this.tab,
    required this.nomeNelTab,
    required this.campi,
  });
  final String titolo;
  final String tab;
  final String nomeNelTab;
  final List<CampoForm> campi;

  @override
  ConsumerState<ModificaCampiPage> createState() => _ModificaCampiPageState();
}

class _ModificaCampiPageState extends ConsumerState<ModificaCampiPage> {
  late final List<TextEditingController> _ctrl;
  late final List<String?> _errori;

  static String _testoIniziale(CampoForm c) {
    final v = c.iniziale;
    if (v is DateTime) return dataIt(v);
    return v?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = [for (final c in widget.campi) TextEditingController(text: _testoIniziale(c))];
    _errori = List.filled(widget.campi.length, null);
  }

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salva() async {
    final campi = <Campo>[];
    var errore = false;
    for (var i = 0; i < widget.campi.length; i++) {
      final f = widget.campi[i];
      final testo = _ctrl[i].text.trim();
      if (testo == _testoIniziale(f).trim()) continue;
      try {
        campi.add(Campo(
          etichetta: f.etichetta,
          header: f.header,
          offset: f.offset,
          atteso: f.iniziale,
          nuovo: convertiCampo(f.tipo, testo),
        ));
        _errori[i] = null;
      } on FormatException catch (e) {
        _errori[i] = e.message;
        errore = true;
      }
    }
    setState(() {});
    if (errore) return;
    if (campi.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (!await controllaOnline(context, ref) || !mounted) return;
    final ok = await scriviCampiLupetto(context, ref,
        tab: widget.tab, nomeNelTab: widget.nomeNelTab, campi: campi);
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String? ultima;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titolo)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(onPressed: _salva, icon: const Icon(Icons.check), label: const Text('Salva')),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < widget.campi.length; i++) ...[
          if (widget.campi[i].sezione != null && widget.campi[i].sezione != ultima)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text((ultima = widget.campi[i].sezione)!, style: Theme.of(context).textTheme.titleSmall),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _ctrl[i],
              keyboardType: switch (widget.campi[i].tipo) {
                TipoCampo.numerico => TextInputType.phone,
                TipoCampo.data => TextInputType.datetime,
                TipoCampo.testo => TextInputType.text,
              },
              decoration: InputDecoration(
                labelText: widget.campi[i].etichetta +
                    (widget.campi[i].tipo == TipoCampo.data ? ' (gg/mm/aaaa)' : ''),
                errorText: _errori[i],
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
