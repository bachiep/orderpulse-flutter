import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/app.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';

void main() {
  testWidgets('App boots on LoginPage and AuthGuard redirects on demo login/logout', (
    tester,
  ) async {
    await configureDependencies(demoLatency: Duration.zero);
    addTearDown(() => sl.reset(dispose: true));

    await tester.pumpWidget(const OrderPulseApp());
    await tester.pumpAndSettle();

    expect(find.text('OrderPulse Merchant'), findsOneWidget);
    expect(find.text('Try Demo Merchant'), findsOneWidget);

    await tester.tap(find.text('Try Demo Merchant'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('OrderPulse Kitchen - Demo'), findsOneWidget);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('OrderPulse Merchant'), findsOneWidget);
  });

  testWidgets('Shared state views render Loading, Empty CTA, and Error Retry', (
    tester,
  ) async {
    var emptyRetried = false;
    var errorRetried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: LoadingStateView(message: 'Loading...')),
              Expanded(
                child: EmptyStateView(
                  title: 'No orders',
                  subtitle: 'Waiting for orders',
                  actionLabel: 'Reload',
                  onAction: () => emptyRetried = true,
                ),
              ),
              Expanded(
                child: ErrorStateView(
                  message: 'Network timeout',
                  onRetry: () => errorRetried = true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No orders'), findsOneWidget);
    expect(find.text('Network timeout'), findsOneWidget);

    await tester.tap(find.text('Reload'));
    await tester.tap(find.text('Retry'));
    expect(emptyRetried, isTrue);
    expect(errorRetried, isTrue);
  });
}
