import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/design/fave_motion.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Optional: the happy path, the clean failure, and B4.
void main() {
  test('Success · pending, pending, success — about 4 s', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.success;
      final h = Harness(backend: backend, async: async);

      h.pay(rupees: 4200, note: 'Rent — October');
      expect(h.state, isA<Confirming>());

      final attempt = (h.state as Confirming).attempt;
      expect(attempt.reference, isNotNull, reason: 'create returned an id');

      // Polls at 0 and 2 answer pending; the one at 4 answers success.
      h.elapse(const Duration(seconds: 4));
      expect(h.state, isA<ConfirmingExit>());
      h.elapse(FaveMotion.ringExit);

      final done = h.state as Succeeded;
      // Success shows what was actually paid, from the attempt's own state.
      expect(done.attempt.amountRupees, 4200);
      expect(done.attempt.note, 'Rent — October');
      expect(done.attempt.recipient.handle, 'kavya.sv@okaxis');
      expect(done.attempt.displayReference, attempt.reference);
      expect(done.recent.single.outcome, RecordOutcome.success);

      // The reference line is the local time the ANSWER arrived — not the
      // instant 250 ms later when the ring finished running to zero.
      expect(
        done.settledAt,
        h.clock.now().subtract(FaveMotion.ringExit),
        reason: 'stamped when the poll answered, not when the exit ended',
      );

      // Done returns to Pay; the next tap gets a fresh key — and the amount
      // and note go with the attempt that just succeeded, so the screen is
      // not left one tap from sending the same payment again.
      h.send(const ReturnToPayTapped(clearForm: true));
      expect(h.state, isA<Editing>());
      expect(h.state.form.amountRupees, isNull, reason: 'amount cleared');
      expect(h.state.form.note, isNull, reason: 'note cleared');
      expect(
        h.state.form.recipient,
        done.attempt.recipient,
        reason: 'but the recipient survives',
      );
      expect(h.state.form.canPay, isFalse, reason: 'CTA back to disabled');

      // Re-enter an amount to prove the next attempt still works.
      h.send(const AmountEdited(4200));
      h.send(const PayTapped());
      expect(h.state, isNot(isA<Editing>()));
      expect(
        (h.state as Confirming).attempt.key,
        isNot(attempt.key),
        reason: 'a fresh key, and therefore a new payment',
      );
    });
  });

  test('Declined · Failed is terminal, and Try again is a new key', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.declined;
      final h = Harness(backend: backend, async: async);

      h.pay();
      h.elapse(FaveMotion.pollInterval);
      h.elapse(FaveMotion.ringExit);

      final failed = h.state as PaymentFailed;
      final firstKey = failed.attempt.key;
      expect(failed.recent.single.outcome, RecordOutcome.failed);

      h.send(const TryAgainTapped());
      final retry = h.state as Confirming;
      expect(retry.attempt.key, isNot(firstKey));
      expect(backend.createCallsFor(firstKey), 1);
      expect(backend.createCallsFor(retry.attempt.key), 1);
      expect(backend.paymentsCreated, 2, reason: 'two payments, two keys');
    });
  });

  test('Go back keeps what was typed; Done does not', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.declined;
      final h = Harness(backend: backend, async: async);

      h.pay(rupees: 4200, note: 'Rent');
      h.elapse(FaveMotion.pollInterval);
      h.elapse(FaveMotion.ringExit);
      expect(h.state, isA<PaymentFailed>());

      // Nothing left the account, so retyping would be friction for no safety.
      h.send(const ReturnToPayTapped());
      expect(h.state, isA<Editing>());
      expect(h.state.form.amountRupees, 4200);
      expect(h.state.form.note, 'Rent');
      expect(h.state.form.canPay, isTrue, reason: 'still ready to pay');
    });
  });

  test('B4 · a late success push does not flip a terminal Failed', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(
        latency: Duration.zero,
        lateSuccessDelay: const Duration(seconds: 1),
      )..mode = BackendMode.lateSuccess;
      final h = Harness(backend: backend, async: async);

      final painted = <PaymentState>[];
      h.bloc.stream.listen(painted.add);

      h.pay();
      h.elapse(FaveMotion.pollInterval);
      h.elapse(FaveMotion.ringExit);
      expect(h.state, isA<PaymentFailed>());

      final settledAt = (h.state as PaymentFailed).settledAt;
      final paintsBefore = painted.whereType<PaymentFailed>().length;

      // The push lands a second later. It must not crash, must not flip,
      // and must not paint again.
      h.elapse(const Duration(seconds: 2));

      expect(h.state, isA<PaymentFailed>());
      expect((h.state as PaymentFailed).settledAt, settledAt);
      expect(
        painted.whereType<PaymentFailed>().length,
        paintsBefore,
        reason: 'no second paint',
      );
      expect(h.state.recent.single.outcome, RecordOutcome.failed);
    });
  });
}
