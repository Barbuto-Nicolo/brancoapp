import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';

import '../../theme/app_theme.dart';
import '../common/scout_art.dart';
import '../dati/dati_provider.dart';

/// Schermata mostrata quando non c'è né sessione né cache.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.messaggio});
  final String? messaggio;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _inCorso = false;
  String? _errore;

  Future<void> _accedi() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      // Un nuovo accesso può essere di un altro account: via i dati salvati prima.
      await ref.read(cacheStoreProvider).cancella(ref.read(profiloProvider).nome);
      await ref.read(authServiceProvider).accedi();
      ref.invalidate(datiProvider);
    } catch (e) {
      // Il messaggio tecnico non contiene dati personali.
      if (mounted) {
        setState(() => _errore = 'Accesso non riuscito ($e). Riprova.');
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.paddingOf(context).top;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: alto + 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const PaesaggioScout(),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: alto + 36),
                    child: const LogoLupo(size: 112),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Column(
                children: [
                  Text('BrancoApp', style: t.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                    widget.messaggio ??
                        'Accedi con il tuo account Google per consultare e aggiornare i dati del branco.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.giallo,
                      foregroundColor: const Color(0xFF2A2000),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    onPressed: _inCorso ? null : _accedi,
                    icon: _inCorso
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Accedi con Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse(AppConfig.urlPrivacy), mode: LaunchMode.externalApplication),
                    child: const Text('Informativa sulla privacy'),
                  ),
                  if (_errore != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errore!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
