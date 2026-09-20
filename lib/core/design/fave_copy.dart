/// Every user-facing string, verbatim from the Figma frames on page ② Screens.
/// Copy is data, not layout — it lives here so a wording change is one edit.
abstract final class FaveCopy {
  // ---- Pay ----
  static const payTitle = 'Pay';
  static const amountLabel = 'AMOUNT';
  static const amountPlaceholder = '₹0';
  static const notePlaceholder = 'Add a note (optional)';
  static const recentLabel = 'RECENT';
  static const recentEmpty = 'No payments yet';
  static const ctaPay = 'Pay';
  static const ctaPaySending = 'Paying…';
  static const chipPrefix = 'Backend · ';
  static const chipChevron = '▾';

  // Amount validation, exact copy.
  static const errorBelowMinimum = 'Enter at least ₹1';
  static const errorOverLimit =
      'UPI payments are capped at ₹1,00,000 per transaction';

  // ---- Confirming ----
  static const payingLabel = 'PAYING';
  static const confirmingHeading = 'Checking with your bank';
  static const confirmingBody =
      'This usually takes a few seconds.\nDon’t close the app.';
  static const confirmingFootnote =
      'Don’t pay again — we’ll confirm one way or the other.';

  // ---- Success ----
  static const successCta = 'Done';
  static String amountSent(String amount) => '$amount sent';
  static String successPayee(String name, String handle) =>
      'to $name · $handle';
  static String successNote(String note) => '“$note”';
  static String reference(String when, String ref) => '$when · UPI ref $ref';

  // ---- Failed ----
  static const failedHeading = 'Payment didn’t go through';
  static const failedSubline = 'Your money hasn’t left your account.';
  static const failedReasonDeclined = 'Your bank declined the request.';
  static const ctaTryAgain = 'Try again';
  static const linkGoBack = 'Go back';

  // ---- Still confirming ----
  static const stillConfirmingHeading = 'Still confirming';
  static const stillConfirmingBody =
      'Your bank hasn’t confirmed yet. We’ll keep checking and tell you the '
      'moment it does.';
  static const stillConfirmingNotice =
      'Don’t pay again. If money has left your account, this will either '
      'complete or be refunded — never both.';
  static const ctaGoToHome = 'Go to home';
  static const linkCheckStatus = 'Check status again';
  static const linkChecking = 'Checking…';

  // ---- Recent row badges ----
  static const badgeChecking = 'CHECKING';
  static const badgeUnresolved = 'UNRESOLVED';
  static const recentSentPrefix = 'Sent';
  static const recentFailedPrefix = 'Failed';

  // ---- Backend behaviour sheet ----
  static const backendSheetTitle = 'Backend behaviour';
  static const backendSheetSubtitle =
      'Pick before you tap Pay. Applies to the next attempt only. To produce '
      'B5, background the app during Confirming in any mode.';

  // ---- Recipient sheet ----
  static const recipientSheetTitle = 'Who are you paying?';
  static const recipientSheetSubtitle =
      'Five people are seeded. No search, no adding — pick one.';
}
