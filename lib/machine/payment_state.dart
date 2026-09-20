import 'package:fave_fake_backend/fave_fake_backend.dart';

import '../core/time/payment_timing.dart';
import '../domain/model/amount.dart';
import '../domain/model/payment_record.dart';
import '../domain/model/recipient.dart';

/// What the user has typed. Editable only on Pay, and carried unchanged
/// through an attempt so Success can show what was actually paid.
class PayForm {
  const PayForm({
    required this.recipient,
    required this.amountRupees,
    required this.note,
  });

  static const initial = PayForm(
    recipient: SeededRecipients.first,
    amountRupees: null,
    note: null,
  );

  final Recipient recipient;

  /// Whole rupees. Null while the field is empty. Never a double.
  final int? amountRupees;

  /// Optional, one line, at most 40 characters.
  final String? note;

  AmountValidation get amount => AmountRules.validate(amountRupees);

  bool get canPay => amount is ValidAmount;

  PayForm copyWith({
    Recipient? recipient,
    int? amountRupees,
    bool clearAmount = false,
    String? note,
    bool clearNote = false,
  }) => PayForm(
    recipient: recipient ?? this.recipient,
    amountRupees: clearAmount ? null : (amountRupees ?? this.amountRupees),
    note: clearNote ? null : (note ?? this.note),
  );
}

/// The frozen facts of one payment. Captured when Pay is tapped; Success and
/// Failed read this, never the live fields.
class Attempt {
  const Attempt({
    required this.key,
    required this.recipient,
    required this.amountRupees,
    required this.note,
    required this.startedAt,
    this.reference,
  });

  /// Our idempotency key, generated before create.
  final String key;
  final Recipient recipient;
  final int amountRupees;
  final String? note;
  final DateTime startedAt;

  /// The id create returned. Null in B1 — the Success screen shows the key.
  final String? reference;

  /// What the reference line shows. In B1 there is no id: show the key.
  String get displayReference => reference ?? key;

  Attempt withReference(String id) => Attempt(
    key: key,
    recipient: recipient,
    amountRupees: amountRupees,
    note: note,
    startedAt: startedAt,
    reference: id,
  );

  PaymentRecord toRecord({
    required RecordOutcome outcome,
    DateTime? settledAt,
  }) => PaymentRecord(
    key: key,
    recipientId: recipient.id,
    recipientName: recipient.name,
    recipientHandle: recipient.handle,
    amountRupees: amountRupees,
    note: note,
    startedAt: startedAt,
    outcome: outcome,
    settledAt: settledAt,
    reference: reference,
  );
}

/// A screen that switches on this cannot forget a case.
sealed class PaymentState {
  const PaymentState({required this.form, required this.recent});

  final PayForm form;

  /// The two most recent payments. The same records the history rows read —
  /// there is only one copy.
  final List<PaymentRecord> recent;
}

/// 01 · Pay. Where the app starts and where every exit returns.
class Editing extends PaymentState {
  const Editing({
    required super.form,
    required super.recent,
    this.ready = false,
  });

  /// False until the stored records have been installed. Pay is gated on it,
  /// so an attempt cannot be started in the window where the restore would
  /// still overwrite it. The CTA is already disabled with an empty amount, so
  /// this needs no state of its own in the design.
  final bool ready;
}

/// 01b · Pay — sending. The button reads "Paying…" until create returns or
/// the 5 s timeout fires.
class Sending extends PaymentState {
  const Sending({
    required this.attempt,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;
}

/// 02 · Confirming. The ten-second clock started at [startedAt]; the ring is
/// a function of [deadline] and the wall clock, never of animation ticks.
class Confirming extends PaymentState {
  const Confirming({
    required this.attempt,
    required this.startedAt,
    required this.deadline,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;

  /// When Confirming was entered — after create returned, or after the
  /// 5 s timeout. Not the tap.
  final DateTime startedAt;
  final DateTime deadline;

  Duration remainingAt(DateTime now) {
    final left = deadline.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Remaining ÷ 10 s. What the sweep draws.
  double fractionAt(DateTime now) =>
      (remainingAt(now).inMicroseconds / PaymentTiming.countdown.inMicroseconds)
          .clamp(0.0, 1.0);
}

/// The 250 ms ring exit. A terminal answer landed; the sweep runs from
/// [exitFrom] to zero before the screen changes. A push arriving during this
/// window changes [outcome], so the screen still ends on the truth.
class ConfirmingExit extends PaymentState {
  const ConfirmingExit({
    required this.attempt,
    required this.outcome,
    required this.exitFrom,
    required this.answeredAt,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;

  /// success or failed. Never pending.
  final PaymentStatus outcome;

  /// The sweep fraction at the instant the answer landed.
  final double exitFrom;

  /// When the terminal answer actually arrived. The reference line on Success
  /// shows this, not the instant 250 ms later when the exit finishes.
  final DateTime answeredAt;
}

/// 03 · Success. Terminal, with the one exception written in DESIGN.md.
class Succeeded extends PaymentState {
  const Succeeded({
    required this.attempt,
    required this.settledAt,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;

  /// Local time the terminal answer arrived — the reference line.
  final DateTime settledAt;
}

/// 04 · Failed. The money never left. A later success push does not flip it.
class PaymentFailed extends PaymentState {
  const PaymentFailed({
    required this.attempt,
    required this.settledAt,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;
  final DateTime settledAt;
}

/// 05 · Still confirming. Ten seconds passed with no answer. Not terminal,
/// not a failure — and the copy says neither.
class StillConfirming extends PaymentState {
  const StillConfirming({
    required this.attempt,
    required this.checking,
    required super.form,
    required super.recent,
  });

  final Attempt attempt;

  /// 05b — a Check status again call is in flight; the link reads "Checking…".
  final bool checking;
}
