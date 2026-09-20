import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../core/util/relative_time.dart';
import '../../core/util/rupees.dart';
import '../../domain/model/payment_record.dart';

/// The two most recent attempts, newest first, only ever two.
class RecentList extends StatelessWidget {
  const RecentList({super.key, required this.records, required this.now});

  final List<PaymentRecord> records;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return Text(FaveCopy.recentEmpty, style: FaveType.recentEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, record) in records.indexed)
          RecentRow(record: record, now: now, showDivider: index > 0),
      ],
    );
  }
}

/// 13 top · 13 bottom · 12 gap · 1 px #E7DFD4 divider above every row
/// except the first.
class RecentRow extends StatelessWidget {
  const RecentRow({
    super.key,
    required this.record,
    required this.now,
    required this.showDivider,
  });

  final PaymentRecord record;
  final DateTime now;
  final bool showDivider;

  /// The verb describes the attempt, not its outcome. The badge carries any
  /// uncertainty.
  String get _statusLine {
    final verb = record.outcome == RecordOutcome.failed
        ? FaveCopy.recentFailedPrefix
        : FaveCopy.recentSentPrefix;
    final when = relativeTime(record.settledAt ?? record.startedAt, now);
    return '$verb · $when';
  }

  String? get _badge => switch (record.outcome) {
    RecordOutcome.inFlight => FaveCopy.badgeChecking,
    RecordOutcome.unresolved => FaveCopy.badgeUnresolved,
    RecordOutcome.success || RecordOutcome.failed => null,
  };

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider)
          Container(
            height: FaveMetrics.dividerThickness,
            color: FaveColors.divider,
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: FaveMetrics.recentRowPadV,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The payee truncates.
                    Text(
                      record.recipientName,
                      style: FaveType.recentPayee,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _statusLine,
                            style: FaveType.recentStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: FaveMetrics.badgeGap),
                          StatusBadge(label: badge),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: FaveMetrics.recentRowGap),
              // Right-aligned, and never truncates.
              Text(
                formatRupees(record.amountRupees),
                style: FaveType.recentAmount,
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 3 vertical · 7 horizontal · radius 100 · #232323 on #FFF3EE.
/// CHECKING while a record is still in flight, UNRESOLVED once the backend no
/// longer knows the key.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      vertical: FaveMetrics.badgePadV,
      horizontal: FaveMetrics.badgePadH,
    ),
    decoration: BoxDecoration(
      color: FaveColors.notice,
      borderRadius: BorderRadius.circular(FaveMetrics.badgeRadius),
    ),
    child: Text(label, style: FaveType.recentBadge),
  );
}
