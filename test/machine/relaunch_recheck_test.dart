import 'dart:io';

import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/time/clock.dart';
import 'package:fave_pay/data/file_payment_store.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/domain/port/key_generator.dart';
import 'package:fave_pay/machine/payment_bloc.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A record that was still pending when the app died is re-checked once on
/// launch and ends on the right status.
///
/// This is the one suite that touches real files, on both sides: our store and
/// the backend's are separate, which is the only way to hold a record for a
/// key the backend has forgotten. Everything else injects a clock and runs
/// under `fake_async`; here the I/O is the point, so the waiting is real.
///
/// It waits by polling `bloc.state`, not by listening to `bloc.stream` and not
/// by pumping the event queue a fixed number of times. Both of those are
/// races: a fixed pump count passes on an idle machine and fails when
/// `flutter test` runs other files in parallel, and a stream subscription set
/// up after the action can miss the emit it was waiting for.
void main() {
  late Directory dir;
  late String ourStore;
  late String backendStore;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fave_relaunch');
    ourStore = '${dir.path}/fave_payments.json';
    backendStore = '${dir.path}/backend_payments.json';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  PaymentBloc build(
    FakePaymentBackend backend,
    Clock clock, {
    KeyGenerator? keys,
  }) => PaymentBloc(
    backend: backend,
    store: FilePaymentStore(ourStore),
    keys: keys ?? SequentialKeyGenerator(),
    clock: clock,
  );

  /// Poll until [reached] holds, or fail saying what we were waiting for.
  Future<void> eventually(bool Function() reached, String what) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (reached()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('never $what');
  }

  /// The bloc writes through to the store without awaiting, so the last write
  /// can still be in flight when the state already reflects it.
  Future<List<PaymentRecord>> storedWhen(
    bool Function(List<PaymentRecord>) reached,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      // A fresh store each time: FilePaymentStore caches after its first read.
      final records = await FilePaymentStore(ourStore).load();
      if (reached(records)) {
        return records;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('the store never reached the expected contents');
  }

  test(
    'a record left pending by a kill is re-checked once and settles',
    () async {
      final clock = TestClock(DateTime(2026, 9, 19, 18, 42));

      // ---- session one: pay, and die while the answer is still pending ----
      final first = FakePaymentBackend(
        latency: Duration.zero,
        storePath: backendStore,
      )..mode = BackendMode.declined;
      final one = build(first, clock);
      await one.start();
      one
        ..add(const AmountEdited(4200))
        ..add(const PayTapped());

      await eventually(() => one.state is Confirming, 'reached Confirming');
      final key = (one.state as Confirming).attempt.key;

      // One poll made, and it answered pending. The counter ticks when the call
      // is answered, which is a microtask after the state that issued it.
      await eventually(() => first.statusCallsFor(key) == 1, 'polled once');
      expect(one.state.recent.single.outcome, RecordOutcome.inFlight);
      await storedWhen((r) => r.length == 1);

      // The process dies. Nothing is disposed cleanly — but the files are there.
      await one.close();
      await first.dispose();

      // ---- session two: relaunch ----
      // A mode's sequence continues across a restart: declined answered pending
      // on the call before the kill, so the re-check gets the next step.
      final second = FakePaymentBackend(
        latency: Duration.zero,
        storePath: backendStore,
      );
      final two = build(second, clock);
      await two.start();
      await eventually(
        () =>
            two.state.recent.length == 1 && two.state.recent.single.isTerminal,
        're-checked the record on launch',
      );

      final row = two.state.recent.single;
      expect(row.key, key, reason: 'the same record, read back from disk');
      expect(row.outcome, RecordOutcome.failed);
      expect(row.amountRupees, 4200, reason: 'still an int of rupees');
      expect(row.amountRupees, isA<int>());

      // Exactly one re-check — the second status call this key has ever had.
      expect(second.statusCallsFor(key), 2);
      expect(
        second.createCallsFor(key),
        1,
        reason: 'a relaunch never re-creates',
      );

      await two.close();
      await second.dispose();
    },
  );

  test('a key the backend has forgotten is shown unresolved', () async {
    final clock = TestClock(DateTime(2026, 9, 19, 18, 42));

    final first = FakePaymentBackend(
      latency: Duration.zero,
      storePath: backendStore,
    )..mode = BackendMode.pendingForever;
    final one = build(first, clock);
    await one.start();
    one
      ..add(const AmountEdited(1200))
      ..add(const PayTapped());

    await eventually(() => one.state is Confirming, 'reached Confirming');
    expect(one.state.recent.single.outcome, RecordOutcome.inFlight);
    await storedWhen((r) => r.length == 1);
    await one.close();

    // The backend's store is cleared — the file was lost. Ours is not.
    first.reset();
    await first.dispose();

    final second = FakePaymentBackend(
      latency: Duration.zero,
      storePath: backendStore,
    );
    final two = build(second, clock);
    await two.start();
    // The recheck is routed through the normal status path now, so the row
    // is restored first and marked unresolved when the call throws.
    await eventually(
      () =>
          two.state.recent.length == 1 &&
          two.state.recent.single.outcome == RecordOutcome.unresolved,
      'marked the orphaned record unresolved',
    );

    await two.close();
    await second.dispose();
  });

  test('only ever two records survive, newest first', () async {
    final clock = TestClock(DateTime(2026, 9, 19, 18, 42));
    final backend = FakePaymentBackend(
      latency: Duration.zero,
      storePath: backendStore,
    )..mode = BackendMode.declined;
    final bloc = build(backend, clock);
    await bloc.start();

    for (final amount in [100, 200, 300]) {
      bloc
        ..add(AmountEdited(amount))
        ..add(const PayTapped());
      // The record is written when the attempt starts, so Confirming is the
      // point at which this attempt exists.
      await eventually(
        () =>
            bloc.state is Confirming &&
            (bloc.state as Confirming).attempt.amountRupees == amount,
        'started the ₹$amount attempt',
      );
      clock.advance(const Duration(minutes: 1));
      bloc.add(const ReturnToPayTapped());
      await eventually(() => bloc.state is Editing, 'returned to Pay');
    }

    final stored = await storedWhen(
      (r) => r.length == 2 && r.first.amountRupees == 300,
    );
    expect(stored, hasLength(2), reason: 'only ever two');
    expect(stored.first.amountRupees, 300, reason: 'newest first');
    expect(stored.last.amountRupees, 200);

    await bloc.close();
    await backend.dispose();
  });
}
