import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';

void main() {
  group('AppConfig & AppClock', () {
    test('AppConfig defaults to demo and 10.0.2.2 endpoints', () {
      final config = AppConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.demo);
      expect(config.apiBaseUrl, 'http://10.0.2.2:8301');
      expect(config.wsBaseUrl, 'ws://10.0.2.2:8301/ws/orders');

      final updated = config.copyWith(
        environment: AppEnvironment.live,
        apiBaseUrl: 'https://api.orderpulse.example',
      );
      expect(updated.environment, AppEnvironment.live);
      expect(updated.apiBaseUrl, 'https://api.orderpulse.example');
      expect(updated.wsBaseUrl, 'ws://10.0.2.2:8301/ws/orders');
    });

    test('FixedClock advances deterministically', () {
      final clock = FixedClock(DateTime.utc(2026, 11, 18, 10, 0, 0));
      expect(clock.now(), DateTime.utc(2026, 11, 18, 10, 0, 0));

      clock.advance(const Duration(seconds: 15));
      expect(clock.now(), DateTime.utc(2026, 11, 18, 10, 0, 15));
    });
  });

  group('ThemeCubit & AppTheme KDS tokens', () {
    test('defaults to KDS dark mode and exposes high-contrast tokens', () {
      final cubit = ThemeCubit();
      expect(cubit.state, ThemeMode.dark);
      expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0C0F17));
      expect(KdsColors.dark.card, const Color(0xFF151B28));
      expect(KdsColors.dark.statusNew, const Color(0xFFF59E0B));
      expect(KdsColors.dark.statusPreparing, const Color(0xFF0284C7));
      expect(KdsColors.dark.statusReady, const Color(0xFF16A34A));
      expect(KdsColors.dark.statusCompleted, const Color(0xFF64748B));
      expect(KdsColors.dark.statusRejected, const Color(0xFFDC2626));
      cubit.close();
    });

    blocTest<ThemeCubit, ThemeMode>(
      'toggles between light and dark modes',
      build: () => ThemeCubit(initialMode: ThemeMode.light),
      act: (cubit) {
        cubit.toggle();
        cubit.toggle();
        cubit.setThemeMode(ThemeMode.dark);
      },
      expect: () => const [ThemeMode.dark, ThemeMode.light, ThemeMode.dark],
    );
  });
}
