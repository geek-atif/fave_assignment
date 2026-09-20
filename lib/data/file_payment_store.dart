import 'dart:convert';
import 'dart:io';

import '../domain/model/payment_record.dart';
import '../domain/port/payment_store.dart';

/// Our records, in our own file. The backend's store is the backend's — the
/// only way to stage a record we hold for a key it has forgotten.
class FilePaymentStore implements PaymentStore {
  FilePaymentStore(this.path);

  final String path;

  List<PaymentRecord>? _cache;

  @override
  Future<List<PaymentRecord>> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return _cache = const [];
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as List<Object?>;
      final records =
          raw.cast<Map<String, Object?>>().map(PaymentRecord.fromJson).toList()
            ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return _cache = List.unmodifiable(records.take(PaymentStore.keptRecords));
    } on Object {
      // A store written by an older shape must not stop the app launching.
      return _cache = const [];
    }
  }

  /// Writes are serialised. The flow fires them without awaiting, and `save`
  /// is a read-modify-write: two overlapping calls would both read the same
  /// list and the later write would drop the earlier record.
  Future<void> _writing = Future<void>.value();

  @override
  Future<List<PaymentRecord>> save(PaymentRecord record) {
    final next = _writing.then((_) => _save(record));
    // Keep the chain alive even if one write fails.
    _writing = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<List<PaymentRecord>> _save(PaymentRecord record) async {
    final current = await load();
    final next = [record, ...current.where((r) => r.key != record.key)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final kept = List<PaymentRecord>.unmodifiable(
      next.take(PaymentStore.keptRecords),
    );
    _cache = kept;
    await File(
      path,
    ).writeAsString(jsonEncode(kept.map((r) => r.toJson()).toList()));
    return kept;
  }
}

/// For tests, and for the widget layer when nothing should touch disk.
class InMemoryPaymentStore implements PaymentStore {
  InMemoryPaymentStore([List<PaymentRecord> seed = const []])
    : _records = List.of(seed);

  List<PaymentRecord> _records;

  @override
  Future<List<PaymentRecord>> load() async =>
      List.unmodifiable(_records.take(PaymentStore.keptRecords));

  @override
  Future<List<PaymentRecord>> save(PaymentRecord record) async {
    _records = [record, ..._records.where((r) => r.key != record.key)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    _records = _records.take(PaymentStore.keptRecords).toList();
    return List.unmodifiable(_records);
  }
}
