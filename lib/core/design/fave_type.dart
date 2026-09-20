import 'package:flutter/widgets.dart';

import 'fave_colors.dart';

/// Every type role in §06, written as size / line-height / tracking.
///
/// The brief gives line-height in pixels; Flutter wants a multiplier, so each
/// style is built through [_t], which does the division once.
abstract final class FaveType {
  static const family = 'Onest';

  static TextStyle _t(
    double size,
    double lineHeight, {
    double tracking = 0,
    FontWeight weight = FontWeight.w400,
    Color color = FaveColors.textPrimary,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    letterSpacing: tracking,
    fontWeight: weight,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // 17 / 22 / −0.2 Bold
  static final screenTitle = _t(
    17,
    22,
    tracking: -0.2,
    weight: FontWeight.w700,
  );

  // 22 / 26 Bold
  static final backChevron = _t(22, 26, weight: FontWeight.w700);

  // 11 / 14 / +1.2 SemiBold, uppercase
  static final sectionLabel = _t(
    11,
    14,
    tracking: 1.2,
    weight: FontWeight.w600,
    color: FaveColors.textSecondary,
  );

  // 40 / 46 / −0.8 ExtraBold
  static final amountField = _t(
    40,
    46,
    tracking: -0.8,
    weight: FontWeight.w800,
  );
  static final amountPlaceholder = amountField.copyWith(
    color: FaveColors.placeholder,
  );

  // 12.5 / 17 Medium #B8433C
  static final amountError = _t(
    12.5,
    17,
    weight: FontWeight.w500,
    color: FaveColors.failedMark,
  );

  // 15 / 20 / −0.1 SemiBold
  static final recipientName = _t(
    15,
    20,
    tracking: -0.1,
    weight: FontWeight.w600,
  );

  // 13 / 18 Medium
  static final noteField = _t(13, 18, weight: FontWeight.w500);
  static final notePlaceholder = noteField.copyWith(
    color: FaveColors.placeholder,
  );

  // 13 / 18 Regular #333333 — Success note line, in curly quotes
  static final successNote = _t(13, 18, color: FaveColors.successNote);

  // 14 / 18 / −0.1 SemiBold
  static final recentPayee = _t(
    14,
    18,
    tracking: -0.1,
    weight: FontWeight.w600,
  );

  // 12 / 16 Regular #7A7877
  static final recentStatus = _t(12, 16, color: FaveColors.textSecondary);

  // 15 / 20 / −0.1 Bold
  static final recentAmount = _t(
    15,
    20,
    tracking: -0.1,
    weight: FontWeight.w700,
  );

  // 9.5 / 12 / +0.6 Bold uppercase
  static final recentBadge = _t(
    9.5,
    12,
    tracking: 0.6,
    weight: FontWeight.w700,
  );

  // 13 / 18 Regular #7A7877
  static final recentEmpty = _t(13, 18, color: FaveColors.textSecondary);

  // Recipient sheet row: 14 / 18 Bold name · 12 / 16 Regular handle
  static final sheetRowName = _t(14, 18, weight: FontWeight.w700);
  static final sheetRowHandle = _t(12, 16, color: FaveColors.textSecondary);

  // 12.5 / 17 Regular — recipient handle, reference, reason, sheet subtitle
  static final caption = _t(12.5, 17, color: FaveColors.textSecondary);

  // 14 / 19 Medium — Confirming summary line
  static final summaryLine = _t(14, 19, weight: FontWeight.w500);

  // 12 / 16 Medium — chip label
  static final chipLabel = _t(12, 16, weight: FontWeight.w500);

  // 30 / 36 / −0.6 ExtraBold
  static final ringSeconds = _t(
    30,
    36,
    tracking: -0.6,
    weight: FontWeight.w800,
  );

  // 19 / 24 / −0.2 Bold
  static final confirmingHeading = _t(
    19,
    24,
    tracking: -0.2,
    weight: FontWeight.w700,
  );

  // 13 / 19 Regular, centred
  static final body = _t(13, 19);

  // 12 / 16 Regular — footnote, sheet mode description
  static final footnote = _t(12, 16, color: FaveColors.textSecondary);
  static final sheetModeDescription = _t(
    12,
    16,
    color: FaveColors.textSecondary,
  );

  // 28 / 34 / −0.5 ExtraBold
  static final successHeading = _t(
    28,
    34,
    tracking: -0.5,
    weight: FontWeight.w800,
  );

  // 24 / 30 / −0.4 ExtraBold — Failed · Still confirming
  static final terminalHeading = _t(
    24,
    30,
    tracking: -0.4,
    weight: FontWeight.w800,
  );

  // 14 / 19 Medium — Failed subline
  static final failedSubline = _t(14, 19, weight: FontWeight.w500);

  // 14 / 18 Bold — sheet mode name
  static final sheetModeName = _t(14, 18, weight: FontWeight.w700);

  // 12.5 / 17 Medium #232323
  static final noticeText = _t(12.5, 17, weight: FontWeight.w500);

  // 15 / 20 Bold #FFFFFF
  static final ctaLabel = _t(
    15,
    20,
    weight: FontWeight.w700,
    color: FaveColors.onTeal,
  );

  // 14 / 18 Medium, underlined
  static final link =
      _t(14, 18, weight: FontWeight.w500, color: FaveColors.link).copyWith(
        decoration: TextDecoration.underline,
        decorationColor: FaveColors.link,
      );

  // "Checking…": #7A7877, no underline
  static final linkChecking = _t(
    14,
    18,
    weight: FontWeight.w500,
    color: FaveColors.textSecondary,
  );
}
