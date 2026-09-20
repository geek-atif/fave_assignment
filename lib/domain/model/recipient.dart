/// One of the five seeded people. No search, no adding.
class Recipient {
  const Recipient({required this.id, required this.name, required this.handle});

  final String id;
  final String name;
  final String handle;

  @override
  bool operator ==(Object other) => other is Recipient && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Hardcoded, in the order the Recipient sheet lists them. The first is
/// selected by default; the fifth handle is 36 characters on purpose.
abstract final class SeededRecipients {
  static const kavya = Recipient(
    id: 'kavya',
    name: 'Kavya Sridharan Venkataraghavan',
    handle: 'kavya.sv@okaxis',
  );
  static const rohit = Recipient(
    id: 'rohit',
    name: 'Rohit Menon',
    handle: 'rohit.menon@ybl',
  );
  static const anaya = Recipient(
    id: 'anaya',
    name: 'Anaya Rao',
    handle: 'anaya@okhdfcbank',
  );
  static const sunita = Recipient(
    id: 'sunita',
    name: 'Sunita (maid)',
    handle: '9876501234@paytm',
  );
  static const bescom = Recipient(
    id: 'bescom',
    name: 'Bandra flat — electricity',
    handle: 'bescom.bandra.westblock.meter7@icici',
  );

  static const all = <Recipient>[kavya, rohit, anaya, sunita, bescom];

  /// Selected by default.
  static const first = kavya;

  static Recipient byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => first);
}
