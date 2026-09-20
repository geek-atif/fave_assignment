import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';

/// The four marks in the flow, drawn rather than set in a font: Onest has no
/// glyph we can rely on for any of them, and a stroke weight is a spec value.
class BackArrow extends StatelessWidget {
  const BackArrow({
    super.key,
    this.size = 22,
    this.color = FaveColors.textPrimary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _BackArrowPainter(color));
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final mid = s / 2;
    final left = s * 0.17;
    final right = s * 0.83;
    final head = s * 0.22;
    canvas
      ..drawLine(Offset(left, mid), Offset(right, mid), paint)
      ..drawLine(Offset(left, mid), Offset(left + head, mid - head), paint)
      ..drawLine(Offset(left, mid), Offset(left + head, mid + head), paint);
  }

  @override
  bool shouldRepaint(_BackArrowPainter old) => old.color != color;
}

/// The ▾ on the backend chip.
class ChevronDown extends StatelessWidget {
  const ChevronDown({
    super.key,
    this.size = 8,
    this.color = FaveColors.textPrimary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size * 1.4, size),
    painter: _ChevronDownPainter(color),
  );
}

class _ChevronDownPainter extends CustomPainter {
  const _ChevronDownPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.25)
      ..lineTo(size.width / 2, size.height * 0.8)
      ..lineTo(size.width, size.height * 0.25);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronDownPainter old) => old.color != color;
}

/// The authoring viewBox of the exported badge SVGs. Path coordinates below
/// are copied from them verbatim and scaled from this, so the marks are the
/// designer's geometry rather than an eyeballed approximation — and they still
/// scale to any size the caller asks for.
const _svgViewBox = 88.0;

/// The ✓ inside the success badge, and the tick on the selected recipient.
///
/// `M28 45 L39 56 L61 33`, round cap and join — Badge slot.svg.
class CheckMark extends StatelessWidget {
  const CheckMark({
    super.key,
    required this.size,
    required this.stroke,
    this.color = FaveColors.onTeal,
  });

  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CheckPainter(color, stroke),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _svgViewBox;
    final path = Path()
      ..moveTo(28 * k, 45 * k)
      ..lineTo(39 * k, 56 * k)
      ..lineTo(61 * k, 33 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// The ✕ inside the failed badge.
///
/// `M32 32 L56 56` and `M56 32 L32 56`, round cap — failed.svg.
class CrossMark extends StatelessWidget {
  const CrossMark({
    super.key,
    required this.size,
    required this.stroke,
    this.color = FaveColors.failedMark,
  });

  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _CrossPainter(color, stroke),
  );
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _svgViewBox;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(32 * k, 32 * k), Offset(56 * k, 56 * k), paint)
      ..drawLine(Offset(56 * k, 32 * k), Offset(32 * k, 56 * k), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) =>
      old.color != color || old.stroke != stroke;
}

/// A ring with no fill — the avatar background, and the Still confirming badge.
class RingOutline extends StatelessWidget {
  const RingOutline({
    super.key,
    required this.size,
    required this.stroke,
    required this.color,
  });

  final double size;
  final double stroke;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _RingPainter(color, stroke),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color, this.stroke);

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // 8 thick, inside: the stroke sits within the 88 box, not straddling it.
    final r = (size.width - stroke) / 2;
    canvas.drawCircle(
      size.center(Offset.zero),
      math.max(r, 0),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.stroke != stroke;
}
