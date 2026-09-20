import 'dart:async';

import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:fave_pay/core/time/clock.dart';
import 'package:fave_pay/domain/model/payment_record.dart';
import 'package:fave_pay/domain/port/key_generator.dart';
import 'package:fave_pay/domain/port/payment_store.dart';
import 'package:fave_pay/machine/payment_bloc.dart';
import 'package:fave_pay/machine/payment_event.dart';
import 'package:fave_pay/machine/payment_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// M05 — the launch restore must not be able to overwrite newer truth.
///
/// `main` fires `start()` without awaiting it and calls `runApp` immediately,
/// so Pay is on screen while the store is still being read. Before this was
/// fixed, `start()` finished by installing a whole-list snapshot, which
/// silently dropped any attempt begun in that window.
class _SlowStore implements PaymentStore {
  _SlowStore(this._seed);

  final List<PaymentRecord> _seed;
  final _gate = Completer<void>();
  List<PaymentRecord> _records = const [];

  /// Let the launch read finish.
  void release() => _gate.complete();

  @override
  Future<List<PaymentRecord>> load() async {
    await _gate.future;
    _records = List.of(_seed);
    return List.unmodifiable(_records);
  }

  @override
  Future<List<PaymentRecord>> save(PaymentRecord record) async {
    _records = [record, ..._records.where((r) => r.key != record.key)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _records = _records.take(PaymentStore.keptRecords).toList();
    return List.unmodifiable(_records);
  }
}

PaymentRecord _old(String key, int rupees, DateTime at) => PaymentRecord(
  key: key,
  recipientId: 'kavya',
  recipientName: 'Kavya Sridharan Venkataraghavan',
  recipientHandle: 'kavya.sv@okaxis',
  amountRupees: rupees,
  note: null,
  startedAt: at,
  outcome: RecordOutcome.success,
  settledAt: at,
  reference: '427118330900',
);

void main() {
  late FakePaymentBackend backend;
  late TestClock clock;
  late _SlowStore store;
  late PaymentBloc bloc;

  setUp(() {
    clock = TestClock(DateTime(2026, 9, 20, 10));
    backend = FakePaymentBackend(latency: Duration.zero);
    store = _SlowStore([_old('old_1', 111, DateTime(2026, 9, 19, 9))]);
    bloc = PaymentBloc(
      backend: backend,
      store: store,
      keys: SequentialKeyGenerator(),
      clock: clock,
    );
  });

  tearDown(() async {
    await bloc.close();
    await backend.dispose();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('Pay is refused until the launch restore has landed', () async {
    unawaited(bloc.start());
    await settle();

    // The read has not finished, so Pay does nothing rather than starting a
    // payment the restore would go on to erase.
    bloc
      ..add(const AmountEdited(4200))
      ..add(const PayTapped());
    await settle();
    expect(bloc.state, isA<Editing>());
    expect((bloc.state as Editing).ready, isFalse);
    expect(backend.paymentsCreated, 0, reason: 'no payment was created');

    store.release();
    await settle();

    expect((bloc.state as Editing).ready, isTrue);
    expect(bloc.state.recent, hasLength(1), reason: 'the stored row is in');

    // And Pay works from here.
    bloc.add(const PayTapped());
    await settle();
    expect(bloc.state, isA<Confirming>());
    expect(backend.paymentsCreated, 1);
  });

  test('the restored row and a new attempt coexist after launch', () async {
    unawaited(bloc.start());
    store.release();
    await settle();

    bloc
      ..add(const AmountEdited(4200))
      ..add(const PayTapped());
    await settle();

    // No later event re-installs the loaded snapshot over the new attempt:
    // the restore is the only whole-list install and it has already happened.
    final keys = bloc.state.recent.map((r) => r.key).toList();
    expect(keys, contains('key_1'), reason: 'the new attempt is in history');
    expect(keys, contains('old_1'), reason: 'and so is the stored row');
    expect(bloc.state.recent, hasLength(2));

    // Settle it and the row updates in place rather than being replaced.
    await settle();
    final row = bloc.state.recent.firstWhere((r) => r.key == 'key_1');
    expect(row.amountRupees, 4200);
    expect(bloc.state.recent, hasLength(2), reason: 'still only ever two');
  });

  test('start is idempotent — a second call re-checks nothing twice', () async {
    final pending = PaymentRecord(
      key: 'pending_1',
      recipientId: 'rohit',
      recipientName: 'Rohit Menon',
      recipientHandle: 'rohit.menon@ybl',
      amountRupees: 1200,
      note: null,
      startedAt: DateTime(2026, 9, 19, 9),
      outcome: RecordOutcome.inFlight,
    );
    store = _SlowStore([pending])..release();
    bloc = PaymentBloc(
      backend: backend,
      store: store,
      keys: SequentialKeyGenerator(),
      clock: clock,
    );

    await bloc.start();
    await bloc.start();
    await bloc.start();
    await settle();

    // The backend never knew this key, so the row is unresolved — and it was
    // asked exactly once despite three starts.
    expect(bloc.state.recent.single.outcome, RecordOutcome.unresolved);
    expect(backend.statusCallsFor('pending_1'), 0, reason: 'unknown key threw');
    expect(bloc.state.recent, hasLength(1));
  });
}
