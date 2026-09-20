import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../domain/model/recipient.dart';
import '../widgets/fave_icons.dart';
import '../widgets/pay_widgets.dart';
import 'fave_sheet.dart';

/// Five seeded people. Pick one; no search, no adding.
Future<Recipient?> showRecipientSheet(
  BuildContext context,
  Recipient selected,
) => showFaveSheet<Recipient>(
  context: context,
  builder: (sheetContext) => FaveSheetShell(
    title: FaveCopy.recipientSheetTitle,
    subtitle: FaveCopy.recipientSheetSubtitle,
    children: [
      for (final recipient in SeededRecipients.all)
        _RecipientRow(
          recipient: recipient,
          selected: recipient == selected,
          onTap: () => Navigator.of(sheetContext).pop(recipient),
        ),
    ],
  ),
);

/// 9 vertical padding · 14 gap · avatar 36 · ✓ on the selected row in #5E6DFF.
class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.recipient,
    required this.selected,
    required this.onTap,
  });

  final Recipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FaveMetrics.sheetRowPadV),
      child: Row(
        children: [
          const Avatar(size: FaveMetrics.sheetAvatar),
          const SizedBox(width: FaveMetrics.sheetRowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipient.name,
                  style: FaveType.sheetRowName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  recipient.handle,
                  style: FaveType.sheetRowHandle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (selected) ...[
            const SizedBox(width: FaveMetrics.sheetRowGap),
            const CheckMark(size: 18, stroke: 2, color: FaveColors.link),
          ],
        ],
      ),
    ),
  );
}
