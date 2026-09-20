import 'package:flutter/widgets.dart';

import '../../core/design/fave_copy.dart';
import '../../core/design/fave_metrics.dart';
import '../../core/design/fave_type.dart';
import '../../core/util/rupees.dart';
import '../../machine/payment_state.dart';
import '../widgets/fave_buttons.dart';
import '../widgets/fave_shell.dart';
import '../widgets/pay_widgets.dart';

/// The two text fields' controllers, owned by the screen and handed down.
/// `EditableText` needs them to outlive a rebuild, so they cannot live here.
class PayFields {
  PayFields()
    : amount = TextEditingController(),
      amountFocus = FocusNode(),
      note = TextEditingController(),
      noteFocus = FocusNode();

  final TextEditingController amount;
  final FocusNode amountFocus;
  final TextEditingController note;
  final FocusNode noteFocus;

  void dispose() {
    amount.dispose();
    amountFocus.dispose();
    note.dispose();
    noteFocus.dispose();
  }
}

/// 01 · Pay, and 01b · Pay — sending.
///
/// Sending is the same screen with three differences the spec names: the
/// chevron is hidden but keeps its space, nothing is tappable, and the button
/// reads "Paying…" at 55%.
class PayView extends StatelessWidget {
  const PayView({
    super.key,
    required this.state,
    required this.sending,
    required this.fields,
    required this.chipLabel,
    required this.now,
    required this.onPay,
    required this.onChip,
    required this.onRecipient,
  });

  final PaymentState state;
  final bool sending;
  final PayFields fields;
  final String chipLabel;
  final DateTime now;
  final VoidCallback onPay;
  final VoidCallback onChip;
  final VoidCallback onRecipient;

  @override
  Widget build(BuildContext context) {
    final form = state.form;
    final validation = form.amount;
    final rupees = validation.rupees;
    return FaveShell(
      children: [
        PayTopBar(
          chipLabel: chipLabel,
          chevronVisible: !sending,
          // Pay is home in this app, so the chevron has nowhere to go. It is
          // drawn because the design draws it, and it is not tappable.
          onBack: null,
          onChip: sending ? null : onChip,
        ),
        const SizedBox(height: FaveMetrics.payBlockGap),
        RecipientCard(
          recipient: form.recipient,
          onTap: sending ? null : onRecipient,
        ),
        const SizedBox(height: FaveMetrics.payBlockGap),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel(FaveCopy.amountLabel),
                const SizedBox(height: FaveMetrics.amountLineGap),
                PlaceholderStack(
                  placeholder: FaveCopy.amountPlaceholder,
                  style: FaveType.amountPlaceholder,
                  controller: fields.amount,
                  child: AmountField(
                    controller: fields.amount,
                    focusNode: fields.amountFocus,
                    validation: validation,
                    enabled: !sending,
                  ),
                ),
                const SizedBox(height: FaveMetrics.amountLineGap),
                PlaceholderStack(
                  placeholder: FaveCopy.notePlaceholder,
                  style: FaveType.notePlaceholder,
                  controller: fields.note,
                  child: NoteField(
                    controller: fields.note,
                    focusNode: fields.noteFocus,
                    enabled: !sending,
                  ),
                ),
                const SizedBox(height: FaveMetrics.payBlockGap),
                const SectionLabel(FaveCopy.recentLabel),
                const SizedBox(height: FaveMetrics.recentLabelToFirstRow),
                RecentList(records: state.recent, now: now),
              ],
            ),
          ),
        ),
        const SizedBox(height: FaveMetrics.payBlockGap),
        if (sending)
          const PrimaryCta.sending(label: FaveCopy.ctaPaySending)
        else if (rupees == null)
          // Disabled at 40%, and it reads "Pay".
          const PrimaryCta.disabled(label: FaveCopy.ctaPay)
        else
          PrimaryCta(
            // Once valid the CTA reads the amount live.
            label: '${FaveCopy.ctaPay} ${formatRupees(rupees)}',
            onTap: onPay,
          ),
      ],
    );
  }
}
