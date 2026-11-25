import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/scout_art.dart';
import '../common/widgets.dart';
import '../../models/models.dart';
import '../common/modifica_campi_page.dart';
import '../common/scrittura.dart';
import '../dati/dati_provider.dart';
import 'prede_widgets.dart';

class PredeScreen extends ConsumerWidget {
  const PredeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lupetti = ref.watch(lupettiProvider).where((l) => l.prede != null).toList();
    return ListaRefresh(children: [
      if (lupetti.isEmpty)
        const StatoVuoto('Nessun dato su prede e specialità')
      else
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(children: [
              for (var i = 0; i < lupetti.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                ExpansionTile(
                  tilePadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
                  leading: AvatarIniziali(
                    lupetti[i].nome,
                    colore: Theme.of(context).colorScheme.tertiaryContainer,
                    testo: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  title: Text(lupetti[i].nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    lupetti[i].prede!.cacciaPer ?? 'Caccia non indicata',
                    lupetti[i].prede!.stato ?? '',
                    '${lupetti[i].prede!.specialitaAcquisite.length} specialità',
                  ].where((s) => s.isNotEmpty).join(' · ')),
                  children: [
                    PredeContenuto(lupetti[i].prede!),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 8),
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Assegna / aggiorna'),
                          onPressed: () => modificaPrede(context, ref, lupetti[i]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ]),
          ),
        ),
    ]);
  }
}

/// Maschera di modifica: preda e i 3 blocchi specialità/impegno/con chi/stato.
Future<void> modificaPrede(BuildContext context, WidgetRef ref, Lupetto l) async {
  if (!await controllaOnline(context, ref) || !context.mounted) return;
  final p = l.prede!;
  final campi = <CampoForm>[
    CampoForm(etichetta: 'Preda', header: 'Prede', tipo: TipoCampo.testo, iniziale: p.prede, sezione: 'Preda'),
    CampoForm(etichetta: 'Con chi', header: 'Prede', offset: 1, tipo: TipoCampo.testo, iniziale: p.conChi, sezione: 'Preda'),
    CampoForm(etichetta: 'Stato', header: 'Prede', offset: 2, tipo: TipoCampo.testo, iniziale: p.stato, sezione: 'Preda'),
    for (var i = 0; i < 3; i++) ...[
      CampoForm(etichetta: 'Specialità', header: 'Specialità ${i + 1}', tipo: TipoCampo.testo, iniziale: p.impegni[i].specialita, sezione: 'Impegno ${i + 1}'),
      CampoForm(etichetta: 'Impegno', header: 'Specialità ${i + 1}', offset: 1, tipo: TipoCampo.testo, iniziale: p.impegni[i].impegno, sezione: 'Impegno ${i + 1}'),
      CampoForm(etichetta: 'Con chi', header: 'Specialità ${i + 1}', offset: 2, tipo: TipoCampo.testo, iniziale: p.impegni[i].conChi, sezione: 'Impegno ${i + 1}'),
      CampoForm(etichetta: 'Stato', header: 'Specialità ${i + 1}', offset: 3, tipo: TipoCampo.testo, iniziale: p.impegni[i].stato, sezione: 'Impegno ${i + 1}'),
    ],
  ];
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ModificaCampiPage(
      titolo: l.nome,
      tab: ref.read(profiloProvider).tabPrede,
      nomeNelTab: p.nome,
      campi: campi,
    ),
  ));
}
