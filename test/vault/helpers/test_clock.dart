// test/vault/helpers/test_clock.dart
// Owner: Developer 3 — D3.6 test utilities
//
// Injectable clock for deterministic date-based tests.
// Pass a fixed DateTime to avoid flaky tests that depend on DateTime.now().

/// A simple injectable clock abstraction.
/// Production code can use [SystemClock]; tests use [FixedClock].
abstract class Clock {
  const Clock();

  DateTime get now;

  /// Returns today's date (no time component) in local timezone.
  DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }
}

class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime get now => DateTime.now();
}

class FixedClock extends Clock {
  final DateTime _fixed;

  const FixedClock(this._fixed);

  /// Convenience: create from ISO date string e.g. '2026-10-24'.
  factory FixedClock.fromIso(String isoDate) =>
      FixedClock(DateTime.parse(isoDate));

  @override
  DateTime get now => _fixed;
}
