import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    // retry disattivato: gli errori (rete, login) li gestisce la UI, non Riverpod.
    ProviderScope(retry: (_, _) => null, child: const LupettiApp()),
  );
}
