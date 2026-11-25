// Genera le icone dell'app (web, iOS, Android) disegnando il lupo in codice.
// Non è un vero test: si lancia a mano con
//   flutter test tool/genera_icone_test.dart
// e riscrive i PNG delle icone.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lupetti_app/features/common/scout_art.dart';
import 'package:lupetti_app/theme/app_theme.dart';

Future<ui.Image> _disegna(int px, {double lupo = 0.62}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final s = px.toDouble();
  // Cielo notturno.
  c.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, s), [Palette.boscoNotte, const Color(0xFF1F5E43)]),
  );
  // Stelle.
  final rnd = math.Random(7);
  for (var i = 0; i < 14; i++) {
    c.drawCircle(Offset(rnd.nextDouble() * s, rnd.nextDouble() * s * 0.5), s * (0.004 + rnd.nextDouble() * 0.006),
        Paint()..color = Colors.white.withValues(alpha: 0.7));
  }
  // Colline in basso.
  final colle = Path()
    ..moveTo(0, s * 0.82)
    ..quadraticBezierTo(s * 0.35, s * 0.70, s * 0.7, s * 0.80)
    ..quadraticBezierTo(s * 0.9, s * 0.85, s, s * 0.78)
    ..lineTo(s, s)
    ..lineTo(0, s)
    ..close();
  c.drawPath(colle, Paint()..color = Palette.bosco);
  // Lupo al centro.
  final l = s * lupo;
  c.save();
  c.translate((s - l) / 2, (s - l) / 2 - s * 0.03);
  const LupoPainter().paint(c, Size(l, l));
  c.restore();
  return rec.endRecording().toImage(px, px);
}

Future<void> _scrivi(String percorso, int px, {double lupo = 0.62}) async {
  final img = await _disegna(px, lupo: lupo);
  final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
  File(percorso)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes.buffer.asUint8List());
}

void main() {
  testWidgets('genera le icone', (t) async {
    await t.runAsync(() async {
      // Web / PWA.
      await _scrivi('web/icons/Icon-192.png', 192);
      await _scrivi('web/icons/Icon-512.png', 512);
      await _scrivi('web/icons/Icon-maskable-192.png', 192, lupo: 0.48);
      await _scrivi('web/icons/Icon-maskable-512.png', 512, lupo: 0.48);
      await _scrivi('web/favicon.png', 64);

      // iOS: tutte le misure già presenti nel set.
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      for (final f in dir.listSync().whereType<File>()) {
        final m = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png$').firstMatch(f.path);
        if (m == null) continue;
        final px = (double.parse(m.group(1)!) * int.parse(m.group(2)!)).round();
        await _scrivi(f.path, px);
      }

      // Android.
      const android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
      for (final e in android.entries) {
        await _scrivi('android/app/src/main/res/mipmap-${e.key}/ic_launcher.png', e.value);
      }
    });
  });
}
