# fave_fake_backend

The backend for the Fave take-home. Pure Dart, no Flutter dependency.

```dart
import 'package:fave_fake_backend/fave_fake_backend.dart';

final backend = FakePaymentBackend();        // PaymentBackend
backend.mode = BackendMode.flipAfterSuccess; // pick before create; captured per key

final id = await backend.create(key);        // may never return (B1) — timeout is yours
final s  = await backend.status(key);        // pending | success | failed
backend.updates.listen((push) { ... });      // pushes, any time, even after terminal — subscribe BEFORE create
```

## Persistence

By default everything is in memory and a restart forgets it. Pass a file path and
keys, outcomes and call counts survive the process dying:

```dart
FakePaymentBackend(storePath: '${dir.path}/payments.json')
```

(Uses `dart:io`, so mobile and desktop only — not web.)

In a Flutter app, get the directory from `path_provider`
(`getApplicationDocumentsDirectory()`) in your composition root.

**This store is the backend's, not yours.** If you persist anything of your own,
keep it in a separate file — that is the only way to stage a record you hold for
a key the backend has forgotten.

**A mode's sequence continues across a restart.** Call counts persist too, so a
payment that answered `pending` before the process died answers the *next* step
of its sequence to the re-check, not the first one again.

**If you vendor this package** (copy it into your project rather than referencing
it in place), run `dart pub get` inside the package directory once, or your
editor and `flutter analyze` will report unresolved imports in its `test/`.

Add it as a path dependency:

```yaml
dependencies:
  fave_fake_backend:
    path: ../fave_fake_backend
```

Depend on `PaymentBackend` in your code, not on `FakePaymentBackend`.

## Modes

| Mode | status(key) sequence | Push |
|---|---|---|
| `success` | pending, pending, success | — |
| `declined` | pending, failed | — |
| `lostResponse` (B1) | pending, success — and `create` never returns | — |
| `pendingForever` (B2) | pending, pending, pending… | — |
| `flipAfterSuccess` (B3) | pending, success | `failed`, 300 ms after the success poll |
| `lateSuccess` (B4) | pending, failed | `success`, 2 min after the failed poll (`lateSuccessDelay`) |

Sequences are by call count, not by time. Delays go through `Future.delayed`,
so `package:fake_async` drives them in tests. `latency: Duration.zero` makes
calls resolve on the next microtask.

## For your tests

- `paymentsCreated` — how many distinct payments exist. B1 handled right leaves this at 1.
- `createCallsFor(key)` / `statusCallsFor(key)` — call counts.
- `reset()` between cases: cancels undelivered pushes **and deletes the store file**.
- `dispose()` on shutdown: cancels pending pushes and closes the stream. It **does not** touch the store — what was persisted survives.
- `create` returns a twelve-digit id that looks like a UPI reference. In `lostResponse` you never get it.

`test/fave_fake_backend_test.dart` is the executable reference for every mode.
