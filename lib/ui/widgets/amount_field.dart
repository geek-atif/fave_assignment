import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/design/fave_colors.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../core/util/rupees.dart';
import '../../domain/model/amount.dart';

/// Whole rupees only. Numeric keyboard, no decimal point. Groups live, the
/// Indian way. The underline belongs to the field, so it lives here.
///
/// The widget renders the reason it was given; it never computes one.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.validation,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AmountValidation validation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final error = validation.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EditableText(
          controller: controller,
          focusNode: focusNode,
          readOnly: !enabled,
          style: FaveType.amountField,
          cursorColor: FaveColors.textPrimary,
          backgroundCursorColor: FaveColors.placeholder,
          selectionColor: FaveColors.avatarAndWaitingRing,
          keyboardType: TextInputType.number,
          inputFormatters: const [RupeeInputFormatter()],
          maxLines: 1,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: FaveMetrics.amountLineGap),
        FieldUnderline(
          color: error != null
              ? FaveColors.failedMark
              : focusNode.hasFocus
              ? FaveColors.link
              : FaveColors.fieldUnderline,
        ),
        if (error != null) ...[
          const SizedBox(height: FaveMetrics.amountLineGap),
          Text(error, style: FaveType.amountError),
        ],
      ],
    );
  }
}

/// Full width · 1 px · #E7DFD4, #5E6DFF focused, #B8433C error.
class FieldUnderline extends StatelessWidget {
  const FieldUnderline({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(height: FaveMetrics.underlineThickness, color: color);
}

/// `₹` + Indian grouping, applied on every keystroke. Digits only — a numeric
/// keyboard cannot produce a decimal point, and neither can this.
class RupeeInputFormatter extends TextInputFormatter {
  const RupeeInputFormatter();

  /// ₹99,99,999 is past the UPI cap, so the error is always reachable.
  static const maxDigits = 7;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Reject anything else outright rather than stripping it. A numeric
    // keypad cannot produce `.` or `-`, but a paste can, and silently
    // deleting them changes what the user is paying: `42.50` would become
    // ₹4,250 and `-1` would become ₹1. Refusing the edit leaves the previous
    // amount on screen, which is wrong in a way the user can see.
    if (!isRenderableAmount(newValue.text)) {
      return oldValue;
    }
    var digits = digitsOf(newValue.text);
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }
    // A lone zero stays: it is a real amount of zero, which is below the
    // minimum and has to show that error (frame 01d). Collapsing it to empty
    // would make the below-minimum state unreachable.
    digits = withoutLeadingZeros(digits);
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final text = formatRupees(int.parse(digits));
    // Grouping shifts everything to the right of the caret, so the caret goes
    // to the end rather than somewhere the user did not put it.
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
