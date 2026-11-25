import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bilancio/bilancio_screen.dart';
import '../bilancio/capi_screen.dart';
import '../censimenti/censimenti_screen.dart';
import '../controllo_nomi/controllo_nomi_screen.dart';
import '../dati/dati_provider.dart';
import '../lupetti/lupetti_screen.dart';
import '../prede/prede_screen.dart';
import '../sestiglie/sestiglie_screen.dart';
import 'intestazione_scout.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;

  static const _titoli = ['Lupetti', 'Sestiglie', 'Censimenti e quote', 'Prede e specialità', 'Bilancio'];
  static const _pagine = <Widget>[
    LupettiScreen(),
    SestiglieScreen(),
    CensimentiScreen(),
    PredeScreen(),
    BilancioScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final dati = ref.watch(datiProvider).value;
    final inCorso = ref.watch(inAggiornamentoProvider);
    final rimborsi = ref.watch(rimborsiPendentiProvider).daRimborsare.length;

    return Scaffold(
      body: Column(children: [
        IntestazioneScout(
          titolo: _titoli[_tab],
          azioni: [
            inCorso
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Aggiorna dal foglio',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => ref.read(datiProvider.notifier).aggiorna(),
                  ),
            PopupMenuButton<String>(
              tooltip: 'Menu',
              iconColor: Colors.white,
              onSelected: (v) async {
                if (v == 'capi') {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CapiScreen()));
                } else if (v == 'nomi') {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ControlloNomiScreen()));
                } else if (v == 'esci') {
                  await ref.read(repositoryProvider).esci();
                  ref.invalidate(datiProvider);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'capi', child: Text('Capi e spese')),
                PopupMenuItem(value: 'nomi', child: Text('Controllo nomi')),
                PopupMenuItem(value: 'esci', child: Text('Esci')),
              ],
            ),
          ],
        ),
        if (dati?.avviso != null)
          MaterialBanner(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            dividerColor: Colors.transparent,
            content: Text(dati!.avviso!),
            actions: [
              if (dati.avvisoRichiedeLogin)
                TextButton(
                  onPressed: () async {
                    try {
                      await ref.read(authServiceProvider).accedi();
                      await ref.read(datiProvider.notifier).aggiorna();
                    } catch (_) {}
                  },
                  child: const Text('Accedi'),
                )
              else
                TextButton(
                  onPressed: () => ref.read(datiProvider.notifier).aggiorna(),
                  child: const Text('Riprova'),
                ),
            ],
          ),
        Expanded(child: _pagine[_tab]),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Lupetti'),
          const NavigationDestination(icon: Icon(Icons.diversity_3_outlined), selectedIcon: Icon(Icons.diversity_3), label: 'Sestiglie'),
          const NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Quote'),
          const NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Prede'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: rimborsi > 0,
              label: Text('$rimborsi'),
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: rimborsi > 0,
              label: Text('$rimborsi'),
              child: const Icon(Icons.account_balance_wallet),
            ),
            label: 'Bilancio',
          ),
        ],
      ),
    );
  }
}
