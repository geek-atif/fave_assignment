import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// B5 — the app is backgrounded during Confirming and comes back later.
///
/// Backgrounding is simulated the way the platform does it: the wall clock
/// moves on while the timers do not. A ticker that pauses and carries on
/// would show too much time left — that is the bug this test exists for.
void main() {
  test('B5 · the ring shows true remaining time after a resume', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.pendingForever;
      final h = Harness(backend: backend, async: async);

      h.pay();
      final key = (h.state as Confirming).attempt.key;

      // Three seconds of normal running: 7 s left.
      h.elapse(const Duration(seconds: 3));
      expect(
        (h.state as Confirming).fractionAt(h.clock.now()),
        closeTo(0.7, 0.001),
      );
      final callsBeforeBackground = backend.statusCallsFor(key);

      // Backgrounded for four seconds: wall clock moves, timers do not.
      h.background(const Duration(seconds: 4));
      h.send(const AppResumed());

      // Same state, and the ring shows 3 s left — not the 7 s a paused
      // ticker would still be holding.
      final resumed = h.state as Confirming;
      expect(resumed.remainingAt(h.clock.now()), const Duration(seconds: 3));
      expect(resumed.fractionAt(h.clock.now()), closeTo(0.3, 0.001));

      // Exactly one status call happens immediately on the way back in.
      async.flushMicrotasks();
      expect(backend.statusCallsFor(key), callsBeforeBackground + 1);

      // Then the 2 s cadence continues until the deadline.
      h.elapse(const Duration(seconds: 2));
      expect(backend.statusCallsFor(key), callsBeforeBackground + 2);
      expect(h.state, isA<Confirming>());

      // 3 s after the resume the deadline lands, not 10.
      h.elapse(const Duration(seconds: 1));
      expect(h.state, isA<StillConfirming>());
    });
  });

  test(
    'B5 · resuming after the ten seconds are gone lands on Still confirming',
    () {
      fakeAsync((async) {
        final backend = FakePaymentBackend(latency: Duration.zero)
          ..mode = BackendMode.pendingForever;
        final h = Harness(backend: backend, async: async);

        h.pay();
        final key = (h.state as Confirming).attempt.key;
        final callsBefore = backend.statusCallsFor(key);

        // Away for three minutes.
        h.background(const Duration(minutes: 3));
        h.send(const AppResumed());

        // The ring shows 0, and one status(key) call happens immediately.
        expect((h.state as Confirming).fractionAt(h.clock.now()), 0);
        async.flushMicrotasks();
        expect(backend.statusCallsFor(key), callsBefore + 1);

        // Still pending and the ten seconds are gone: Still confirming.
        h.elapse(Duration.zero);
        expect(h.state, isA<StillConfirming>());
      });
    },
  );

  test('B5 · resuming during sending changes nothing', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.lostResponse;
      final h = Harness(backend: backend, async: async);

      h.pay();
      expect(h.state, isA<Sending>());

      h.background(const Duration(minutes: 3));
      h.send(const AppResumed());
      expect(h.state, isA<Sending>(), reason: 'keep waiting for the timeout');

      // The 5 s timeout is still the thing that ends Sending.
      h.elapse(const Duration(seconds: 5));
      expect(h.state, isA<Confirming>());
    });
  });
}
