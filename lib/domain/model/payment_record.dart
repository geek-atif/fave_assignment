/// What a settled — or unsettled — attempt looks like on disk and in the
/// Recent list. One source of truth: the live flow and the history rows read
/// the same records.
enum RecordOutcome {
  /// Started, no terminal answer yet. Shows the CHECKING badge.
  inFlight,
  success,
  failed,

  /// The backend no longer knows the key: the store was cleared or lost.
  /// Never success, never failure.
  unresolved,
}

class PaymentRecord {
  const PaymentRecord({
    required this.key,
    required this.recipientId,
    required this.recipientName,
    required this.recipientHandle,
    required this.amountRupees,
    required this.note,
    required this.startedAt,
    required this.outcome,
    this.settledAt,
    this.reference,
  });

  /// Our idempotency key. Generated in the app, before create.
  final String key;

  final String recipientId;
  final String recipientName;
  final String recipientHandle;

  /// Whole rupees. An int after a write and a read — not a double, and not
  /// the formatted string, which loses the value.
  final int amountRupees;

  final String? note;
  final DateTime startedAt;
  final RecordOutcome outcome;
  final DateTime? settledAt;

  /// The id `create` returned. Null in B1, where it never did.
  final String? reference;

  bool get isTerminal =>
      outcome == RecordOutcome.success || outcome == RecordOutcome.failed;

  PaymentRecord copyWith({
    RecordOutcome? outcome,
    DateTime? settledAt,
    String? reference,
  }) => PaymentRecord(
    key: key,
    recipientId: recipientId,
    recipientName: recipientName,
    recipientHandle: recipientHandle,
    amountRupees: amountRupees,
    note: note,
    startedAt: startedAt,
    outcome: outcome ?? this.outcome,
    settledAt: settledAt ?? this.settledAt,
    reference: reference ?? this.reference,
  );

  /// A value object: two records with the same fields are the same record.
  /// The machine leans on this to avoid repainting a screen that did not
  /// change when the store echoes a write back.
  @override
  bool operator ==(Object other) =>
      other is PaymentRecord &&
      other.key == key &&
      other.recipientId == recipientId &&
      other.amountRupees == amountRupees &&
      other.note == note &&
      other.startedAt == startedAt &&
      other.outcome == outcome &&
      other.settledAt == settledAt &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(
    key,
    recipientId,
    amountRupees,
    note,
    startedAt,
    outcome,
    settledAt,
    reference,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'recipientId': recipientId,
    'recipientName': recipientName,
    'recipientHandle': recipientHandle,
    // int in, int out.
    'amountRupees': amountRupees,
    'note': note,
    'startedAt': startedAt.toIso8601String(),
    'outcome': outcome.name,
    'settledAt': settledAt?.toIso8601String(),
    'reference': reference,
  };

  static PaymentRecord fromJson(Map<String, Object?> json) => PaymentRecord(
    key: json['key']! as String,
    recipientId: json['recipientId']! as String,
    recipientName: json['recipientName']! as String,
    recipientHandle: json['recipientHandle']! as String,
    amountRupees: json['amountRupees']! as int,
    note: json['note'] as String?,
    startedAt: DateTime.parse(json['startedAt']! as String),
    outcome: RecordOutcome.values.firstWhere(
      (o) => o.name == json['outcome'],
      orElse: () => RecordOutcome.inFlight,
    ),
    settledAt: switch (json['settledAt']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    reference: json['reference'] as String?,
  );
}
