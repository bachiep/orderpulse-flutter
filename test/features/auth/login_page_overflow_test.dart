import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/app.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';

void main() {
  testWidgets(
    'LoginPage expands Server Endpoint Settings cleanly on 320px screen with open keyboard insets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await configureDependencies(demoLatency: Duration.zero);
      addTearDown(() => sl.reset(dispose: true));

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            viewInsets: EdgeInsets.only(bottom: 240),
          ),
          child: OrderPulseApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Server Endpoint Settings'));
      await tester.tap(find.text('Server Endpoint Settings'));
      await tester.pumpAndSettle();

      expect(find.text('API Base URL'), findsOneWidget);
      expect(find.text('WebSocket URL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
