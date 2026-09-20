import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';

/// #FFF3EE, radius 14, 14 vertical · 16 horizontal, full width of content.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      vertical: FaveMetrics.noticePadV,
      horizontal: FaveMetrics.noticePadH,
    ),
    decoration: BoxDecoration(
      color: FaveColors.notice,
      borderRadius: BorderRadius.circular(FaveMetrics.noticeRadius),
    ),
    child: Text(text, style: FaveType.noticeText, textAlign: TextAlign.center),
  );
}
