import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Illustrazioni del branco, tutte disegnate in codice (nessun file immagine).

// ---------------------------------------------------------------------------
// Paesaggio notturno per la testata: luna, pini, tende e falò.
// ---------------------------------------------------------------------------
class PaesaggioPainter extends CustomPainter {
  PaesaggioPainter({required this.terra});

  /// Colore del primo piano: uguale allo sfondo della pagina, così la testata
  /// "appoggia" sul terreno senza stacco.
  final Color terra;

  static const _stelle = <(double, double, double)>[
    (0.06, 0.14, 1.2),
    (0.17, 0.30, 0.9),
    (0.28, 0.10, 1.3),
    (0.41, 0.22, 0.9),
    (0.52, 0.08, 1.1),
    (0.63, 0.26, 1.0),
    (0.71, 0.12, 1.3),
    (0.92, 0.36, 0.9),
    (0.34, 0.36, 0.8),
    (0.58, 0.40, 0.8),
  ];

  double _colline(Size s, double x, double base, double ampiezza, double fase) =>
      s.height * base + math.sin(x / s.width * math.pi * 2 + fase) * s.height * ampiezza;

  Path _profilo(Size s, double base, double ampiezza, double fase) {
    final p = Path()..moveTo(0, s.height);
    for (var i = 0; i <= 48; i++) {
      final x = s.width * i / 48;
      p.lineTo(x, _colline(s, x, base, ampiezza, fase));
    }
    return p
      ..lineTo(s.width, s.height)
      ..close();
  }

  void _pino(Canvas c, double cx, double base, double h, Color col) {
    final paint = Paint()..color = col;
    for (var i = 0; i < 3; i++) {
      final larg = h * (0.42 - i * 0.09);
      final y0 = base - h * (0.30 + i * 0.27);
      final y1 = y0 - h * 0.42;
      c.drawPath(
        Path()
          ..moveTo(cx - larg, y0)
          ..lineTo(cx, y1)
          ..lineTo(cx + larg, y0)
          ..close(),
        paint,
      );
    }
    c.drawRect(Rect.fromLTWH(cx - h * 0.04, base - h * 0.30, h * 0.08, h * 0.30), paint);
  }

  void _tenda(Canvas c, double cx, double base, double w, {required Color tela, required Color ombra}) {
    final h = w * 0.78;
    c.drawPath(
      Path()
        ..moveTo(cx - w / 2, base)
        ..lineTo(cx, base - h)
        ..lineTo(cx + w / 2, base)
        ..close(),
      Paint()..color = tela,
    );
    c.drawPath(
      Path()
        ..moveTo(cx, base - h)
        ..lineTo(cx + w / 2, base)
        ..lineTo(cx + w * 0.08, base)
        ..close(),
      Paint()..color = ombra,
    );
    c.drawPath(
      Path()
        ..moveTo(cx - w * 0.12, base)
        ..lineTo(cx, base - h * 0.48)
        ..lineTo(cx + w * 0.12, base)
        ..close(),
      Paint()..color = Palette.boscoNotte,
    );
    // Bandierina sulla cima.
    final asta = Paint()
      ..color = tela
      ..strokeWidth = 1.4;
    c.drawLine(Offset(cx, base - h), Offset(cx, base - h - w * 0.26), asta);
    c.drawPath(
      Path()
        ..moveTo(cx, base - h - w * 0.26)
        ..lineTo(cx + w * 0.2, base - h - w * 0.20)
        ..lineTo(cx, base - h - w * 0.14)
        ..close(),
      Paint()..color = Palette.giallo,
    );
  }

  void _falo(Canvas c, double cx, double base, double r) {
    c.drawCircle(
      Offset(cx, base - r * 0.6),
      r * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [Palette.giallo.withValues(alpha: 0.38), Palette.giallo.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, base - r * 0.6), radius: r * 2.6)),
    );
    Path fiamma(double k) => Path()
      ..moveTo(cx, base - r * 2.0 * k)
      ..quadraticBezierTo(cx + r * 0.9 * k, base - r * 0.7 * k, cx + r * 0.5 * k, base)
      ..lineTo(cx - r * 0.5 * k, base)
      ..quadraticBezierTo(cx - r * 0.9 * k, base - r * 0.7 * k, cx, base - r * 2.0 * k)
      ..close();
    c.drawPath(fiamma(1), Paint()..color = const Color(0xFFE2792D));
    c.drawPath(fiamma(0.58), Paint()..color = Palette.giallo);
    final legna = Paint()
      ..color = const Color(0xFF3B2A1A)
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx - r * 0.9, base + r * 0.15), Offset(cx + r * 0.9, base - r * 0.05), legna);
    c.drawLine(Offset(cx - r * 0.9, base - r * 0.05), Offset(cx + r * 0.9, base + r * 0.15), legna);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Cielo notturno.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2218), Color(0xFF1B5139)],
        ).createShader(Offset.zero & size),
    );
    for (final (fx, fy, r) in _stelle) {
      canvas.drawCircle(Offset(w * fx, h * fy), r, Paint()..color = Colors.white.withValues(alpha: 0.75));
    }
    // Colline di fondo con pini.
    canvas.drawPath(_profilo(size, 0.64, 0.045, 0.6), Paint()..color = const Color(0xFF14412D));
    for (final fx in [0.04, 0.10, 0.17, 0.26, 0.34, 0.45, 0.55, 0.96]) {
      final x = w * fx;
      _pino(
        canvas,
        x,
        _colline(size, x, 0.64, 0.045, 0.6) + 3,
        h * (0.20 + (fx * 13 % 3) * 0.02),
        const Color(0xFF0F3324),
      );
    }

    // Colline di mezzo: campo con tende e falò.
    canvas.drawPath(_profilo(size, 0.80, 0.03, 2.2), Paint()..color = Palette.bosco);
    // Tende e falò stanno a destra: a sinistra c'è il testo della testata.
    final yT1 = _colline(size, w * 0.73, 0.80, 0.03, 2.2);
    final yT2 = _colline(size, w * 0.86, 0.80, 0.03, 2.2);
    _tenda(canvas, w * 0.73, yT1 + 2, h * 0.30, tela: Palette.tela, ombra: const Color(0xFFD9C58C));
    _tenda(canvas, w * 0.86, yT2 + 2, h * 0.23, tela: const Color(0xFFE9D9A2), ombra: const Color(0xFFCDB879));
    _falo(canvas, w * 0.955, _colline(size, w * 0.955, 0.80, 0.03, 2.2) + 2, h * 0.06);
    for (final fx in [0.02, 0.09, 0.57]) {
      final x = w * fx;
      _pino(canvas, x, _colline(size, x, 0.80, 0.03, 2.2) + 3, h * 0.27, Palette.boscoNotte);
    }

    // Primo piano = colore della pagina.
    canvas.drawPath(_profilo(size, 0.955, 0.012, 1.0), Paint()..color = terra);
  }

  @override
  bool shouldRepaint(PaesaggioPainter old) => old.terra != terra;
}

class PaesaggioScout extends StatelessWidget {
  const PaesaggioScout({super.key});
  @override
  Widget build(BuildContext context) {
    final terra = Theme.of(context).colorScheme.surface;
    return CustomPaint(
      painter: PaesaggioPainter(terra: terra),
      size: Size.infinite,
    );
  }
}

// ---------------------------------------------------------------------------
// Testa di lupo stilizzata (logo).
// ---------------------------------------------------------------------------
class LupoPainter extends CustomPainter {
  const LupoPainter({this.pelo = Palette.giallo, this.contorno = Palette.boscoNotte});
  final Color pelo;
  final Color contorno;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 100;
    Offset o(double x, double y) => Offset(x * k, y * k);
    Path poly(List<(double, double)> pts) {
      final p = Path()..moveTo(pts.first.$1 * k, pts.first.$2 * k);
      for (final q in pts.skip(1)) {
        p.lineTo(q.$1 * k, q.$2 * k);
      }
      return p..close();
    }

    final testa = poly(const [(50, 94), (30, 76), (12, 46), (20, 8), (42, 30), (58, 30), (80, 8), (88, 46), (70, 76)]);
    canvas.drawPath(testa, Paint()..color = pelo);
    canvas.drawPath(
      testa,
      Paint()
        ..color = contorno
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * k
        ..strokeJoin = StrokeJoin.round,
    );
    // Interno delle orecchie.
    final orecchie = Paint()..color = contorno.withValues(alpha: 0.35);
    canvas.drawPath(poly(const [(22, 20), (34, 34), (20, 42)]), orecchie);
    canvas.drawPath(poly(const [(78, 20), (66, 34), (80, 42)]), orecchie);
    // Muso chiaro.
    canvas.drawPath(
      poly(const [(38, 62), (62, 62), (57, 82), (50, 88), (43, 82)]),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    // Occhi obliqui.
    final occhio = Paint()..color = contorno;
    canvas.drawPath(poly(const [(30, 50), (43, 54), (40, 58), (30, 55)]), occhio);
    canvas.drawPath(poly(const [(70, 50), (57, 54), (60, 58), (70, 55)]), occhio);
    // Naso.
    canvas.drawPath(poly(const [(44, 68), (56, 68), (50, 76)]), occhio);
    canvas.drawLine(
      o(50, 76),
      o(50, 82),
      Paint()
        ..color = contorno
        ..strokeWidth = 2 * k
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(LupoPainter old) => old.pelo != pelo || old.contorno != contorno;
}

class LogoLupo extends StatelessWidget {
  const LogoLupo({super.key, this.size = 40, this.pelo = Palette.giallo, this.contorno = Palette.boscoNotte});
  final double size;
  final Color pelo;
  final Color contorno;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: LupoPainter(pelo: pelo, contorno: contorno),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tenda con pino e luna: stato vuoto.
// ---------------------------------------------------------------------------
class TendaPainter extends CustomPainter {
  const TendaPainter({
    required this.tela,
    required this.ombra,
    required this.porta,
    required this.terreno,
    required this.pino,
  });
  final Color tela, ombra, porta, terreno, pino;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final suolo = h * 0.86;
    canvas.drawOval(Rect.fromLTWH(w * 0.04, suolo - h * 0.05, w * 0.92, h * 0.12), Paint()..color = terreno);
    // Pino.
    final pp = Paint()..color = pino;
    for (var i = 0; i < 3; i++) {
      final larg = w * (0.13 - i * 0.025);
      final y0 = suolo - h * (0.10 + i * 0.17);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.80 - larg, y0)
          ..lineTo(w * 0.80, y0 - h * 0.26)
          ..lineTo(w * 0.80 + larg, y0)
          ..close(),
        pp,
      );
    }
    // Tenda.
    final cx = w * 0.40, tw = w * 0.56, th = h * 0.62;
    canvas.drawPath(
      Path()
        ..moveTo(cx - tw / 2, suolo)
        ..lineTo(cx, suolo - th)
        ..lineTo(cx + tw / 2, suolo)
        ..close(),
      Paint()..color = tela,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, suolo - th)
        ..lineTo(cx + tw / 2, suolo)
        ..lineTo(cx + tw * 0.08, suolo)
        ..close(),
      Paint()..color = ombra,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx - tw * 0.13, suolo)
        ..lineTo(cx, suolo - th * 0.52)
        ..lineTo(cx + tw * 0.13, suolo)
        ..close(),
      Paint()..color = porta,
    );
    canvas.drawLine(
      Offset(cx, suolo - th),
      Offset(cx, suolo - th - h * 0.16),
      Paint()
        ..color = porta
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, suolo - th - h * 0.16)
        ..lineTo(cx + w * 0.11, suolo - th - h * 0.11)
        ..lineTo(cx, suolo - th - h * 0.06)
        ..close(),
      Paint()..color = Palette.giallo,
    );
  }

  @override
  bool shouldRepaint(TendaPainter old) => false;
}

/// Stato vuoto illustrato: una tenda, un testo e (facoltativo) un'azione.
class TendaVuota extends StatelessWidget {
  const TendaVuota(this.titolo, {super.key, this.dettaglio, this.azione});
  final String titolo;
  final String? dettaglio;
  final Widget? azione;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 110,
            child: CustomPaint(
              painter: TendaPainter(
                tela: Palette.tela,
                ombra: const Color(0xFFD9C58C),
                porta: Palette.boscoNotte,
                terreno: s.primaryContainer,
                pino: s.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(titolo, textAlign: TextAlign.center, style: t.titleMedium),
          if (dettaglio != null) ...[
            const SizedBox(height: 4),
            Text(
              dettaglio!,
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
            ),
          ],
          if (azione != null) ...[const SizedBox(height: 16), azione!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fazzolettone: il triangolo della sestiglia.
// ---------------------------------------------------------------------------
/// Macchie nere (pezzati) dentro un'area [r]: posizioni fisse, in proporzione.
void disegnaMacchie(Canvas canvas, Rect r, {Color colore = const Color(0xFF1E211F)}) {
  final pt = Paint()..color = colore;
  void m(double x, double y, double rx, double ry) => canvas.drawOval(
    Rect.fromCenter(
      center: Offset(r.left + r.width * x, r.top + r.height * y),
      width: r.width * rx,
      height: r.height * ry,
    ),
    pt,
  );
  m(0.28, 0.30, 0.26, 0.20);
  m(0.72, 0.26, 0.18, 0.22);
  m(0.52, 0.55, 0.22, 0.18);
  m(0.30, 0.74, 0.16, 0.20);
  m(0.74, 0.70, 0.20, 0.16);
}

class FazzolettonePainter extends CustomPainter {
  const FazzolettonePainter(this.colore, this.bordo, {this.macchie = false});
  final Color colore, bordo;
  final bool macchie;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(w * 0.06, h * 0.14)
      ..quadraticBezierTo(w * 0.5, h * 0.30, w * 0.94, h * 0.14)
      ..lineTo(w * 0.54, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h * 0.99, w * 0.46, h * 0.92)
      ..close();
    canvas.drawPath(p, Paint()..color = colore);
    if (macchie) {
      canvas.save();
      canvas.clipPath(p);
      disegnaMacchie(canvas, Rect.fromLTWH(w * 0.1, h * 0.15, w * 0.8, h * 0.7));
      canvas.restore();
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = bordo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.12), w * 0.085, Paint()..color = bordo);
  }

  @override
  bool shouldRepaint(FazzolettonePainter old) => old.colore != colore || old.bordo != bordo || old.macchie != macchie;
}

class Fazzolettone extends StatelessWidget {
  const Fazzolettone({super.key, required this.colore, this.size = 44, this.macchie = false});
  final Color colore;
  final bool macchie;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: FazzolettonePainter(
        colore,
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.9),
        macchie: macchie,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Avatar con le iniziali.
// ---------------------------------------------------------------------------
String iniziali(String nome) {
  final parti = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parti.isEmpty) return '?';
  if (parti.length == 1) return parti.first.substring(0, 1).toUpperCase();
  return (parti.first.substring(0, 1) + parti.last.substring(0, 1)).toUpperCase();
}

class AvatarIniziali extends StatelessWidget {
  const AvatarIniziali(
    this.nome, {
    super.key,
    required this.colore,
    required this.testo,
    this.size = 40,
    this.macchie = false,
  });
  final bool macchie;
  final String nome;
  final Color colore, testo;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colore,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (macchie)
          Positioned.fill(
            child: ClipOval(child: CustomPaint(painter: _MacchiePainter())),
          ),
        Text(
          iniziali(nome),
          style: TextStyle(
            color: testo,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
            shadows: macchie ? const [Shadow(color: Colors.white, blurRadius: 3)] : null,
          ),
        ),
      ],
    ),
  );
}

class _MacchiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => disegnaMacchie(canvas, Offset.zero & size);
  @override
  bool shouldRepaint(_MacchiePainter old) => false;
}
