# DESIGN

## The state machine

`PaymentBloc` (`lib/machine/`) — plain Dart: no fake, no widgets, and no Flutter
import even transitively, which is why its durations live in
`core/time/payment_timing.dart` and not beside the curves. **One** `on<PaymentEvent>` with `sequential()`, not one per event type: separate
registrations each get their own transformer, so ordering *between* types would
not be guaranteed. One handler means a poll, a push, a timer and a tap are a
single queue in arrival order. Every handler is synchronous — async work is
launched from a handler and returns as another event — so `emit` is never called
across an await. States are sealed; the screen is a `switch`.

```
Editing ──tap Pay (new key, record written)──▶ Sending
Sending ──create returns / our 5 s timeout──▶ Confirming      (clock starts HERE)
Confirming ──terminal answer──▶ ConfirmingExit ──250 ms──▶ Succeeded | PaymentFailed
Confirming ──10.0 s deadline──▶ StillConfirming ──late answer / push──▶ terminal
Succeeded ──failed push (B3)──▶ PaymentFailed
PaymentFailed ──success push (B4)──▶ absorbed, nothing emitted
any terminal ──Done / Go to home / Go back──▶ Editing         (fresh key next tap)
```

`ConfirmingExit` is a state, not a widget animation, because the truth can change
while it runs: a push during those 250 ms rewrites its outcome. `Confirming`
carries an absolute `deadline` and the ring reads `clock.now()` each frame — so a
resume emits nothing, shows true remaining time, and its test needs no real
waiting. Dependencies are injected (`get_it`/`injectable` in `lib/di/` only;
nothing in `domain/`, `machine/` or `data/` is annotated). `BackendMode` lives
only in the sheet and the tests. "Does not paint twice" is structural: a push in
`PaymentFailed` emits nothing, so there is no second state to rebuild from.

## B3 — success, then a push saying failed

**The screen ends on Failed** — not on a cost argument, since neither direction
is harmless, but because the push is the same authority correcting itself about
the same attempt. B4 fixes the other half by fiat, so the rule cannot be
symmetric "newest wins"; what is left is coherent: **`failed` is a sink.** A
failure is never overturned, a success is. The record follows the same rule.

Directional, **not time-boxed**: I did not write "a push within 600 ms", because
behaviour depending on whether a push beat an animation is a race the user can
feel but not explain, and is untestable without pumping a widget.

**The risk this leaves.** A payment that really succeeded can end on Failed, and
Try again mints a *new* key — so it double-pays. Nothing reconciles it: launch
re-checks only non-terminal records, per requirement 5. B4 creates this; I did
not invent a state to escape it.

**Returning to Pay clears the amount — after Success and Go to home, not after
Go back.** The brief says only that the key is fresh. Leaving `₹4,200` typed
with an enabled CTA, on a payment that already succeeded, is one tap from a
double-pay that a fresh key guarantees idempotency will not catch. After a
failure nothing left the account, so what was typed stays.

## The three I am least sure about

1. **B4's push is dropped from the record too.** A row saying `Failed` when the
   server says success is a lie on Pay, indefinitely. Both honest fixes need
   design that does not exist — a third row state, or a notification — so I left
   the gap visible.
2. **Polling stops when you leave Still confirming.** The row keeps `CHECKING`
   and is re-checked next launch. The brief says this is my call; a reconciler
   would be more correct and more code.
3. **The ring exit, where the file and the table disagree.** ③ Flow & timing says
   a terminal answer "cuts straight" and the ring "does not finish, fill, or
   animate out". §06 Motion and ④ Motion specify the 250 ms run-to-zero. I
   followed the table, as instructed — and am telling you, as also instructed.
