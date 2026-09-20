import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';

/// Full width · 17 vertical padding · radius 100 · #0FBAB0.
/// Sending: 55% opacity. Invalid amount: 40%.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    required this.onTap,
    this.opacity = 1,
  });

  /// Disabled — 40% — reads "Pay" and does nothing.
  const PrimaryCta.disabled({super.key, required this.label})
    : onTap = null,
      opacity = 0.4;

  /// Sending — 55% — reads "Paying…" and does nothing.
  const PrimaryCta.sending({super.key, required this.label})
    : onTap = null,
      opacity = 0.55;

  final String label;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: FaveMetrics.ctaPadV),
      decoration: BoxDecoration(
        color: FaveColors.teal.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(FaveMetrics.ctaRadius),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: FaveType.ctaLabel,
        maxLines: 1,
        // The amount on the CTA never truncates.
        overflow: TextOverflow.visible,
        softWrap: false,
      ),
    ),
  );
}

/// 14 / 18 Medium, underlined, #5E6DFF. "Checking…" is #7A7877 and not
/// underlined, and is not tappable.
class FaveLink extends StatelessWidget {
  const FaveLink({super.key, required this.label, required this.onTap});

  const FaveLink.running({super.key, required this.label}) : onTap = null;

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: onTap == null ? FaveType.linkChecking : FaveType.link,
    ),
  );
}
