import 'package:flutter/widgets.dart';

import '../../core/design/fave_metrics.dart';

/// 56 top · 32 sides · 32 bottom, all states. The bottom padding grows with
/// the keyboard so the CTA is never behind it.
class FaveShell extends StatelessWidget {
  const FaveShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: FaveMetrics.screenTop,
      left: FaveMetrics.screenSide,
      right: FaveMetrics.screenSide,
      bottom:
          FaveMetrics.screenBottom + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Badge or ring, heading and body, vertically centred between the top
/// content and the CTA. 22 gap on Confirming, 20 everywhere else.
class StatusBlock extends StatelessWidget {
  const StatusBlock({super.key, required this.gap, required this.children});

  const StatusBlock.confirming({super.key, required this.children})
    : gap = FaveMetrics.statusGapConfirming;

  const StatusBlock.terminal({super.key, required this.children})
    : gap = FaveMetrics.statusGapOther;

  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) SizedBox(height: gap),
            child,
          ],
        ],
      ),
    ),
  );
}
