import 'package:flutter/material.dart';

/// The MooshRevolt logo for use inside the app: the Mooshimeter's pill
/// body with its chip and three copper jacks, without the app icon's dark
/// tile. It is drawn in the theme's foreground color, so it stays visible
/// on light and dark backgrounds (the tile version lives in
/// assets/branding/mooshrevolt_icon.svg).
class MooshRevoltMark extends StatelessWidget {
  const MooshRevoltMark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MooshRevolt logo',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _PillPainter(
          outline: Theme.of(context).colorScheme.onSurface,
          detailed: size >= 48,
        ),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  _PillPainter({required this.outline, required this.detailed});

  final Color outline;

  /// Large renderings add the bolt and the copper traces.
  final bool detailed;

  static const _copper = Color(0xFFE08A3C);
  static const _hole = Color(0xFF0C0F14);
  static const _bolt = Color(0xFF2F7BFF);

  @override
  void paint(Canvas canvas, Size size) {
    // The proportions of the Mooshimeter body in the app icon.
    final height = size.height * 0.94;
    final width = height * 0.3625;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      Radius.circular(width / 2),
    );
    canvas.drawRRect(body, Paint()..color = outline.withAlpha(22));
    canvas.drawRRect(
      body,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.08,
    );

    final cx = left + width / 2;
    final chip = width * 0.38;
    final chipTop = top + height * 0.13;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - chip / 2, chipTop, chip, chip),
        Radius.circular(chip * 0.15),
      ),
      Paint()..color = outline,
    );
    if (detailed) {
      final trace = Paint()
        ..color = _copper
        ..strokeWidth = width * 0.03
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        final y = chipTop + chip * (0.2 + k * 0.3);
        canvas
          ..drawLine(
            Offset(cx - width * 0.3, y),
            Offset(cx - chip / 2, y),
            trace,
          )
          ..drawLine(
            Offset(cx + chip / 2, y),
            Offset(cx + width * 0.3, y),
            trace,
          );
      }
      final s = chip * 0.8;
      final ox = cx;
      final oy = chipTop + chip / 2;
      final bolt = Path()
        ..moveTo(ox + 0.10 * s, oy - 0.50 * s)
        ..lineTo(ox - 0.30 * s, oy + 0.04 * s)
        ..lineTo(ox - 0.02 * s, oy + 0.04 * s)
        ..lineTo(ox - 0.16 * s, oy + 0.50 * s)
        ..lineTo(ox + 0.30 * s, oy - 0.08 * s)
        ..lineTo(ox + 0.03 * s, oy - 0.08 * s)
        ..close();
      canvas.drawPath(bolt, Paint()..color = _bolt);
    }

    for (final fraction in const [0.56, 0.70, 0.84]) {
      final centre = Offset(cx, top + height * fraction);
      canvas
        ..drawCircle(centre, width * 0.19, Paint()..color = _copper)
        ..drawCircle(centre, width * 0.09, Paint()..color = _hole);
    }
  }

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.outline != outline || old.detailed != detailed;
}
