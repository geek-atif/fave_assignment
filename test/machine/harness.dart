import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/time/clock.dart';
import 'package:fave_pay/data/file_payment_store.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/domain/port/key_generator.dart';
import 'package:fave_pay/domain/port/payment_store.dart';
import 'package:fave_pay/machine/payment_bloc.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';

/// A bloc wired to the real fake, a fake clock and an in-memory store —
/// everything the state machine needs and nothing a widget does.
///
/// [send] and [elapse] both settle the bloc's own event queue, and [elapse]
/// moves the injected clock with the timers: the ring reads wall-clock time,
/// so a test that advanced only one of the two would be lying to it.
class Harness {
  Harness({
    required this.backend,
    required this.async,
    DateTime? start,
    List<PaymentRecord> seed = const [],
    PaymentStore? store,
  }) : clock = TestClock(start ?? DateTime(2026, 9, 19, 18, 42)),
       store = store ?? InMemoryPaymentStore(seed) {
    bloc = PaymentBloc(
      backend: backend,
      store: this.store,
      keys: keys,
      clock: clock,
    );
    // The app restores its records before enabling Pay; a test that skipped
    // this would be driving a bloc the real app never presents.
    unawaited(bloc.start());
    async.flushMicrotasks();
  }

  final FakePaymentBackend backend;
  final FakeAsync async;
  final TestClock clock;
  final PaymentStore store;
  final keys = SequentialKeyGenerator();
  late final PaymentBloc bloc;

  PaymentState get state => bloc.state;

  /// Add an event and let the bloc process it. Bloc delivers events through a
  /// stream, so without this the state would still be the previous one.
  void send(PaymentEvent event) {
    bloc.add(event);
    async.flushMicrotasks();
  }

  /// Advance the wall clock and the timers together.
  void elapse(Duration d) {
    clock.advance(d);
    async.elapse(d);
  }

  /// Simulate the app being backgrounded: the wall clock moves on while the
  /// timers do not, which is exactly what the platform does.
  void background(Duration d) => clock.advance(d);

  /// Type an amount and tap Pay. The key is generated inside the bloc.
  void pay({int rupees = 4200, String? note}) {
    send(AmountEdited(rupees));
    send(NoteEdited(note));
    send(const PayTapped());
  }
}
