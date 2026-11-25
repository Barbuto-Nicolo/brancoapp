import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../common/widgets.dart';

/// Contenuto di Prede e specialità per un lupetto (riusato da elenco e scheda).
class PredeContenuto extends StatelessWidget {
  const PredeContenuto(this.p, {super.key});
  final PredeSpecialita p;

  @override
  Widget build(BuildContext context) {
    final impegni = p.impegni.where((i) => !i.vuoto).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CampoRiga('Caccia per', p.cacciaPer == null ? null : '${p.cacciaPer}${p.cacciaAsterisco ? ' *' : ''}'),
      CampoRiga('Preda', p.prede),
      CampoRiga('Con chi', p.conChi),
      CampoRiga('Stato preda', p.stato),
      CampoRiga('Specialità già acquisite',
          p.specialitaAcquisite.isEmpty ? null : p.specialitaAcquisite.join(', ')),
      if (impegni.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Nessun impegno di specialità in corso.'),
        ),
      for (final i in impegni)
        CampoRiga(
          'Specialità: ${i.specialita ?? '—'}',
          [i.impegno, if (i.conChi != null) 'con ${i.conChi}', if (i.stato != null) '(${i.stato})']
              .whereType<String>()
              .join(' '),
        ),
    ]);
  }
}
