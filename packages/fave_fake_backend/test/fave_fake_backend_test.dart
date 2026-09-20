import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';
import 'package:test/test.dart';

// These tests are also the reference for how each mode behaves.
void main() {
  late FakePaymentBackend be;
  setUp(() => be = FakePaymentBackend(latency: Duration.zero));

  Future<List<PaymentStatus>> poll(String key, int times) async => [
        for (var i = 0; i < times; i++) await be.status(key),
      ];

  test('Success: pending, pending, success', () {
    fakeAsync((a) {
      be.mode = BackendMode.success;
      late String id;
      be.create('k').then((v) => id = v);
      a.flushMicrotasks();
      expect(id, '427118330921');
      late List<PaymentStatus> seen;
      poll('k', 4).then((v) => seen = v);
      a.flushMicrotasks();
      expect(seen, [
        PaymentStatus.pending,
        PaymentStatus.pending,
        PaymentStatus.success,
        PaymentStatus.success,
      ]);
    });
  });

  test('Declined: pending, failed', () {
    fakeAsync((a) {
      be.mode = BackendMode.declined;
      be.create('k');
      a.flushMicrotasks();
      late List<PaymentStatus> seen;
      poll('k', 3).then((v) => seen = v);
      a.flushMicrotasks();
      expect(seen, [
        PaymentStatus.pending,
        PaymentStatus.failed,
        PaymentStatus.failed,
      ]);
    });
  });

  test(
    'B1 lost response: create never completes, but status(key) works and one payment exists',
    () {
      fakeAsync((a) {
        be.mode = BackendMode.lostResponse;
        var completed = false;
        be.create('k').then((_) => completed = true);
        a.elapse(const Duration(minutes: 1));
        expect(completed, isFalse);
        late List<PaymentStatus> seen;
        poll('k', 2).then((v) => seen = v);
        a.flushMicrotasks();
        expect(seen, [PaymentStatus.pending, PaymentStatus.success]);
        expect(be.paymentsCreated, 1);
      });
    },
  );

  test('B1: a second create with the same key is the same payment', () {
    fakeAsync((a) {
      be.mode = BackendMode.lostResponse;
      be.create('k');
      be.create('k');
      a.flushMicrotasks();
      expect(be.paymentsCreated, 1);
      expect(
        be.createCallsFor('k'),
        2,
      ); // the app did resend — visible to graders
    });
  });

  test('B2 pending forever', () {
    fakeAsync((a) {
      be.mode = BackendMode.pendingForever;
      be.create('k');
      a.flushMicrotasks();
      late List<PaymentStatus> seen;
      poll('k', 20).then((v) => seen = v);
      a.flushMicrotasks();
      expect(seen.toSet(), {PaymentStatus.pending});
    });
  });

  test(
    'B3 flip after success: poll says success, push says failed 300 ms later, status then says failed',
    () {
      fakeAsync((a) {
        be.mode = BackendMode.flipAfterSuccess;
        final pushes = <StatusPush>[];
        be.updates.listen(pushes.add);
        be.create('k');
        a.flushMicrotasks();
        late List<PaymentStatus> seen;
        poll('k', 2).then((v) => seen = v);
        a.flushMicrotasks();
        expect(seen, [PaymentStatus.pending, PaymentStatus.success]);
        expect(pushes, isEmpty);
        a.elapse(const Duration(milliseconds: 299));
        expect(pushes, isEmpty);
        a.elapse(const Duration(milliseconds: 1));
        expect(pushes.map((p) => p.status), [PaymentStatus.failed]);
        late PaymentStatus after;
        be.status('k').then((v) => after = v);
        a.flushMicrotasks();
        expect(after, PaymentStatus.failed);
      });
    },
  );

  test(
    'B4 late success: poll says failed, push says success after the delay',
    () {
      fakeAsync((a) {
        be = FakePaymentBackend(
          latency: Duration.zero,
          lateSuccessDelay: const Duration(seconds: 5),
        );
        be.mode = BackendMode.lateSuccess;
        final pushes = <StatusPush>[];
        be.updates.listen(pushes.add);
        be.create('k');
        a.flushMicrotasks();
        late List<PaymentStatus> seen;
        poll('k', 2).then((v) => seen = v);
        a.flushMicrotasks();
        expect(seen, [PaymentStatus.pending, PaymentStatus.failed]);
        a.elapse(const Duration(seconds: 5));
        expect(pushes.map((p) => p.status), [PaymentStatus.success]);
      });
    },
  );

  test(
    'mode is captured at create; changing it afterwards affects only the next key',
    () {
      fakeAsync((a) {
        be.mode = BackendMode.declined;
        be.create('a');
        be.mode = BackendMode.success;
        be.create('b');
        a.flushMicrotasks();
        late List<PaymentStatus> sa, sb;
        poll('a', 2).then((v) => sa = v);
        poll('b', 3).then((v) => sb = v);
        a.flushMicrotasks();
        expect(sa.last, PaymentStatus.failed);
        expect(sb.last, PaymentStatus.success);
      });
    },
  );

  test('storePath: a new instance remembers the outcome and the call counts',
      () {
    final dir = Directory.systemTemp.createTempSync('fake_be');
    final path = '${dir.path}/store.json';
    final first = FakePaymentBackend(latency: Duration.zero, storePath: path)
      ..mode = BackendMode.declined;
    fakeAsync((a) {
      first.create('k');
      a.flushMicrotasks();
      first.status('k');
      a.flushMicrotasks();
      first.status('k');
      a.flushMicrotasks();
    });

    // the process dies: a brand-new instance, same file
    final second = FakePaymentBackend(latency: Duration.zero, storePath: path);
    fakeAsync((a) {
      late PaymentStatus s;
      second.status('k').then((v) => s = v);
      a.flushMicrotasks();
      expect(s, PaymentStatus.failed);
    });
    expect(second.paymentsCreated, 1);
    expect(second.createCallsFor('k'), 1);
    dir.deleteSync(recursive: true);
  });

  test('storePath: a pending payment survives, and still settles', () {
    final dir = Directory.systemTemp.createTempSync('fake_be');
    final path = '${dir.path}/store.json';
    final first = FakePaymentBackend(latency: Duration.zero, storePath: path)
      ..mode = BackendMode.success;
    fakeAsync((a) {
      first.create('k');
      a.flushMicrotasks();
      late PaymentStatus s;
      first.status('k').then((v) => s = v);
      a.flushMicrotasks();
      expect(s, PaymentStatus.pending);
    });

    final second = FakePaymentBackend(latency: Duration.zero, storePath: path);
    fakeAsync((a) {
      final seen = <PaymentStatus>[];
      second.status('k').then(seen.add);
      a.flushMicrotasks();
      second.status('k').then(seen.add);
      a.flushMicrotasks();
      expect(seen.last, PaymentStatus.success);
    });
    dir.deleteSync(recursive: true);
  });

  test('dispose does NOT delete the store file', () {
    final dir = Directory.systemTemp.createTempSync('fake_be');
    final path = '${dir.path}/store.json';
    final be = FakePaymentBackend(latency: Duration.zero, storePath: path);
    fakeAsync((a) {
      be.create('k');
      a.flushMicrotasks();
    });
    be.dispose();
    expect(File(path).existsSync(), isTrue,
        reason: 'shutdown must not lose persistence');
    final next = FakePaymentBackend(latency: Duration.zero, storePath: path);
    expect(next.createCallsFor('k'), 1);
    dir.deleteSync(recursive: true);
  });

  test('a corrupt or foreign store file is ignored, not thrown', () {
    final dir = Directory.systemTemp.createTempSync('fake_be');
    final path = '${dir.path}/store.json';
    File(path).writeAsStringSync('{"nextId":7}');
    final partial = FakePaymentBackend(latency: Duration.zero, storePath: path);
    expect(partial.paymentsCreated, 0);
    File(path).writeAsStringSync('not json at all');
    final corrupt = FakePaymentBackend(latency: Duration.zero, storePath: path);
    expect(corrupt.paymentsCreated, 0);
    dir.deleteSync(recursive: true);
  });

  test('reset deletes the store file', () {
    final dir = Directory.systemTemp.createTempSync('fake_be');
    final path = '${dir.path}/store.json';
    final be = FakePaymentBackend(latency: Duration.zero, storePath: path);
    fakeAsync((a) {
      be.create('k');
      a.flushMicrotasks();
    });
    expect(File(path).existsSync(), isTrue);
    be.reset();
    expect(File(path).existsSync(), isFalse);
    dir.deleteSync(recursive: true);
  });

  test('unknown key fails the future, not the call', () {
    expect(be.status('nope'), throwsStateError);
  });

  test('reset cancels a push that has not arrived yet', () {
    fakeAsync((a) {
      be.mode = BackendMode.flipAfterSuccess;
      final pushes = <StatusPush>[];
      be.updates.listen(pushes.add);
      be.create('k');
      a.flushMicrotasks();
      poll('k', 2);
      a.flushMicrotasks();
      be.reset();
      a.elapse(const Duration(seconds: 1));
      expect(pushes, isEmpty);
    });
  });

  test(
    'refundBeforeSuccess: refunded push (with amount) arrives before the poll says success',
    () {
      fakeAsync((a) {
        be.mode = BackendMode.refundBeforeSuccess;
        final pushes = <StatusPush>[];
        be.updates.listen(pushes.add);
        be.create('k');
        a.flushMicrotasks();
        late PaymentStatus first;
        be.status('k').then((v) => first = v);
        a.flushMicrotasks();
        expect(first, PaymentStatus.pending);
        expect(pushes, isEmpty);
        a.elapse(const Duration(milliseconds: 100));
        expect(pushes.single.status, PaymentStatus.refunded);
        expect(pushes.single.amountPaise, 100000);
        late PaymentStatus second;
        be.status('k').then((v) => second = v);
        a.flushMicrotasks();
        expect(second, PaymentStatus.success); // success lands AFTER the refund
      });
    },
  );

  test(
    'cancelRace: cancel says true, then a success push contradicts it',
    () {
      fakeAsync((a) {
        be.mode = BackendMode.cancelRace;
        final pushes = <StatusPush>[];
        be.updates.listen(pushes.add);
        be.create('k');
        a.flushMicrotasks();
        late bool ok;
        be.cancel('k').then((v) => ok = v);
        a.flushMicrotasks();
        expect(ok, isTrue);
        expect(be.cancelCallsFor('k'), 1);
        a.elapse(const Duration(milliseconds: 100));
        expect(pushes.single.status, PaymentStatus.success);
        late PaymentStatus after;
        be.status('k').then((v) => after = v);
        a.flushMicrotasks();
        expect(after, PaymentStatus.success); // the server's truth wins
      });
    },
  );

  test('cancel after settlement returns false and changes nothing', () {
    fakeAsync((a) {
      be.mode = BackendMode.success;
      be.create('k');
      a.flushMicrotasks();
      poll('k', 3);
      a.flushMicrotasks();
      late bool ok;
      be.cancel('k').then((v) => ok = v);
      a.flushMicrotasks();
      expect(ok, isFalse);
      late PaymentStatus s;
      be.status('k').then((v) => s = v);
      a.flushMicrotasks();
      expect(s, PaymentStatus.success);
    });
  });
}
