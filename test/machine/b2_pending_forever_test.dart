import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// B2 — pending forever. Confirming for ten seconds, then Still confirming,
/// and the ring reaches zero exactly once.
void main() {
  test('B2 · ten seconds of pending lands on Still confirming', () {
    fakeAsync((async) {
      final backend = FakePaymentBackend(latency: Duration.zero)
        ..mode = BackendMode.pendingForever;
      final h = Harness(backend: backend, async: async);

      final transitions = <PaymentState>[];
      h.bloc.stream.listen(transitions.add);

      h.pay();
      expect(h.state, isA<Confirming>());
      final key = (h.state as Confirming).attempt.key;

      // Polls at 0, 2, 4, 6 and 8 seconds.
      expect(backend.statusCallsFor(key), 1);
      for (final second in [2, 4, 6, 8]) {
        h.elapse(const Duration(seconds: 2));
        expect(
          backend.statusCallsFor(key),
          second ~/ 2 + 1,
          reason: 'a poll at $second s',
        );
        expect(h.state, isA<Confirming>());
      }

      final confirming = h.state as Confirming;
      expect(confirming.fractionAt(h.clock.now()), closeTo(0.2, 0.001));

      // 9.9 s: still counting, ring not yet empty.
      h.elapse(const Duration(milliseconds: 1900));
      expect(h.state, isA<Confirming>());
      expect(
        (h.state as Confirming).fractionAt(h.clock.now()),
        closeTo(0.01, 0.001),
      );

      // 10.0 s: the deadline wins.
      h.elapse(const Duration(milliseconds: 100));
      expect(h.state, isA<StillConfirming>());
      expect((h.state as StillConfirming).checking, isFalse);

      // The ring never reappears: no further Confirming state is emitted, so
      // it reaches zero exactly once.
      final indexOfStill = transitions.indexWhere((s) => s is StillConfirming);
      expect(
        transitions.skip(indexOfStill).whereType<Confirming>(),
        isEmpty,
        reason: 'the countdown does not restart',
      );

      // No terminal answer, so the row keeps its CHECKING badge.
      expect(h.state.recent.single.outcome, RecordOutcome.inFlight);

      // Polling stopped at the deadline.
      final callsAtDeadline = backend.statusCallsFor(key);
      h.elapse(const Duration(seconds: 10));
      expect(backend.statusCallsFor(key), callsAtDeadline);
    });
  });

  test('B2 · Check status again makes exactly one call and comes back', () {
    fakeAsync((async) {
      // A real round trip, so the in-flight window is observable: with zero
      // latency the answer lands in the same microtask as the tap and the
      // link would never be seen reading "Checking…".
      const latency = Duration(milliseconds: 150);
      final backend = FakePaymentBackend(latency: latency)
        ..mode = BackendMode.pendingForever;
      final h = Harness(backend: backend, async: async);

      h.pay();
      h.elapse(latency); // create returns
      final key = (h.state as Confirming).attempt.key;
      h.elapse(const Duration(seconds: 10));
      expect(h.state, isA<StillConfirming>());
      expect((h.state as StillConfirming).checking, isFalse);

      final before = backend.statusCallsFor(key);
      h.send(const CheckStatusTapped());

      // 05b — the link reads "Checking…" and is disabled while it runs.
      expect((h.state as StillConfirming).checking, isTrue);

      h.elapse(latency);
      expect(backend.statusCallsFor(key), before + 1, reason: 'exactly one');
      expect(h.state, isA<StillConfirming>(), reason: 'still pending: stays');
      expect((h.state as StillConfirming).checking, isFalse);

      // A second tap while one is in flight does not start another call.
      h.send(const CheckStatusTapped());
      h.send(const CheckStatusTapped());
      h.elapse(latency);
      expect(backend.statusCallsFor(key), before + 2);
    });
  });
}
