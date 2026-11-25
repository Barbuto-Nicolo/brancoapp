/// SOLO per vedere l'interfaccia su simulatore: dati finti, nessun login e
/// nessun accesso a Google. Non fa parte dell'app.
///
/// flutter run -t tool/preview_main.dart -d ID_SIMULATORE
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lupetti_app/app.dart';
import 'package:lupetti_app/config/app_config.dart';
import 'package:lupetti_app/data/branco_repository.dart';
import 'package:lupetti_app/data/name_matcher.dart';
import 'package:lupetti_app/data/write_service.dart';
import 'package:lupetti_app/features/dati/dati_provider.dart';
import 'package:lupetti_app/models/models.dart';

import '../test/fixtures/fixtures.dart';

final _p = AppConfig.profili['copia']!;

final _bilancio = <List<Object?>>[
  ['Dettagli spese', 'Categoria', 'Costo', 'Data della transazione', 'Pagato da', 'Note', 'Da rimborsare', 'Rimborsata il'],
  ['Conto iniziale', 'Sede', 235, '', '', 'Contanti'],
  ['Colori', 'Materiale', -18, s(2026, 11, 3), 'Akela', '', 'sì'],
  ['Quaderni', 'Attività', -7.5, s(2026, 11, 3), 'Akela', '', 'sì'],
  ['Corda', 'Materiale', -12, s(2026, 10, 1), 'Bagheera', '', 'sì', s(2026, 10, 20)],
  ['Pane', 'Cibo', -6, s(2026, 11, 9), 'Raksha'],
  ['Cartoncini', 'Attività', -14, s(2026, 9, 28), 'Bagheera', '', 'sì'],
  ['Quote Caccia', '/', 73, '', 'Bagheera'],
  ['', '', 250],
];

class _Repo implements BrancoRepository {
  @override
  Future<CaricamentoDati?> daCache() async => null;
  @override
  Future<CaricamentoDati> daRete() async => CaricamentoDati(
        BrancoData.daTab(_p, {
          _p.tabDati: fxDati,
          _p.tabCensimenti: fxCensimenti,
          _p.tabPrede: fxPrede,
          _p.tabSestiglie: fxSestiglie,
          _p.tabBilancio: _bilancio,
          _p.tabCapi: [
            ['Capo/a'],
            ['Akela'],
            ['Bagheera'],
            ['Raksha'],
          ],
        }),
        DateTime.now(),
        daCache: false,
      );
  @override
  Future<void> esci() async {}
}

class _Scrittura implements ScritturaService {
  @override
  Future<void> scriviCampi({
    required String tab,
    required String nomeNelTab,
    required List<Campo> campi,
    bool forza = false,
  }) async {}
  @override
  Future<String?> aggiungiMovimento(Movimento m) async => null;
  @override
  Future<void> segnaRimborsati(List<Movimento> movimenti, DateTime data) async {}
  @override
  Future<void> aggiungiCapo(String nome) async {}
  @override
  Future<EsitoNuovoLupetto> aggiungiLupetto(NuovoLupetto n) async => const EsitoNuovoLupetto([], {});

  @override
  Future<EsitoEliminazione> eliminaLupetto(Map<String, String> nomiPerTab) async =>
      EsitoEliminazione(nomiPerTab.keys.toList(), const {});
}

void main() {
  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(_Repo()),
      scritturaProvider.overrideWithValue(_Scrittura()),
      controlloOnlineProvider.overrideWithValue(() async => true),
    ],
    child: const LupettiApp(),
  ));
}
