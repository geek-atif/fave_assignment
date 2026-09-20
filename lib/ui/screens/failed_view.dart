import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../widgets/badges.dart';
import '../widgets/fave_buttons.dart';
import '../widgets/fave_shell.dart';

/// 04 · Failed — the money never left. Terminal for this screen; a later
/// success push does not flip it.
class FailedView extends StatelessWidget {
  const FailedView({
    super.key,
    required this.onTryAgain,
    required this.onGoBack,
  });

  final VoidCallback onTryAgain;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) => FaveShell(
    children: [
      StatusBlock.terminal(
        children: [
          const FailedBadge(),
          Text(
            FaveCopy.failedHeading,
            style: FaveType.terminalHeading,
            textAlign: TextAlign.center,
          ),
          // Only ever shown for a terminal failed — never for a timeout.
          Text(
            FaveCopy.failedSubline,
            style: FaveType.failedSubline,
            textAlign: TextAlign.center,
          ),
          Text(
            FaveCopy.failedReasonDeclined,
            style: FaveType.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      // Try again asks the machine for a NEW key: a new payment, not a resend.
      PrimaryCta(label: FaveCopy.ctaTryAgain, onTap: onTryAgain),
      const SizedBox(height: FaveMetrics.ctaToLink),
      FaveLink(label: FaveCopy.linkGoBack, onTap: onGoBack),
    ],
  );
}
