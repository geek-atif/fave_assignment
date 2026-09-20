import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_type.dart';
import '../../core/util/relative_time.dart';
import '../../core/util/rupees.dart';
import '../../machine/payment_state.dart';
import '../widgets/badges.dart';
import '../widgets/fave_buttons.dart';
import '../widgets/fave_shell.dart';

/// 03 · Success — what was actually paid, read from the attempt's own state
/// and never from the live fields.
class SuccessView extends StatelessWidget {
  const SuccessView({
    super.key,
    required this.state,
    required this.now,
    required this.onDone,
  });

  final Succeeded state;
  final DateTime now;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final attempt = state.attempt;
    final note = attempt.note;
    return FaveShell(
      children: [
        StatusBlock.terminal(
          children: [
            const SuccessBadge(),
            // The amount never truncates and never wraps.
            Text(
              FaveCopy.amountSent(formatRupees(attempt.amountRupees)),
              style: FaveType.successHeading,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
            ),
            Text(
              FaveCopy.successPayee(
                attempt.recipient.name,
                attempt.recipient.handle,
              ),
              style: FaveType.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (note != null && note.isNotEmpty)
              Text(
                FaveCopy.successNote(note),
                style: FaveType.successNote,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            Text(
              FaveCopy.reference(
                // The local time the terminal answer arrived.
                localTimeStamp(state.settledAt, now),
                // B1 has no id — show the key, and do not crash.
                attempt.displayReference,
              ),
              style: FaveType.caption,
              // A server id fits the designed single line. Our fallback key is
              // 36 characters and does not, and a reference you cannot read is
              // not a reference — so in B1 only, it wraps. A deliberate
              // deviation from the frame, recorded in the README.
              maxLines: attempt.reference == null ? 3 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        PrimaryCta(label: FaveCopy.successCta, onTap: onDone),
      ],
    );
  }
}
