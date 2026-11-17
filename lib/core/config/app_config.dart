/// Runtime execution environment for OrderPulse.
enum AppEnvironment {
  demo,
  live;

  /// Parses an environment string from `--dart-define=APP_ENV`.
  static AppEnvironment fromString(String value) {
    return switch (value.trim().toLowerCase()) {
      'live' => AppEnvironment.live,
      _ => AppEnvironment.demo,
    };
  }
}

/// Immutable application configuration sourced from `--dart-define` or runtime settings.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
  });

  /// Default URLs target Android Emulator loopback (`10.0.2.2`).
  /// For iOS Simulator, Desktop, or Web, pass `http://localhost:8301`.
  factory AppConfig.fromEnvironment() {
    const rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'demo');
    const rawApiUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8301',
    );
    const rawWsUrl = String.fromEnvironment(
      'WS_BASE_URL',
      defaultValue: 'ws://10.0.2.2:8301/ws/orders',
    );

    return AppConfig(
      environment: AppEnvironment.fromString(rawEnv),
      apiBaseUrl: rawApiUrl,
      wsBaseUrl: rawWsUrl,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;
  final String wsBaseUrl;

  /// Returns an updated copy for runtime mode or endpoint overrides.
  AppConfig copyWith({
    AppEnvironment? environment,
    String? apiBaseUrl,
    String? wsBaseUrl,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      wsBaseUrl: wsBaseUrl ?? this.wsBaseUrl,
    );
  }
}
