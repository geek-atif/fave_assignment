import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../core/util/rupees.dart';
import '../../machine/payment_state.dart';
import '../widgets/fave_shell.dart';
import '../widgets/pay_widgets.dart';

/// 02 · Confirming — the countdown ring while the app polls for a result.
///
/// The ring is passed in rather than built here: counting down and running to
/// zero are two different widgets, and which one to show is the machine's
/// decision, not this view's.
class ConfirmingView extends StatelessWidget {
  const ConfirmingView({super.key, required this.attempt, required this.ring});

  final Attempt attempt;
  final Widget ring;

  @override
  Widget build(BuildContext context) =>
      // Nothing is tappable. There is no cancel: money may already be in flight.
      IgnorePointer(
        child: FaveShell(
          children: [
            Column(
              children: [
                const SectionLabel(FaveCopy.payingLabel),
                const SizedBox(height: FaveMetrics.summaryGap),
                _SummaryLine(attempt: attempt),
              ],
            ),
            StatusBlock.confirming(
              children: [
                ring,
                Text(
                  FaveCopy.confirmingHeading,
                  style: FaveType.confirmingHeading,
                ),
                SizedBox(
                  width: FaveMetrics.bodyCopyWidth,
                  child: Text(
                    FaveCopy.confirmingBody,
                    style: FaveType.body,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            Text(
              FaveCopy.confirmingFootnote,
              style: FaveType.footnote,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

/// The name truncates — but the amount never does. That order of priority is
/// the requirement, so the amount is laid out first and inflexibly.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.attempt});

  final Attempt attempt;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        flex: 0,
        child: Text(
          '${formatRupees(attempt.amountRupees)} to ',
          style: FaveType.summaryLine,
          maxLines: 1,
          softWrap: false,
        ),
      ),
      Flexible(
        child: Text(
          attempt.recipient.name,
          style: FaveType.summaryLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
