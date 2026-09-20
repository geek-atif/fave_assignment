import 'dart:ui' show Color;

/// Every colour in the design, once. A colour typed twice is a colour that
/// will drift — §06 of the brief is the only source.
abstract final class FaveColors {
  static const screen = Color(0xFFFFFBF6);

  static const textPrimary = Color(0xFF232323);
  static const textSecondary = Color(0xFF7A7877);

  /// Success note line is #333333, not the primary #232323 — §06 says so.
  static const successNote = Color(0xFF333333);

  static const recipientCard = Color(0xFFFFEDD9);
  static const avatarAndWaitingRing = Color(0xFFFFD9C2);
  static const ringTrack = Color(0xFFFFEADF);

  /// Primary CTA · ring progress · success badge.
  static const teal = Color(0xFF0FBAB0);
  static const onTeal = Color(0xFFFFFFFF);

  static const failedBadge = Color(0xFFFBEAE8);
  static const failedMark = Color(0xFFB8433C);

  static const notice = Color(0xFFFFF3EE);

  /// Links · selected radio.
  static const link = Color(0xFF5E6DFF);

  /// Chip fill · unselected radio · grabber.
  static const chipFill = Color(0xFFF5EFE6);
  static const chipBorder = Color(0xFFD3C8B8);

  /// Placeholder text uses the same warm grey as the chip border.
  static const placeholder = chipBorder;

  static const fieldUnderline = Color(0xFFE7DFD4);
  static const divider = Color(0xFFE7DFD4);

  static const scrim = Color(0x73231F30); // #231F30 at 45%
}
