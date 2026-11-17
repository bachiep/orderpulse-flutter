import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/widgets/connection_status_bar.dart';

void main() {
  group('ConnectionStatusBar', () {
    testWidgets('renders Live, Reconnecting, and Offline states cleanly on 320px width', (
      tester,
    ) async {
      var reconnectTapped = 0;

      Widget wrap(OrderStreamState state) {
        return MediaQuery(
          data: const MediaQueryData(size: Size(320, 640)),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ConnectionStatusBar(
                state: state,
                onReconnectTap: () => reconnectTapped += 1,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(wrap(const OrderStreamLive(receivedCount: 3)));
      expect(find.text('Live • 3 stream event(s)'), findsOneWidget);
      expect(find.text('Reconnect'), findsNothing);

      await tester.pumpWidget(
        wrap(
          const OrderStreamReconnecting(
            attempt: 2,
            nextRetryDelay: Duration(seconds: 2),
          ),
        ),
      );
      expect(
        find.text('Reconnecting (attempt 2, retry in 2s)...'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reconnect'));
      expect(reconnectTapped, 1);

      await tester.pumpWidget(wrap(const OrderStreamOffline()));
      expect(find.text('Offline • Stream disconnected'), findsOneWidget);
      await tester.tap(find.text('Reconnect'));
      expect(reconnectTapped, 2);
      expect(tester.takeException(), isNull);
    });
  });
}
