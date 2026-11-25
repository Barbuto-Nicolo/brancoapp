import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Numero in formato internazionale senza "+", per wa.me. Un cellulare italiano
/// a 10 cifre che inizia per 3 riceve il prefisso 39. null se non plausibile.
String? numeroPerWhatsapp(String telefono) {
  var d = telefono.replaceAll(RegExp(r'[^\d+]'), '');
  if (d.startsWith('+')) {
    d = d.substring(1);
  } else if (d.startsWith('00')) {
    d = d.substring(2);
  } else if (d.length == 10 && d.startsWith('3')) {
    d = '39$d';
  }
  d = d.replaceAll('+', '');
  return d.length >= 9 ? d : null;
}

Uri uriChiamata(String telefono) =>
    Uri(scheme: 'tel', path: telefono.replaceAll(RegExp(r'[^\d+]'), ''));

Uri uriMail(String email) => Uri(scheme: 'mailto', path: email.trim());

Future<void> _apri(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('Impossibile aprire l\'app richiesta.')));
  }
}

/// Foglio con le azioni per un numero: chiama o WhatsApp.
void mostraAzioniTelefono(BuildContext context, String nome, String telefono) {
  final wa = numeroPerWhatsapp(telefono);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(nome), subtitle: Text(telefono)),
          ListTile(
            leading: const Icon(Icons.call),
            title: const Text('Chiama'),
            onTap: () {
              Navigator.pop(ctx);
              _apri(context, uriChiamata(telefono));
            },
          ),
          if (wa != null)
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Scrivi su WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _apri(context, Uri.parse('https://wa.me/$wa'));
              },
            ),
        ],
      ),
    ),
  );
}

void scriviMail(BuildContext context, String email) => _apri(context, uriMail(email));
