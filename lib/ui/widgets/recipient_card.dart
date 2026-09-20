import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../domain/model/recipient.dart';

/// #FFEDD9, radius 20, 18 padding, 14 gap, avatar 44. The name takes the
/// remaining width and truncates; the handle sits 3 below it.
class RecipientCard extends StatelessWidget {
  const RecipientCard({
    super.key,
    required this.recipient,
    required this.onTap,
  });

  final Recipient recipient;

  /// Null while sending — nothing on that screen is tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.all(FaveMetrics.cardPad),
      decoration: BoxDecoration(
        color: FaveColors.recipientCard,
        borderRadius: BorderRadius.circular(FaveMetrics.cardRadius),
      ),
      child: Row(
        children: [
          const Avatar(size: FaveMetrics.cardAvatar),
          const SizedBox(width: FaveMetrics.cardGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipient.name,
                  style: FaveType.recipientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: FaveMetrics.cardNameToHandle),
                Text(
                  recipient.handle,
                  style: FaveType.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: FaveColors.avatarAndWaitingRing,
      shape: BoxShape.circle,
    ),
  );
}
