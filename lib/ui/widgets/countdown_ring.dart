import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_motion.dart';
import '../../core/design/fave_type.dart';
import '../../core/time/clock.dart';

/// 120 × 120 · 8 thick · starts at 12 o'clock, clockwise · butt ends.
///
/// The sweep is a function of wall-clock time sampled each frame, never of an
/// animation that could pause. Only the painter and the seconds label are
/// wired to the ticker — the screen around them is not rebuilt.
class CountdownRing extends StatefulWidget {
  /// Counting down towards [deadline], read from [clock] each frame.
  const CountdownRing.counting({
    super.key,
    required this.clock,
    required this.deadline,
  }) : exitFrom = null;

  /// The one-shot exit: from [exitFrom] to zero over 250 ms, ease-out.
  const CountdownRing.exiting({super.key, required this.exitFrom})
    : clock = null,
      deadline = null;

  final Clock? clock;
  final DateTime? deadline;
  final double? exitFrom;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
        // Not Single: the counting ring and the exit tween share this State when
        // one replaces the other, and that is two tickers over its lifetime.
        with
        TickerProviderStateMixin {
  /// The single value both the painter and the label listen to. Changing it
  /// repaints the arc and the two glyphs, and nothing else.
  final _fraction = ValueNotifier<double>(1);

  Ticker? _ticker;
  AnimationController? _exit;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.exitFrom != widget.exitFrom || old.deadline != widget.deadline) {
      _stop();
      _start();
    }
  }

  void _start() {
    final exitFrom = widget.exitFrom;
    if (exitFrom != null) {
      final controller = AnimationController(
        vsync: this,
        duration: FaveMotion.ringExit,
      );
      final tween = Tween<double>(begin: exitFrom, end: 0).animate(
        CurvedAnimation(parent: controller, curve: FaveMotion.ringExitCurve),
      );
      // The label follows the sweep down and must read 0 on the final frame.
      tween.addListener(() => _fraction.value = tween.value);
      _fraction.value = exitFrom;
      _exit = controller;
      controller.forward();
      return;
    }
    _sample();
    _ticker = createTicker((_) => _sample())..start();
  }

  void _sample() {
    final clock = widget.clock;
    final deadline = widget.deadline;
    if (clock == null || deadline == null) {
      return;
    }
    final left = deadline.difference(clock.now()).inMicroseconds;
    _fraction.value = (left / FaveMotion.countdown.inMicroseconds).clamp(
      0.0,
      1.0,
    );
  }

  void _stop() {
    _ticker?.dispose();
    _ticker = null;
    _exit?.dispose();
    _exit = null;
  }

  @override
  void dispose() {
    _stop();
    _fraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Counting down, `9.2 s left` still reads "10s" would be wrong, so round
    // up; on the way out `0.4 s` must read "0", so round down.
    final exiting = widget.exitFrom != null;
    return SizedBox.square(
      dimension: FaveMetrics.ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              size: const Size.square(FaveMetrics.ringSize),
              painter: _RingSweepPainter(_fraction),
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _fraction,
            builder: (_, f, _) {
              final tenths = f * FaveMotion.countdown.inSeconds;
              final seconds = exiting ? tenths.floor() : tenths.ceil();
              return Text(
                '${seconds.clamp(0, FaveMotion.countdown.inSeconds)}s',
                style: FaveType.ringSeconds,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RingSweepPainter extends CustomPainter {
  _RingSweepPainter(this.fraction) : super(repaint: fraction);

  final ValueListenable<double> fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = FaveMetrics.ringStroke;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.width - stroke) / 2,
    );
    canvas.drawCircle(
      rect.center,
      rect.width / 2,
      Paint()
        ..color = FaveColors.ringTrack
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );
    final sweep = fraction.value.clamp(0.0, 1.0) * 2 * math.pi;
    if (sweep <= 0) {
      return;
    }
    canvas.drawArc(
      rect,
      -math.pi / 2, // 12 o'clock
      sweep, // clockwise
      false,
      Paint()
        ..color = FaveColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_RingSweepPainter old) => old.fraction != fraction;
}
