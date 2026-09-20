import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/design/fave_motion.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// B3 — the poll says success, then a push says failed 300 ms later, while
/// the badge is still animating.
///
/// The brief does not specify what the screen ends on. Our decision, argued
/// in DESIGN.md: **failed wins.** A later contradiction from the server is a
/// correction, and the safe direction to be wrong in is to stop claiming that
/// money moved. The reverse — a success overturning a shown failure — never
/// happens (see the B4 test).
void main() {
  test('B3 · a failed push after success ends the screen on Failed', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.flipAfterSuccess;
      final h = Harness(backend: backend, async: async);

      h.pay();
      expect(h.state, isA<Confirming>());

      // First poll: pending. Second poll at 2 s: success.
      h.elapse(FaveMotion.pollInterval);
      expect(
        h.state,
        isA<ConfirmingExit>(),
        reason: 'the ring runs to zero before the screen changes',
      );
      expect((h.state as ConfirmingExit).outcome, PaymentStatus.success);

      // 250 ms later the screen changes; the badge starts animating.
      h.elapse(FaveMotion.ringExit);
      expect(h.state, isA<Succeeded>());
      expect(h.state.recent.single.outcome, RecordOutcome.success);

      // The push lands 300 ms after the success poll — 50 ms into the 600 ms
      // badge entrance.
      h.elapse(const Duration(milliseconds: 50));
      expect(
        h.state,
        isA<PaymentFailed>(),
        reason: 'the screen ends on the truth',
      );

      // And the record follows the screen: one source of truth.
      expect(h.state.recent.single.outcome, RecordOutcome.failed);

      // Nothing further moves it.
      h.elapse(const Duration(seconds: 5));
      expect(h.state, isA<PaymentFailed>());
    });
  });

  test('B3 · a failed push during the ring exit still ends on Failed', () {
    fakeAsync((async) {
      // Delay the push so it lands inside the 250 ms exit rather than after it.
      final backend = FakePaymentBackend(
        latency: Duration.zero,
        flipDelay: const Duration(milliseconds: 100),
      )..mode = BackendMode.flipAfterSuccess;
      final h = Harness(backend: backend, async: async);

      h.pay();
      h.elapse(FaveMotion.pollInterval);
      expect((h.state as ConfirmingExit).outcome, PaymentStatus.success);

      h.elapse(const Duration(milliseconds: 100));
      expect(
        (h.state as ConfirmingExit).outcome,
        PaymentStatus.failed,
        reason: 'the exit is still running; the outcome is corrected in place',
      );

      h.elapse(const Duration(milliseconds: 150));
      expect(h.state, isA<PaymentFailed>());
      expect(h.state.recent.single.outcome, RecordOutcome.failed);
    });
  });
}
