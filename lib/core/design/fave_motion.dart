import 'package:flutter/animation.dart';

import '../time/payment_timing.dart';

/// Exactly three things move in this flow: the ring, the badge, the sheets.
///
/// The durations are re-exported from [PaymentTiming] so there is still one
/// source of truth, while the state machine can depend on the timings without
/// importing Flutter for the curves.
abstract final class FaveMotion {
  /// The countdown itself. Wall-clock driven, sampled each frame.
  static const countdown = PaymentTiming.countdown;

  /// Poll cadence inside Confirming.
  static const pollInterval = PaymentTiming.pollInterval;

  /// The app's own timeout on `create`.
  static const createTimeout = PaymentTiming.createTimeout;

  /// Ring exit: sweep runs to zero over 250 ms, ease-out, then the screen
  /// changes.
  static const ringExit = PaymentTiming.ringExit;
  static const ringExitCurve = Curves.easeOut;

  /// Success badge entrance: scale 0.6 → 1.0, opacity 0 → 1, 600 ms, ease-out.
  static const badgeIn = PaymentTiming.badgeIn;
  static const badgeInCurve = Curves.easeOut;
  static const badgeFromScale = 0.6;

  /// Both sheets: slide up 250 ms ease-out, scrim fades 0 → 45% over the same.
  static const sheet = PaymentTiming.sheet;
  static const sheetCurve = Curves.easeOut;
}
