import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_motion.dart';
import 'fave_icons.dart';

/// 88 × 88 teal disc with a white check, stroke 5, round caps.
///
/// Enters on status = success: scale 0.6 → 1.0 and opacity 0 → 1, 600 ms,
/// ease-out. Text and CTA do not animate, so only this subtree does.
class SuccessBadge extends StatefulWidget {
  const SuccessBadge({super.key});

  @override
  State<SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<SuccessBadge>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: FaveMotion.badgeIn,
  )..forward();

  late final _eased = CurvedAnimation(
    parent: _controller,
    curve: FaveMotion.badgeInCurve,
  );

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _eased,
    child: ScaleTransition(
      scale: Tween<double>(
        begin: FaveMotion.badgeFromScale,
        end: 1,
      ).animate(_eased),
      child: const _Disc(
        color: FaveColors.teal,
        child: CheckMark(
          size: FaveMetrics.badgeSize,
          stroke: FaveMetrics.badgeMarkStroke,
        ),
      ),
    ),
  );
}

/// 88 × 88 #FBEAE8 disc with a #B8433C cross. Cuts in — nothing animates.
class FailedBadge extends StatelessWidget {
  const FailedBadge({super.key});

  @override
  Widget build(BuildContext context) => const _Disc(
    color: FaveColors.failedBadge,
    child: CrossMark(
      size: FaveMetrics.badgeSize,
      stroke: FaveMetrics.badgeMarkStroke,
    ),
  );
}

/// 88 × 88, ring only, 8 thick, inside. Static — Still confirming does not spin.
class WaitingBadge extends StatelessWidget {
  const WaitingBadge({super.key});

  @override
  Widget build(BuildContext context) => const RingOutline(
    size: FaveMetrics.badgeSize,
    stroke: FaveMetrics.waitingRingStroke,
    color: FaveColors.avatarAndWaitingRing,
  );
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: FaveMetrics.badgeSize,
    height: FaveMetrics.badgeSize,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}
