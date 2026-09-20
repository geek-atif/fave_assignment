import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import 'amount_field.dart';

/// Optional, one line, at most 40 characters — no counter, the field simply
/// stops accepting input.
class NoteField extends StatelessWidget {
  const NoteField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  static const maxCharacters = 40;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      EditableText(
        controller: controller,
        focusNode: focusNode,
        readOnly: !enabled,
        style: FaveType.noteField,
        cursorColor: FaveColors.textPrimary,
        backgroundCursorColor: FaveColors.placeholder,
        selectionColor: FaveColors.avatarAndWaitingRing,
        maxLines: 1,
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(maxCharacters)],
      ),
      const SizedBox(height: FaveMetrics.amountLineGap),
      // "Underline as the amount's" — same rule, and it follows focus too.
      // The note has nothing to be invalid about, so it is never the error red.
      FieldUnderline(
        color: focusNode.hasFocus ? FaveColors.link : FaveColors.fieldUnderline,
      ),
    ],
  );
}

/// `EditableText` cannot draw its own placeholder, so it is stacked behind
/// one. Both fields need this, which is why it is not inside either of them.
class PlaceholderStack extends StatelessWidget {
  const PlaceholderStack({
    super.key,
    required this.placeholder,
    required this.style,
    required this.controller,
    required this.child,
  });

  final String placeholder;
  final TextStyle style;
  final TextEditingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Align(
          alignment: Alignment.topLeft,
          child: IgnorePointer(
            child: Opacity(
              opacity: controller.text.isEmpty ? 1 : 0,
              child: Text(placeholder, style: style, maxLines: 1),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
