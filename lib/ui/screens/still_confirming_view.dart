import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../widgets/badges.dart';
import '../widgets/fave_buttons.dart';
import '../widgets/fave_shell.dart';
import '../widgets/pay_widgets.dart';

/// 05 · Still confirming — ten seconds passed with no answer. Not terminal,
/// not a failure, and the copy says neither.
class StillConfirmingView extends StatelessWidget {
  const StillConfirmingView({
    super.key,
    required this.checking,
    required this.onGoToHome,
    required this.onCheckStatus,
  });

  /// 05b — a Check status again call is in flight.
  final bool checking;

  final VoidCallback onGoToHome;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) => FaveShell(
    children: [
      StatusBlock.terminal(
        children: [
          const WaitingBadge(),
          Text(
            FaveCopy.stillConfirmingHeading,
            style: FaveType.terminalHeading,
            textAlign: TextAlign.center,
          ),
          SizedBox(
            width: FaveMetrics.bodyCopyWidth,
            child: Text(
              FaveCopy.stillConfirmingBody,
              style: FaveType.body,
              textAlign: TextAlign.center,
            ),
          ),
          // The only place in the flow that tells the user what happens to
          // their money. Its copy is fixed.
          const NoticeBox(text: FaveCopy.stillConfirmingNotice),
        ],
      ),
      PrimaryCta(label: FaveCopy.ctaGoToHome, onTap: onGoToHome),
      const SizedBox(height: FaveMetrics.ctaToLink),
      if (checking)
        const FaveLink.running(label: FaveCopy.linkChecking)
      else
        FaveLink(label: FaveCopy.linkCheckStatus, onTap: onCheckStatus),
    ],
  );
}
