import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../common/scout_art.dart';
import 'stato_foglio.dart';

/// Testata dell'app: paesaggio notturno con titolo della sezione, stato del
/// foglio e pulsanti (aggiorna, menu).
class IntestazioneScout extends StatelessWidget {
  const IntestazioneScout({
    super.key,
    required this.titolo,
    required this.azioni,
  });
  final String titolo;
  final List<Widget> azioni;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.paddingOf(context).top;
    // Il cielo è sempre scuro: orario e batteria devono essere chiari.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: alto + 138,
        child: Stack(
          children: [
            const Positioned.fill(child: PaesaggioScout()),
            Padding(
              padding: EdgeInsets.fromLTRB(16, alto + 6, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LogoLupo(size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            titolo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                      IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: Row(children: azioni),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: StatoFoglioChip(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colore dei testi sopra la testata (sempre chiaro: il cielo è sempre scuro).
const coloreSuTestata = Colors.white;
const coloreAccento = Palette.giallo;
