/// Clock abstraction for deterministic timestamps across repositories, SLA timers, and tests.
abstract interface class AppClock {
  DateTime now();
}

/// System clock returning the current local/UTC timestamp.
class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Mutable fixed clock for deterministic unit and widget tests.
class FixedClock implements AppClock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}
