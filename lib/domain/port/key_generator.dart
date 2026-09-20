import 'dart:math';

/// The idempotency key is generated in the app, before create. A Try again
/// after a terminal failure asks for a new one.
abstract interface class KeyGenerator {
  String next();
}

class RandomKeyGenerator implements KeyGenerator {
  RandomKeyGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pay_$hex';
  }
}

/// Deterministic keys, so a test can assert on them.
class SequentialKeyGenerator implements KeyGenerator {
  SequentialKeyGenerator([this._n = 0]);

  int _n;

  @override
  String next() => 'key_${++_n}';
}
