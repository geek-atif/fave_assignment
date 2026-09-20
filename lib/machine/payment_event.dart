import 'package:fave_fake_backend/fave_fake_backend.dart';

import '../domain/model/payment_record.dart';
import '../domain/model/recipient.dart';

/// One entrance. Polls, pushes, timers and taps all arrive here, in order.
/// A machine with two entrances is a machine with a race.
sealed class PaymentEvent {
  const PaymentEvent();
}

// ---- launch ----

/// The stored records, read once at launch. This is the only event that
/// installs a whole list, and it lands before Pay is enabled — so it cannot
/// overwrite an attempt started while the app was still starting.
class RecordsRestored extends PaymentEvent {
  const RecordsRestored(this.records);

  final List<PaymentRecord> records;
}

/// A write-through completed and came back with something we did not predict.
class RecordsLoaded extends PaymentEvent {
  const RecordsLoaded(this.records);

  final List<PaymentRecord> records;
}

// ---- the form ----

class RecipientPicked extends PaymentEvent {
  const RecipientPicked(this.recipient);

  final Recipient recipient;
}

class AmountEdited extends PaymentEvent {
  const AmountEdited(this.rupees);

  /// Null while the field is empty.
  final int? rupees;
}

class NoteEdited extends PaymentEvent {
  const NoteEdited(this.note);

  final String? note;
}

// ---- taps ----

class PayTapped extends PaymentEvent {
  const PayTapped();
}

/// Try again after a terminal Failed. A new payment, not a resend.
class TryAgainTapped extends PaymentEvent {
  const TryAgainTapped();
}

/// Done · Go to home · Go back. All return to Pay with a fresh key.
///
/// [clearForm] is our decision, not the brief's — it says only that the key is
/// fresh. Done and Go to home clear the amount and note; Go back does not.
/// See DESIGN.md.
class ReturnToPayTapped extends PaymentEvent {
  const ReturnToPayTapped({this.clearForm = false});

  /// True when the attempt is finished with — Success, or leaving Still
  /// confirming. False for Go back on Failed, where nothing left the account
  /// and retyping would be friction for no safety.
  final bool clearForm;
}

class CheckStatusTapped extends PaymentEvent {
  const CheckStatusTapped();
}

// ---- the backend ----

class CreateReturned extends PaymentEvent {
  const CreateReturned(this.key, this.id);

  final String key;
  final String id;
}

/// Our 5 s timeout fired. Do not call create again — call status(key).
class CreateTimedOut extends PaymentEvent {
  const CreateTimedOut(this.key);

  final String key;
}

class CreateThrew extends PaymentEvent {
  const CreateThrew(this.key);

  final String key;
}

/// A poll answered.
class StatusAnswered extends PaymentEvent {
  const StatusAnswered(this.key, this.status);

  final String key;
  final PaymentStatus status;
}

/// A poll threw — the backend no longer knows this key.
class StatusThrew extends PaymentEvent {
  const StatusThrew(this.key);

  final String key;
}

/// A push over `updates`. Can arrive at any time, including after the screen
/// has already reached a terminal state.
class PushArrived extends PaymentEvent {
  const PushArrived(this.key, this.status);

  final String key;
  final PaymentStatus status;
}

// ---- the clock ----

/// Time to make the next status call.
class PollDue extends PaymentEvent {
  const PollDue(this.key);

  final String key;
}

/// 10.0 s. The deadline wins even if a poll is in flight.
class DeadlineReached extends PaymentEvent {
  const DeadlineReached(this.key);

  final String key;
}

/// The 250 ms ring exit finished; now the screen changes.
class RingExitFinished extends PaymentEvent {
  const RingExitFinished(this.key);

  final String key;
}

/// B5. The app came back to the foreground.
class AppResumed extends PaymentEvent {
  const AppResumed();
}
