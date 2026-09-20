# fave_pay

One payment flow, five states, built to the Figma against `fave_fake_backend`.

Read [DESIGN.md](DESIGN.md) for the state machine, the B3 decision and the three
calls I am least sure about. What I cut is below.

## Running it

```bash
flutter pub get
flutter run
```

Built and driven on an **iPhone 16 simulator**, which is 393 pt wide — the design's
own width, so every value in §06 maps 1:1 with no scaling.

The backend is vendored at `packages/fave_fake_backend` as a path dependency.
Its own `test/` folder needs `dart pub get` run inside the package before its
imports resolve — its README says so — so it is excluded from this project's
`analysis_options.yaml`. It is not our code and it carries its own lints. If you
want to run the package's tests:

```bash
cd packages/fave_fake_backend && dart pub get && dart test
```

## What I cut, and why

Scope was mine to cut, so this is the whole list — the uncomfortable ones too.
One line each.

**Not built**

- **`cancel()`** — on the interface, never called; nothing in this flow needs it.
- **Partial refunds** — `refunded` is outside the six modes; the push is absorbed
  without crashing and no amount is re-rendered from it.
- **`refundBeforeSuccess` / `cancelRace`** — not on the sheet; the brief names six.
- **Durable write ordering** — `create` fires before the initial record write
  lands, so a kill in that window leaves money on the server with no local row.
- **Explicit store-failure handling** — a rejected write is not surfaced as an
  event; I would want a revision counter and an ack before claiming it worked.
- **`UNRESOLVED` → `CHECKING` recovery** — a row the backend later *does* know
  keeps its badge; the requirement only asks that an unknown key show unresolved.
- **Request tokens on manual status checks** — a `pending` push can clear
  "Checking…" early; there are no automatic polls left by then, so it is narrow.
- **Background reconciliation** after leaving Still confirming — the row carries
  `CHECKING` and is re-checked on next launch instead.

**Not tested**

- **A hand-written `PaymentBackend` double** — I test against the real fake, which
  is the executable reference and cannot drift from the thing you will run.
- **Golden tests** — they would lock in my render, not the Figma; the frames are
  the oracle and comparing against them is a human job.
- **A scheduler-derived test clock** — `Harness.elapse` advances the clock by the
  whole duration before `fake_async` runs intermediate callbacks, so a callback
  at 2 s observes 4 s. Real, and it masks nothing the suite currently asserts.
- **Android** — see the note at the end; I could not build it here.

**Deliberate deviations from the frame**

- **The B1 reference wraps to two lines.** A server id fits the designed single
  line; our 36-character fallback key does not, and a reference you cannot read
  is not a reference.
- **The caret jumps to the end of the amount on every edit**, so editing the
  middle of a number is awkward. Grouping shifts everything right of the caret
  and I would rather it be predictable than subtly wrong.
- **The ring runs to zero over 250 ms** — §06 and ④ Motion say so, ③ Flow &
  timing says it "cuts straight". The table wins, per the brief, and I am
  telling you.

## Dependency injection

`get_it` + `injectable`. The whole graph is one `@module` in
[`lib/di/app_module.dart`](lib/di/app_module.dart); `lib/di/` is the only place
that imports either package.

Nothing in `domain/`, `machine/` or `data/` is annotated. That is deliberate — a
container is a wiring detail of the app, and annotating the machine would couple
it to a DI framework it does not need. `PaymentBloc` still takes four constructor
arguments, which is exactly how every test builds it.

The generated `injection.config.dart` is committed, so `flutter test` and
`flutter run` work without running the generator. After changing the module:

```bash
dart run build_runner build
```

## Tests

```bash
flutter test
```

State is managed with **bloc** (`bloc` + `bloc_concurrency` in the machine,
`flutter_bloc` for the one `BlocBuilder`). The bloc has no Flutter import —
`grep -rn "package:flutter" lib/machine/` is empty, which is why the timings it
schedules on live in `core/time/payment_timing.dart` and not next to the curves.

28 tests, all passing on Flutter 3.41.1, verified over consecutive runs on a
fresh clone. The six the brief asks for:

| What | Where |
|---|---|
| B1 — the 5 s timeout calls `status(key)`, never `create` again | `test/machine/b1_lost_response_test.dart` |
| B2 — ten seconds of pending, ring reaches zero exactly once | `test/machine/b2_pending_forever_test.dart` |
| B3 — a failed push after success | `test/machine/b3_flip_after_success_test.dart` |
| B5 — the ring shows true remaining time after a resume | `test/machine/b5_resume_test.dart` |
| the badge animation ends on the truth when a push interrupts it | `test/widget/badge_interrupted_test.dart` |
| a record left pending by a kill is re-checked once on launch | `test/machine/relaunch_recheck_test.dart` |

Plus the optional ones: B4, the happy path, Declined and Try again
(`test/machine/happy_path_and_b4_test.dart`), the Indian grouping and validation
boundaries (`test/unit/amount_test.dart`), and the launch race
(`test/machine/launch_race_test.dart`) — `main` fires `start()` without awaiting
it, so Pay is on screen while the store is still being read.

Only one test pumps a widget — the badge one, because its claim is about what is
on screen while something animates. Everything else drives the bloc directly with
`fake_async` and an injected clock, so nothing waits. `test/machine/harness.dart`
wraps the two things a bloc test has to get right: `send` settles the event queue
(bloc delivers through a stream), and `elapse` moves the injected clock *and* the
timers together, because the ring reads wall-clock time.

`dart format .` and `flutter analyze` are clean — verified on a fresh clone, not
just in my working copy.

## Layout

```
lib/
  core/design/     every colour, type role, metric, duration and string — once
  core/time/       Clock (injected; TestClock for tests)
  core/util/       Indian grouping, relative time
  domain/model/    Recipient, AmountValidation (a type, not a string), PaymentRecord
  domain/port/     PaymentStore, KeyGenerator — the flow talks to these, not plugins
  di/              get_it + injectable — the composition root, and the only
                   place that imports either
  machine/         PaymentBloc — plain Dart, no Flutter import even
                   transitively, one sequential entrance
  data/            FilePaymentStore (our file, separate from the backend's)
  ui/
    pay_screen.dart  the host: a BlocBuilder and a switch, nothing else
    screens/         one file per state — pay, confirming, success, failed, still
    widgets/         one concern per file, re-exported by pay_widgets.dart
    sheets/          the backend sheet (the only place BackendMode lives) and
                     the recipient sheet, on a route that owns the 250 ms slide
```

## Notes

- **Onest** is bundled in `assets/fonts/` as five static instances cut from the
  Google Fonts variable file, so the build needs no network and the weights are
  exactly 400 / 500 / 600 / 700 / 800. Its SIL Open Font License ships beside
  them in `assets/fonts/OFL.txt`.
- **The amount field refuses input it cannot represent** rather than stripping
  it. A numeric keypad cannot produce `.` or `-`, but a paste can, and quietly
  deleting them turns `42.50` into ₹4,250. One known wart: the caret jumps to
  the end on every edit, so editing the middle of a number is awkward.
- The 56 pt top padding is measured from the top of the screen, as §06 says, not
  from the safe area — on a notched device the top bar clears the status bar by a
  few points. Faithful to the spec; say the word if you want it inset instead.
- `FakePaymentBackend` is named in exactly two places: the DI module, which has
  to construct something (the Figma's own wiring snippet does the same), and the
  backend sheet. `BackendMode` is named only in the sheet and the tests. The bloc
  and every view see `PaymentBackend` and nothing else.
- **Android is untested.** The project targets it and nothing in the code is
  platform-specific — the only plugin is `path_provider` — but I built and drove
  the iOS simulator only. I tried an `assembleDebug` to at least prove it
  compiles; it failed fetching Flutter's Android engine JARs from
  `storage.googleapis.com` on this machine, so it never reached compilation.
  Untested rather than known-broken, and I would rather say so than let you
  find out.
- The backend's store and ours are two separate files in the app's documents
  directory. Deleting `backend_payments.json` while the app is dead is how I
  produced the `UNRESOLVED` badge.
