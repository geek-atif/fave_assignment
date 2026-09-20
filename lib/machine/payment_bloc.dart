import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:fave_fake_backend/fave_fake_backend.dart';

import '../core/time/payment_timing.dart';
import '../core/time/clock.dart';
import '../domain/model/payment_record.dart';
import '../domain/port/key_generator.dart';
import '../domain/port/payment_store.dart';
import 'payment_event.dart';
import 'payment_state.dart';

/// The whole flow, with no Flutter in it. Timers and polling belong here, not
/// in a widget's initState, and they stop when this does.
///
/// One `on<PaymentEvent>` registration, not one per event type: separate
/// registrations each get their own transformer, so ordering *between* types
/// would not be guaranteed. A single sequential handler means a poll, a push,
/// a timer and a tap are one queue in arrival order — the machine has one
/// entrance and therefore no race.
///
/// Every handler is synchronous. The asynchronous work — create, status, the
/// store — is launched from a handler and comes back as another event, so
/// `emit` is never called across an await.
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc({
    required PaymentBackend backend,
    required PaymentStore store,
    required KeyGenerator keys,
    Clock clock = const SystemClock(),
  }) : _backend = backend,
       _store = store,
       _keys = keys,
       _clock = clock,
       super(const Editing(form: PayForm.initial, recent: [])) {
    on<PaymentEvent>(_onEvent, transformer: sequential());
    // Subscribe before you create, or you will miss the push.
    _pushes = _backend.updates.listen(
      (push) => add(PushArrived(push.key, push.status)),
    );
  }

  final PaymentBackend _backend;
  final PaymentStore _store;
  final KeyGenerator _keys;
  final Clock _clock;

  late final StreamSubscription<StatusPush> _pushes;

  Timer? _pollTimer;
  Timer? _deadlineTimer;
  Timer? _exitTimer;

  /// The two most recent payments. The same records the history rows and the
  /// live flow both read — there is only one copy.
  List<PaymentRecord> _recent = const [];

  /// Pay is gated until the stored records are installed, and [start] runs
  /// once however many times it is called.
  bool _ready = false;
  bool _starting = false;

  /// Work that is already in flight when the bloc closes — a poll, a push, a
  /// store write — comes back as an event. Dropping those is correct: nothing
  /// is listening any more, and `Bloc.add` throws after `close`.
  @override
  void add(PaymentEvent event) {
    if (isClosed) {
      return;
    }
    super.add(event);
  }

  /// Read the store and give every record that never reached a terminal state
  /// exactly one status(key) call. A key the backend has forgotten is
  /// unresolved: never success, never failure.
  Future<void> start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    // Install what is on disk before Pay is enabled. Nothing can have been
    // added yet, so this is the one safe whole-list install.
    final stored = await _store.load();
    add(RecordsRestored(stored));
    // Then give every record that never reached a terminal state exactly one
    // status(key) — through the same events a live poll or push arrives on,
    // so there is one place where a status answer changes a record.
    for (final record in stored.where((r) => !r.isTerminal)) {
      _pollOnce(record.key);
    }
  }

  // ------------------------------------------------------------------ reduce

  void _onEvent(PaymentEvent event, Emitter<PaymentState> emit) {
    switch (event) {
      case RecordsRestored(:final records):
        // Union by key rather than replace, so anything that did slip in is
        // kept rather than silently dropped.
        _recent = _mergeAll(records);
        _ready = true;
        emit(_withRecent(state));

      case RecordsLoaded(:final records):
        _recent = records;
        emit(_withRecent(state));

      case RecipientPicked(:final recipient):
        if (state case Editing(:final form, :final recent)) {
          emit(
            Editing(
              form: form.copyWith(recipient: recipient),
              recent: recent,
            ),
          );
        }

      case AmountEdited(:final rupees):
        if (state case Editing(:final form, :final recent)) {
          emit(
            Editing(
              form: rupees == null
                  ? form.copyWith(clearAmount: true)
                  : form.copyWith(amountRupees: rupees),
              recent: recent,
              ready: _ready,
            ),
          );
        }

      case NoteEdited(:final note):
        if (state case Editing(:final form, :final recent)) {
          emit(
            Editing(
              // Whitespace is not a note: it would render as empty curly
              // quotes on Success.
              form: (note == null || note.trim().isEmpty)
                  ? form.copyWith(clearNote: true)
                  : form.copyWith(note: note),
              recent: recent,
              ready: _ready,
            ),
          );
        }

      case PayTapped():
        // Not ready means the restore has not landed; starting an attempt now
        // is what M05 exists to prevent.
        if (state case Editing(:final form, ready: true) when form.canPay) {
          _beginAttempt(form, emit);
        }

      case TryAgainTapped():
        // A retry after a terminal failed is a new payment, not a resend.
        if (state is PaymentFailed) {
          _beginAttempt(state.form, emit);
        }

      case ReturnToPayTapped(:final clearForm):
        _cancelTimers();
        emit(
          Editing(
            // The recipient survives — only the amount and note are about the
            // attempt that just ended.
            form: clearForm
                ? state.form.copyWith(clearAmount: true, clearNote: true)
                : state.form,
            recent: _recent,
            ready: _ready,
          ),
        );

      case CheckStatusTapped():
        if (state case StillConfirming(:final attempt, checking: false)) {
          emit(
            StillConfirming(
              attempt: attempt,
              checking: true,
              form: state.form,
              recent: _recent,
            ),
          );
          _pollOnce(attempt.key);
        }

      case CreateReturned(:final key, :final id):
        if (state case Sending(:final attempt) when attempt.key == key) {
          final withId = attempt.withReference(id);
          _recordLocally(withId.toRecord(outcome: RecordOutcome.inFlight));
          _enterConfirming(withId, emit);
        }

      case CreateTimedOut(:final key):
      case CreateThrew(:final key):
        // The server may already have it. Do not create again — poll.
        if (state case Sending(:final attempt) when attempt.key == key) {
          _enterConfirming(attempt, emit);
        }

      case StatusAnswered(:final key, :final status):
      case PushArrived(:final key, :final status):
        _applyStatus(key, status, emit);

      case StatusThrew(:final key):
        // A live attempt the backend has forgotten. Keep the row honest and
        // let the deadline decide the screen.
        _markRecord(key, RecordOutcome.unresolved, emit);
        if (state case StillConfirming(
          :final attempt,
          checking: true,
        ) when attempt.key == key) {
          emit(
            StillConfirming(
              attempt: attempt,
              checking: false,
              form: state.form,
              recent: _recent,
            ),
          );
        }

      case PollDue(:final key):
        // Polls land at 0, 2, 4, 6 and 8 seconds. The tick at 10.0 s coincides
        // with the deadline, and the deadline wins — firing a sixth request we
        // have already decided to stop waiting for would be pure waste.
        if (state case Confirming(
          :final attempt,
          :final deadline,
        ) when attempt.key == key && _clock.now().isBefore(deadline)) {
          _pollOnce(key);
        }

      case DeadlineReached(:final key):
        if (state case Confirming(:final attempt) when attempt.key == key) {
          _cancelTimers();
          emit(
            StillConfirming(
              attempt: attempt,
              checking: false,
              form: state.form,
              recent: _recent,
            ),
          );
        }

      case RingExitFinished(:final key):
        if (state case ConfirmingExit(
          :final attempt,
          :final outcome,
          :final answeredAt,
        ) when attempt.key == key) {
          _settle(attempt, outcome, emit, at: answeredAt);
        }

      case AppResumed():
        _onResume();
    }
  }

  // ------------------------------------------------------------- transitions

  void _beginAttempt(PayForm form, Emitter<PaymentState> emit) {
    _cancelTimers();
    final rupees = form.amount.rupees;
    if (rupees == null) {
      return;
    }
    final attempt = Attempt(
      // Generated in the app, before create.
      key: _keys.next(),
      recipient: form.recipient,
      amountRupees: rupees,
      note: form.note,
      startedAt: _clock.now(),
    );
    // Recorded when the attempt starts, updated when it settles.
    _recordLocally(attempt.toRecord(outcome: RecordOutcome.inFlight));
    emit(Sending(attempt: attempt, form: form, recent: _recent));

    // The 5 s timeout is ours; the backend never times out.
    unawaited(
      _backend
          .create(attempt.key)
          .timeout(PaymentTiming.createTimeout)
          .then(
            (id) => add(CreateReturned(attempt.key, id)),
            onError: (Object e) => add(
              e is TimeoutException
                  ? CreateTimedOut(attempt.key)
                  : CreateThrew(attempt.key),
            ),
          ),
    );
  }

  void _enterConfirming(Attempt attempt, Emitter<PaymentState> emit) {
    // The clock starts here — after create returned, or after the timeout.
    final now = _clock.now();
    emit(
      Confirming(
        attempt: attempt,
        startedAt: now,
        deadline: now.add(PaymentTiming.countdown),
        form: state.form,
        recent: _recent,
      ),
    );
    _startPolling(attempt.key, deadlineIn: PaymentTiming.countdown);
    // The first status call is made immediately.
    _pollOnce(attempt.key);
  }

  void _startPolling(String key, {required Duration deadlineIn}) {
    _pollTimer?.cancel();
    _deadlineTimer?.cancel();
    _pollTimer = Timer.periodic(
      PaymentTiming.pollInterval,
      (_) => add(PollDue(key)),
    );
    _deadlineTimer = Timer(
      deadlineIn.isNegative ? Duration.zero : deadlineIn,
      () => add(DeadlineReached(key)),
    );
  }

  void _pollOnce(String key) {
    unawaited(
      _backend
          .status(key)
          .then(
            (status) => add(StatusAnswered(key, status)),
            onError: (Object _) => add(StatusThrew(key)),
          ),
    );
  }

  /// Polls and pushes land here identically — the machine cannot tell them
  /// apart, and nothing about the flow should depend on which it was.
  void _applyStatus(String key, PaymentStatus status, Emitter<PaymentState> e) {
    if (status == PaymentStatus.pending) {
      _clearChecking(key, e);
      return;
    }
    // A partial refund is not one of the six modes this screen is designed
    // for. Record nothing, paint nothing, do not crash.
    if (status == PaymentStatus.refunded) {
      return;
    }

    switch (state) {
      case Confirming(:final attempt) when attempt.key == key:
        _beginRingExit(attempt, status, e);

      case ConfirmingExit(:final attempt, :final exitFrom)
          when attempt.key == key:
        // The exit is still running. Take the newer answer, subject to the
        // same rule as below: a success never overturns a failure.
        if (status == PaymentStatus.failed) {
          e(
            ConfirmingExit(
              attempt: attempt,
              outcome: status,
              exitFrom: exitFrom,
              // The correction is the answer that counts now.
              answeredAt: _clock.now(),
              form: state.form,
              recent: _recent,
            ),
          );
        }

      case StillConfirming(:final attempt) when attempt.key == key:
        // Not terminal: an answer that arrives after the deadline is applied.
        _cancelTimers();
        _settle(attempt, status, e);

      case Succeeded(:final attempt) when attempt.key == key:
        // B3. Our decision, argued in DESIGN.md: a later `failed` corrects a
        // success — we stop claiming money moved. The reverse never happens.
        if (status == PaymentStatus.failed) {
          _settle(attempt, status, e);
        }

      case PaymentFailed(:final attempt) when attempt.key == key:
        // B4. Terminal stays terminal. No flip, no crash, and — because
        // nothing is emitted — no second paint.
        break;

      case Sending(:final attempt) when attempt.key == key:
        // A push beat create's response. Confirming is where answers are
        // applied, so go there and let the poll agree.
        _enterConfirming(attempt, e);
        _applyStatus(key, status, e);

      default:
        // A push for an attempt no screen is showing — the user left Still
        // confirming, or this is an older key. The row still tells the truth.
        _settleRecordOnly(key, status, e);
    }
  }

  void _clearChecking(String key, Emitter<PaymentState> emit) {
    if (state case StillConfirming(
      :final attempt,
      checking: true,
    ) when attempt.key == key) {
      emit(
        StillConfirming(
          attempt: attempt,
          checking: false,
          form: state.form,
          recent: _recent,
        ),
      );
    }
  }

  void _beginRingExit(
    Attempt attempt,
    PaymentStatus outcome,
    Emitter<PaymentState> emit,
  ) {
    final confirming = state as Confirming;
    _cancelTimers();
    final at = _clock.now();
    emit(
      ConfirmingExit(
        attempt: attempt,
        outcome: outcome,
        exitFrom: confirming.fractionAt(at),
        answeredAt: at,
        form: state.form,
        recent: _recent,
      ),
    );
    _exitTimer = Timer(
      PaymentTiming.ringExit,
      () => add(RingExitFinished(attempt.key)),
    );
  }

  /// [at] is when the answer arrived. It is only different from now when the
  /// 250 ms ring exit ran in between.
  void _settle(
    Attempt attempt,
    PaymentStatus outcome,
    Emitter<PaymentState> emit, {
    DateTime? at,
  }) {
    _cancelTimers();
    at ??= _clock.now();
    final isSuccess = outcome == PaymentStatus.success;
    _recordLocally(
      attempt.toRecord(
        outcome: isSuccess ? RecordOutcome.success : RecordOutcome.failed,
        settledAt: at,
      ),
    );
    emit(
      isSuccess
          ? Succeeded(
              attempt: attempt,
              settledAt: at,
              form: state.form,
              recent: _recent,
            )
          : PaymentFailed(
              attempt: attempt,
              settledAt: at,
              form: state.form,
              recent: _recent,
            ),
    );
  }

  /// A late answer for an attempt no screen is showing. The row follows the
  /// same rule the screen does: a failure is never overturned by a success.
  void _settleRecordOnly(
    String key,
    PaymentStatus status,
    Emitter<PaymentState> emit,
  ) {
    final existing = _recent.where((r) => r.key == key).firstOrNull;
    if (existing == null || existing.outcome == RecordOutcome.failed) {
      return;
    }
    if (existing.outcome == RecordOutcome.success &&
        status != PaymentStatus.failed) {
      return;
    }
    _recordLocally(
      existing.copyWith(
        outcome: status == PaymentStatus.success
            ? RecordOutcome.success
            : RecordOutcome.failed,
        settledAt: _clock.now(),
      ),
    );
    emit(_withRecent(state));
  }

  void _markRecord(
    String key,
    RecordOutcome outcome,
    Emitter<PaymentState> emit,
  ) {
    final existing = _recent.where((r) => r.key == key).firstOrNull;
    if (existing == null || existing.isTerminal) {
      return;
    }
    _recordLocally(existing.copyWith(outcome: outcome));
    emit(_withRecent(state));
  }

  // B5 — the ring shows the true remaining time, not where a paused ticker
  // left off, and exactly one status call happens on the way back in.
  //
  // Nothing is emitted: `deadline` is absolute, so the state is already right
  // and the ring re-reads the clock on its own next frame.
  void _onResume() {
    switch (state) {
      case Confirming(:final attempt, :final deadline):
        final left = deadline.difference(_clock.now());
        _startPolling(attempt.key, deadlineIn: left);
        _pollOnce(attempt.key);
      case _:
        // Sending keeps waiting for its 5 s timeout; the terminal screens and
        // Pay are unchanged by a resume.
        break;
    }
  }

  // ------------------------------------------------------------------ store

  /// Updates the in-memory records and writes through. Callers emit — a record
  /// change on its own is not always a state change.
  void _recordLocally(PaymentRecord record) {
    _recent = _merge(record);
    unawaited(
      _store.save(record).then((saved) {
        // The optimistic merge above is almost always exactly what came back.
        // Only tell the screen when it is not.
        if (!_sameRecords(saved, _recent)) {
          add(RecordsLoaded(saved));
        }
      }),
    );
  }

  static bool _sameRecords(List<PaymentRecord> a, List<PaymentRecord> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  /// Union of what was on disk and what is already in memory, keyed, newest
  /// first, capped.
  List<PaymentRecord> _mergeAll(List<PaymentRecord> restored) {
    final keys = _recent.map((r) => r.key).toSet();
    final next = [..._recent, ...restored.where((r) => !keys.contains(r.key))]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(next.take(PaymentStore.keptRecords));
  }

  List<PaymentRecord> _merge(PaymentRecord record) {
    final next = [record, ..._recent.where((r) => r.key != record.key)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return List.unmodifiable(next.take(PaymentStore.keptRecords));
  }

  PaymentState _withRecent(PaymentState s) => switch (s) {
    Editing() => Editing(form: s.form, recent: _recent, ready: _ready),
    Sending() => Sending(attempt: s.attempt, form: s.form, recent: _recent),
    Confirming() => Confirming(
      attempt: s.attempt,
      startedAt: s.startedAt,
      deadline: s.deadline,
      form: s.form,
      recent: _recent,
    ),
    ConfirmingExit() => ConfirmingExit(
      attempt: s.attempt,
      outcome: s.outcome,
      exitFrom: s.exitFrom,
      answeredAt: s.answeredAt,
      form: s.form,
      recent: _recent,
    ),
    Succeeded() => Succeeded(
      attempt: s.attempt,
      settledAt: s.settledAt,
      form: s.form,
      recent: _recent,
    ),
    PaymentFailed() => PaymentFailed(
      attempt: s.attempt,
      settledAt: s.settledAt,
      form: s.form,
      recent: _recent,
    ),
    StillConfirming() => StillConfirming(
      attempt: s.attempt,
      checking: s.checking,
      form: s.form,
      recent: _recent,
    ),
  };

  // ---------------------------------------------------------------- lifetime

  void _cancelTimers() {
    _pollTimer?.cancel();
    _deadlineTimer?.cancel();
    _exitTimer?.cancel();
    _pollTimer = null;
    _deadlineTimer = null;
    _exitTimer = null;
  }

  @override
  Future<void> close() async {
    _cancelTimers();
    await _pushes.cancel();
    await super.close();
  }
}
