/// The fake payment backend for the Fave take-home.
///
/// Pick a [BackendMode] before calling [create]; the mode is captured per key
/// at create time, so changing it afterwards affects only the next attempt.
///
/// Time passes through `Future.delayed`, so `package:fake_async` drives every
/// delay in a test without waiting.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum PaymentStatus {
  pending,
  success,
  failed,

  /// Part of the amount came back. Carried on a push with [StatusPush.amountPaise].
  refunded,
}

enum BackendMode {
  /// pending, pending, success.
  success,

  /// pending, failed.
  declined,

  /// B1 — create never returns. status(key): pending, then success.
  lostResponse,

  /// B2 — status returns pending and never stops.
  pendingForever,

  /// B3 — pending, success; then a push saying failed, [flipDelay] later.
  flipAfterSuccess,

  /// B4 — pending, failed; then a push saying success, [lateSuccessDelay] later.
  lateSuccess,

  /// pending; a refunded push for part of the amount arrives BEFORE the poll
  /// says success; then the poll says success.
  refundBeforeSuccess,

  /// cancel(key) returns true, and a success push arrives [cancelRaceDelay]
  /// later anyway: the server settled at the same instant.
  cancelRace,
}

/// A status change the backend pushes to the app, on its own schedule.
class StatusPush {
  const StatusPush(this.key, this.status, {this.amountPaise});
  final String key;
  final PaymentStatus status;

  /// Set on [PaymentStatus.refunded] pushes: how much came back.
  final int? amountPaise;

  @override
  String toString() =>
      'StatusPush($key, ${status.name}${amountPaise == null ? '' : ', ₹${amountPaise! / 100}'})';
}

/// What the app talks to. Depend on this, not on [FakePaymentBackend].
abstract class PaymentBackend {
  /// Creates the payment identified by the app's own [key].
  /// Returns the server's id. May time out — that is the app's problem.
  Future<String> create(String key);

  /// Current status of the payment the app created under [key].
  Future<PaymentStatus> status(String key);

  /// Pushes. Can arrive at any time, including after the app has already
  /// reached a terminal state for the key. Broadcast: subscribe before you
  /// create, or you will miss them.
  Stream<StatusPush> get updates;

  /// Ask the server to cancel. True if it had not settled yet, in
  /// which case the payment is failed. False if it had — and then whatever
  /// it settled to still stands, and may still arrive as a push.
  Future<bool> cancel(String key);
}

class _Payment {
  _Payment(this.id, this.mode);
  final String id;
  final BackendMode mode;
  int statusCalls = 0;
  PaymentStatus? truth; // once the server has settled, this is it
  bool pushScheduled = false;
}

class FakePaymentBackend implements PaymentBackend {
  FakePaymentBackend({
    this.latency = const Duration(milliseconds: 150),
    this.flipDelay = const Duration(milliseconds: 300),
    this.lateSuccessDelay = const Duration(minutes: 2),
    this.refundDelay = const Duration(milliseconds: 100),
    this.cancelRaceDelay = const Duration(milliseconds: 100),
    this.refundPaise = 100000,
    this.storePath,
  }) {
    _load();
  }

  /// When set, payments survive the process dying: keys, outcomes and call
  /// counts are written to this file and read back by the next instance.
  /// Left null, everything is in memory and a restart forgets it all.
  final String? storePath;

  /// how long after the first pending poll the refunded push arrives.
  final Duration refundDelay;

  /// how long after a successful cancel the contradicting success push arrives.
  final Duration cancelRaceDelay;

  /// how much of the amount is refunded (₹1,000 by default).
  final int refundPaise;

  int cancelCallsFor(String key) => _cancelCalls[key] ?? 0;
  final _cancelCalls = <String, int>{};

  /// Round-trip time for create and status. Zero is fine in tests.
  final Duration latency;

  /// B3: how long after the poll said success the failed push arrives.
  final Duration flipDelay;

  /// B4: how long after the poll said failed the success push arrives.
  final Duration lateSuccessDelay;

  /// Mode for the *next* create. Captured per key.
  BackendMode mode = BackendMode.success;

  final _payments = <String, _Payment>{};
  final _pushes = StreamController<StatusPush>.broadcast();
  final _timers = <Timer>[];
  int _nextId = 1;

  // ---- introspection, for your tests and ours ----

  /// How many distinct payments exist. B1 handled correctly leaves this at 1.
  int get paymentsCreated => _payments.length;

  /// How many times create was called for [key]. Should be 1.
  int createCallsFor(String key) => _createCalls[key] ?? 0;
  final _createCalls = <String, int>{};

  /// How many times status was called for [key].
  int statusCallsFor(String key) => _payments[key]?.statusCalls ?? 0;

  @override
  Stream<StatusPush> get updates => _pushes.stream;

  @override
  Future<String> create(String key) {
    _createCalls[key] = createCallsFor(key) + 1;
    // Same key, same payment. This is the server's half of idempotency.
    final p = _payments.putIfAbsent(
      key,
      () => _Payment(_upiRef(_nextId++), mode),
    );
    _save();
    if (p.mode == BackendMode.lostResponse) {
      // The server created it. The response never arrives.
      return Completer<String>().future;
    }
    return _after(latency, () => p.id);
  }

  /// Zero latency resolves on the next microtask, so tests that only
  /// flushMicrotasks still see the answer. Anything else is a real timer.
  Future<T> _after<T>(Duration d, T Function() body) =>
      d == Duration.zero ? Future.microtask(body) : Future.delayed(d, body);

  @override
  Future<PaymentStatus> status(String key) async {
    final p = _payments[key];
    // async, so this arrives as a Future error rather than a synchronous throw
    if (p == null) {
      throw StateError('Unknown key: $key');
    }
    return _after(latency, () => _answer(key, p));
  }

  PaymentStatus _answer(String key, _Payment p) {
    final n = p.statusCalls++;
    _save();
    if (p.truth != null) {
      return p.truth!;
    }
    switch (p.mode) {
      case BackendMode.success:
        return n < 2
            ? PaymentStatus.pending
            : _settle(p, PaymentStatus.success);
      case BackendMode.declined:
        return n < 1 ? PaymentStatus.pending : _settle(p, PaymentStatus.failed);
      case BackendMode.lostResponse:
        return n < 1
            ? PaymentStatus.pending
            : _settle(p, PaymentStatus.success);
      case BackendMode.pendingForever:
        return PaymentStatus.pending;
      case BackendMode.flipAfterSuccess:
        if (n < 1) {
          return PaymentStatus.pending;
        }
        // The poll says success. The server then reverses itself.
        _schedulePush(key, p, flipDelay, PaymentStatus.failed);
        return PaymentStatus.success;
      case BackendMode.lateSuccess:
        if (n < 1) {
          return PaymentStatus.pending;
        }
        _schedulePush(key, p, lateSuccessDelay, PaymentStatus.success);
        return PaymentStatus.failed;
      case BackendMode.refundBeforeSuccess:
        if (n < 1) {
          // The refund is pushed before the app has even heard "success".
          _schedulePush(
            key,
            p,
            refundDelay,
            PaymentStatus.refunded,
            amount: refundPaise,
            settles: false,
          );
          return PaymentStatus.pending;
        }
        return _settle(p, PaymentStatus.success);
      case BackendMode.cancelRace:
        return PaymentStatus.pending; // resolved by cancel(), not by polling
    }
  }

  @override
  Future<bool> cancel(String key) async {
    _cancelCalls[key] = cancelCallsFor(key) + 1;
    final p = _payments[key];
    if (p == null) {
      throw StateError('Unknown key: $key');
    }
    return _after(latency, () {
      if (p.truth != null) {
        return false;
      }
      p.truth = PaymentStatus.failed;
      _save();
      if (p.mode == BackendMode.cancelRace) {
        // The server settled in the same instant. Its truth wins.
        _schedulePush(
          key,
          p,
          cancelRaceDelay,
          PaymentStatus.success,
          force: true,
        );
      }
      return true;
    });
  }

  PaymentStatus _settle(_Payment p, PaymentStatus s) {
    p.truth = s;
    _save();
    return s;
  }

  /// Looks like a UPI reference: twelve digits, stable per payment.
  String _upiRef(int n) => (427118330920 + n).toString();

  void _load() {
    final path = storePath;
    if (path == null) {
      return;
    }
    final f = File(path);
    if (!f.existsSync()) {
      return;
    }
    // A store written by a different version must not crash construction.
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } on Object {
      return;
    }
    try {
      _nextId = json['nextId'] as int? ?? 1;
      final created = json['createCalls'] as Map<String, dynamic>? ?? {};
      for (final e in created.entries) {
        _createCalls[e.key] = e.value as int;
      }
      final cancelled = json['cancelCalls'] as Map<String, dynamic>? ?? {};
      for (final e in cancelled.entries) {
        _cancelCalls[e.key] = e.value as int;
      }
      final payments = json['payments'] as Map<String, dynamic>? ?? {};
      for (final e in payments.entries) {
        final m = e.value as Map<String, dynamic>;
        final mode =
            BackendMode.values.where((v) => v.name == m['mode']).firstOrNull;
        // A payment written by a version that knows a mode this one does not
        // is dropped rather than guessed at.
        if (mode == null) {
          continue;
        }
        final p = _Payment(m['id'] as String, mode);
        p.statusCalls = m['statusCalls'] as int? ?? 0;
        final truth = m['truth'] as String?;
        if (truth != null) {
          p.truth =
              PaymentStatus.values.where((v) => v.name == truth).firstOrNull;
        }
        _payments[e.key] = p;
      }
    } on Object {
      // Partial load is fine: the app re-checks anything non-terminal anyway.
      return;
    }
  }

  void _save() {
    final path = storePath;
    if (path == null) {
      return;
    }
    File(path).writeAsStringSync(
      jsonEncode({
        'nextId': _nextId,
        'createCalls': _createCalls,
        'cancelCalls': _cancelCalls,
        'payments': {
          for (final e in _payments.entries)
            e.key: {
              'id': e.value.id,
              'mode': e.value.mode.name,
              'statusCalls': e.value.statusCalls,
              'truth': e.value.truth?.name,
            },
        },
      }),
    );
  }

  void _schedulePush(
    String key,
    _Payment p,
    Duration after,
    PaymentStatus s, {
    int? amount,
    bool settles = true,
    bool force = false,
  }) {
    if (p.pushScheduled && !force) {
      return;
    }
    p.pushScheduled = true;
    _timers.add(
      Timer(after, () {
        if (settles) {
          p.truth = s;
        }
        if (!_pushes.isClosed) {
          _pushes.add(StatusPush(key, s, amountPaise: amount));
        }
      }),
    );
  }

  /// Forget everything, including pushes not yet delivered. Use between test cases.
  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  /// Forgets every payment and deletes the store file. For tests, and for
  /// staging a key the app still holds but the server no longer knows.
  void reset() {
    _cancelTimers();
    _payments.clear();
    _createCalls.clear();
    _cancelCalls.clear();
    mode = BackendMode.success;
    // _nextId is deliberately not reset: a reference this fake has issued is
    // never issued again, so a record the app still holds cannot collide.
    final path = storePath;
    if (path != null && File(path).existsSync()) {
      File(path).deleteSync();
    }
  }

  /// Stops pending pushes and closes the stream. Deliberately does **not**
  /// touch the store: disposing on shutdown must not lose what was persisted.
  Future<void> dispose() {
    _cancelTimers();
    return _pushes.close();
  }
}
