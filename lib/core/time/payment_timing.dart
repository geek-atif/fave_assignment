/// The transaction's clock, in plain Dart.
///
/// These live outside `core/design/fave_motion.dart` on purpose: that file
/// imports `package:flutter/animation.dart` for its curves, and the state
/// machine must not reach Flutter even transitively. Durations the machine
/// schedules on belong here; how something eases belongs there.
abstract final class PaymentTiming {
  /// The countdown the Confirming ring draws, and the deadline it ends on.
  static const countdown = Duration(seconds: 10);

  /// First status call is immediate, then every 2 s: at 0, 2, 4, 6 and 8.
  static const pollInterval = Duration(seconds: 2);

  /// The app's own timeout on `create`. The backend never times out.
  static const createTimeout = Duration(seconds: 5);

  /// A terminal answer runs the sweep to zero over this before the screen
  /// changes. The machine schedules it; the ring eases it.
  static const ringExit = Duration(milliseconds: 250);

  /// The success badge entrance.
  static const badgeIn = Duration(milliseconds: 600);

  /// Both sheets slide up over this, and the scrim fades over the same.
  static const sheet = Duration(milliseconds: 250);
}
