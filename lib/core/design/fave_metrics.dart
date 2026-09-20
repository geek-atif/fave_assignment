/// Every layout number in §06. The design is 393 px wide, so these map 1:1.
abstract final class FaveMetrics {
  static const designWidth = 393.0;

  // Screen padding: 56 top · 32 sides · 32 bottom, all states.
  static const screenTop = 56.0;
  static const screenSide = 32.0;
  static const screenBottom = 32.0;

  /// Pay: 24 between blocks (top bar → card → amount).
  static const payBlockGap = 24.0;

  // Top bar: 14 gap between chevron, title and the chip.
  static const topBarGap = 14.0;

  // Chip: 6 vertical · 12 / 10 horizontal · radius 100 · 6 between label and chevron.
  static const chipPadV = 6.0;
  static const chipPadLeft = 12.0;
  static const chipPadRight = 10.0;
  static const chipRadius = 100.0;
  static const chipLabelGap = 6.0;

  // Recipient card: 18 padding · 14 gap · avatar 44 · radius 20 · name → handle 3.
  static const cardPad = 18.0;
  static const cardGap = 14.0;
  static const cardAvatar = 44.0;
  static const cardRadius = 20.0;
  static const cardNameToHandle = 3.0;

  // Amount block: 6 between lines (label → field → underline → error → note).
  static const amountLineGap = 6.0;
  static const underlineThickness = 1.0;

  /// Recent: label, then 8 to the first row.
  static const recentLabelToFirstRow = 8.0;

  // Recent row: 13 top · 13 bottom · 12 gap.
  static const recentRowPadV = 13.0;
  static const recentRowGap = 12.0;
  static const dividerThickness = 1.0;

  // Unresolved badge: 3 vertical · 7 horizontal · radius 100 · 6 after the status line.
  static const badgePadV = 3.0;
  static const badgePadH = 7.0;
  static const badgeRadius = 100.0;
  static const badgeGap = 6.0;

  // Primary CTA: full width · 17 vertical padding · radius 100.
  static const ctaPadV = 17.0;
  static const ctaRadius = 100.0;

  /// CTA → link beneath: 18 (Failed, Still confirming).
  static const ctaToLink = 18.0;

  // Status block: centred · 22 gap (Confirming) · 20 gap (others).
  static const statusGapConfirming = 22.0;
  static const statusGapOther = 20.0;

  // Countdown ring: 120 × 120 · 8 thick.
  static const ringSize = 120.0;
  static const ringStroke = 8.0;

  // Badges: 88 × 88 · check / cross stroke 5 · waiting ring 8 thick, inside.
  static const badgeSize = 88.0;
  static const badgeMarkStroke = 5.0;
  static const waitingRingStroke = 8.0;

  /// Still confirming body copy width.
  static const bodyCopyWidth = 300.0;

  // Notice box: 14 vertical · 16 horizontal padding · radius 14 · full width.
  static const noticePadV = 14.0;
  static const noticePadH = 16.0;
  static const noticeRadius = 14.0;

  /// Confirming summary strip: 4 gap.
  static const summaryGap = 4.0;

  // Sheets: top radius 24 · 12 top / 24 sides / 32 bottom padding.
  static const sheetRadius = 24.0;
  static const sheetPadTop = 12.0;
  static const sheetPadSide = 24.0;
  static const sheetPadBottom = 32.0;

  // Grabber: 36 × 4, radius 2, centred, 10 beneath. 6 between blocks.
  static const grabberWidth = 36.0;
  static const grabberHeight = 4.0;
  static const grabberRadius = 2.0;
  static const grabberGap = 10.0;
  static const sheetBlockGap = 6.0;

  // Sheet mode row: 9 vertical padding · 14 gap · radio 20.
  static const sheetRowPadV = 9.0;
  static const sheetRowGap = 14.0;
  static const radioSize = 20.0;
  static const radioDot = 8.0;
  static const radioBorder = 2.0;

  /// Recipient sheet avatar.
  static const sheetAvatar = 36.0;
}
