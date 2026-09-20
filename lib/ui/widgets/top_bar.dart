import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import 'fave_icons.dart';

/// Chevron, title, then the chip pushed to the right edge. 14 gap.
class PayTopBar extends StatelessWidget {
  const PayTopBar({
    super.key,
    required this.chipLabel,
    required this.onChip,
    required this.onBack,
    this.chevronVisible = true,
  });

  final String chipLabel;
  final VoidCallback? onChip;
  final VoidCallback? onBack;

  /// Hidden in Sending: opacity 0, keeps its space.
  final bool chevronVisible;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Opacity(
        opacity: chevronVisible ? 1 : 0,
        child: GestureDetector(
          onTap: chevronVisible ? onBack : null,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: 22,
            height: 26,
            child: Center(child: BackArrow()),
          ),
        ),
      ),
      const SizedBox(width: FaveMetrics.topBarGap),
      Text(FaveCopy.payTitle, style: FaveType.screenTitle),
      const Spacer(),
      const SizedBox(width: FaveMetrics.topBarGap),
      BackendChip(label: chipLabel, onTap: onChip),
    ],
  );
}

/// 6 vertical · 12 / 10 horizontal · radius 100 · fill #F5EFE6, 1 px #D3C8B8.
/// Opens the Backend behaviour sheet.
class BackendChip extends StatelessWidget {
  const BackendChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.only(
        top: FaveMetrics.chipPadV,
        bottom: FaveMetrics.chipPadV,
        left: FaveMetrics.chipPadLeft,
        right: FaveMetrics.chipPadRight,
      ),
      decoration: BoxDecoration(
        color: FaveColors.chipFill,
        borderRadius: BorderRadius.circular(FaveMetrics.chipRadius),
        border: Border.all(color: FaveColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${FaveCopy.chipPrefix}$label',
            style: FaveType.chipLabel,
            maxLines: 1,
          ),
          const SizedBox(width: FaveMetrics.chipLabelGap),
          const ChevronDown(),
        ],
      ),
    ),
  );
}

/// 11 / 14 / +1.2 SemiBold, uppercase — AMOUNT, PAYING, RECENT.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: FaveType.sectionLabel);
}
