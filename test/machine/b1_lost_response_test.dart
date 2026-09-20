import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/design/fave_motion.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// B1 — create never returns. The one thing that must not happen is a second
/// create: that is the double-charge shape, and the fake counts.
void main() {
  test('B1 · the 5 s timeout calls status(key), never create again', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.lostResponse;
      final h = Harness(backend: backend, async: async);

      h.pay();
      expect(h.state, isA<Sending>(), reason: 'create is hanging');

      final key = (h.state as Sending).attempt.key;

      // Four seconds in, still waiting — the timeout is ours and it is 5 s.
      h.elapse(const Duration(seconds: 4));
      expect(h.state, isA<Sending>());

      h.elapse(const Duration(seconds: 1));
      expect(
        h.state,
        isA<Confirming>(),
        reason: 'the timeout enters Confirming; the clock starts here',
      );
      expect(backend.createCallsFor(key), 1);
      expect(backend.paymentsCreated, 1);

      // status(key): pending on the first call, success on the second.
      expect(backend.statusCallsFor(key), 1, reason: 'polled immediately');

      h.elapse(FaveMotion.pollInterval);
      h.elapse(FaveMotion.ringExit);

      expect(h.state, isA<Succeeded>());
      final succeeded = h.state as Succeeded;

      // Still exactly one create, after a full round trip.
      expect(backend.createCallsFor(key), 1);
      expect(backend.paymentsCreated, 1);

      // There is no id in B1 — show the key, and do not crash.
      expect(succeeded.attempt.reference, isNull);
      expect(succeeded.attempt.displayReference, key);

      expect(succeeded.recent.single.outcome, RecordOutcome.success);
    });
  });
}
