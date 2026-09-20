import '../model/payment_record.dart';

/// The flow talks to this, never to a plugin. Whatever is behind it, an
/// amount is still an integer of rupees after a write and a read.
abstract interface class PaymentStore {
  /// Newest first, at most [keptRecords].
  Future<List<PaymentRecord>> load();

  /// Insert or replace by key, keeping only the two most recent.
  Future<List<PaymentRecord>> save(PaymentRecord record);

  static const keptRecords = 2;
}
