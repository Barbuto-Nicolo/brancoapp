import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/auth/auth_service.dart';
import 'data/branco_repository.dart';
import 'data/sheets_client.dart' show SheetsException;
import 'features/auth/login_screen.dart';
import 'features/common/scout_art.dart';
import 'features/dati/dati_provider.dart';
import 'features/home/home_shell.dart';
import 'theme/app_theme.dart';

class LupettiApp extends ConsumerStatefulWidget {
  const LupettiApp({super.key});
  @override
  ConsumerState<LupettiApp> createState() => _LupettiAppState();
}

class _LupettiAppState extends ConsumerState<LupettiApp> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Si rilegge il foglio al ritorno in primo piano e, finché l'app è aperta,
    // ogni [intervalloAggiornamento]. In background il timer è fermo.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _avviaTimer();
        ref.read(datiProvider.notifier).aggiornaSeVecchi();
      },
      onHide: _fermaTimer,
    );
    _avviaTimer();
  }

  void _avviaTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(intervalloAggiornamento, (_) {
      ref.read(datiProvider.notifier).aggiornaSeVecchi(soglia: intervalloAggiornamento - const Duration(seconds: 2));
    });
  }

  void _fermaTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _fermaTimer();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BrancoApp',
      debugShowCheckedModeBanner: false,
      theme: costruisciTema(Brightness.light),
      darkTheme: costruisciTema(Brightness.dark),
      home: const _Gate(),
    );
  }
}

/// Decide cosa mostrare: caricamento, login, errore o app.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(datiProvider);
    return stato.when(
      data: (_) => const HomeShell(),
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [LogoLupo(size: 72), SizedBox(height: 20), CircularProgressIndicator()],
          ),
        ),
      ),
      error: (e, _) {
        if (e is NonAutenticatoException) return const LoginScreen();
        if (e is SheetsException && e.accessoNegato) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoLupo(size: 84),
                    const SizedBox(height: 20),
                    Text('Nessun accesso al foglio', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                      'Questo account Google non può aprire il foglio del branco. '
                      'Chiedi a un capo di condividerlo con la tua email, poi riprova.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: () => ref.invalidate(datiProvider), child: const Text('Riprova')),
                    TextButton(
                      onPressed: () async {
                        await ref.read(repositoryProvider).esci();
                        ref.invalidate(datiProvider);
                      },
                      child: const Text('Usa un altro account'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final testo = e is RetePersaException
            ? 'Nessuna connessione e nessun dato salvato. Collegati a internet per il primo caricamento.'
            : 'Impossibile leggere il foglio: $e';
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(testo, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => ref.invalidate(datiProvider), child: const Text('Riprova')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
