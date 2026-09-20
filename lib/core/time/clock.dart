/// Time is a dependency. If a resume test has to actually wait, it is not one.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock a test drives by hand. Pair it with `fake_async` so the machine's
/// timers and its sense of wall-clock time advance together.
class TestClock implements Clock {
  TestClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  /// Jump forward without the machine's timers firing — a backgrounded app.
  void set(DateTime t) => _now = t;
}
