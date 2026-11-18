import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/app.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/pages/order_detail_page.dart';
import 'package:orderpulse_flutter/features/insights/presentation/widgets/shift_insights_view.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/widgets/simulator_sheet.dart';

const bool _writeScreenshots = bool.fromEnvironment(
  'WRITE_SCREENSHOTS',
  defaultValue: false,
);

Future<bool> _loadLocalMaterialFontsIfPresent() async {
  final candidateDirs = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final flutterRoot?)
      '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}artifacts${Platform.pathSeparator}material_fonts',
    r'C:\src\flutter\bin\cache\artifacts\material_fonts',
  ];

  String? resolvedDir;
  for (final dir in candidateDirs) {
    if (Directory(dir).existsSync()) {
      resolvedDir = dir;
      break;
    }
  }
  if (resolvedDir == null) return false;

  final sep = Platform.pathSeparator;
  final iconsFile = File('$resolvedDir${sep}materialicons-regular.otf');
  if (iconsFile.existsSync()) {
    final bytes = iconsFile.readAsBytesSync();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  const robotoFiles = [
    'roboto-light.ttf',
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-italic.ttf',
  ];
  final loadedBytes = <Uint8List>[];
  for (final name in robotoFiles) {
    final file = File('$resolvedDir$sep$name');
    if (file.existsSync()) {
      loadedBytes.add(file.readAsBytesSync());
    }
  }
  if (loadedBytes.isEmpty) return false;

  for (final family in const ['Roboto', 'Segoe UI']) {
    final loader = FontLoader(family);
    for (final bytes in loadedBytes) {
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  final monoLoader = FontLoader('monospace');
  var loadedSystemMono = false;
  for (final monoPath in const [
    r'C:\Windows\Fonts\consola.ttf',
    r'C:\Windows\Fonts\consolab.ttf',
  ]) {
    final monoFile = File(monoPath);
    if (monoFile.existsSync()) {
      final bytes = monoFile.readAsBytesSync();
      monoLoader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      loadedSystemMono = true;
    }
  }
  if (!loadedSystemMono) {
    for (final bytes in loadedBytes) {
      monoLoader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
  }
  await monoLoader.load();
  return true;
}

Future<void> _capturePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String relativePath,
) async {
  if (!_writeScreenshots) return;
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode PNG for $relativePath');
    }
    final outFile = File(relativePath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsBytesSync(byteData.buffer.asUint8List());
  });
}

void main() {
  testWidgets(
    'Renders v2.1 393x852 @2x screens and verifies zero layout regressions',
    (tester) async {
      final boundaryKey = GlobalKey();
      final fixedClock = FixedClock(DateTime.utc(2026, 11, 18, 12, 20));

      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.physicalSize = const Size(393 * 2.0, 852 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        final fontsLoaded = await _loadLocalMaterialFontsIfPresent();
        await configureDependencies(
          clock: fixedClock,
          demoLatency: Duration.zero,
        );
        addTearDown(() => sl.reset(dispose: true));

        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: const OrderPulseApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Login & Demo Entry
        expect(find.text('OrderPulse Merchant'), findsOneWidget);
        expect(find.text('Try Demo Merchant'), findsOneWidget);
        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/01-login-demo-entry.png',
        );

        // 2. Live Order Board (Tab 1: Live Queue with SLA Urgency First active)
        await tester.tap(find.text('Try Demo Merchant'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('OrderPulse'), findsOneWidget);
        expect(find.text('District 1 • Demo Kitchen'), findsOneWidget);
        expect(find.text('ORD-1028'), findsOneWidget);
        expect(find.widgetWithText(FilterChip, 'Urgent SLA'), findsOneWidget);
        expect(
          find.widgetWithText(FilterChip, 'SLA Urgency First'),
          findsOneWidget,
        );

        // Verify AppBar reserves generous space and does not truncate with Roboto loaded.
        final subtitleFinder = find.text('District 1 • Demo Kitchen');
        final subtitleWidget = tester.widget<Text>(subtitleFinder);
        final subtitleBox = tester.renderObject<RenderBox>(subtitleFinder);
        expect(subtitleBox.size.width, greaterThanOrEqualTo(120));
        if (fontsLoaded) {
          final subtitlePainter = TextPainter(
            text: TextSpan(
              text: subtitleWidget.data,
              style: subtitleWidget.style,
            ),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: subtitleBox.size.width + 0.5);
          expect(subtitlePainter.didExceedMaxLines, isFalse);
        }

        // Activate SLA Urgency First so overdue tickets (+4m OVERDUE) rise to the top.
        await tester.tap(find.widgetWithText(FilterChip, 'SLA Urgency First'));
        await tester.pumpAndSettle();
        expect(find.text('ORD-1025'), findsOneWidget);
        expect(find.text('+4m OVERDUE'), findsOneWidget);

        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/02-order-board-live.png',
        );

        // 3. Order Detail Workspace (ORD-1025 shows SLA overdue, Kitchen Slip, stepper, checklist, rider)
        await tester.tap(find.text('Vo Tuan Kiet'));
        await tester.pump();
        await tester.pumpAndSettle();

        final detailScrollable = find
            .descendant(
              of: find.byType(OrderDetailPage),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(find.text('Order Lifecycle'), findsOneWidget);
        expect(find.text('Kitchen Slip'), findsOneWidget);
        if (find.text('Kitchen Prep Checklist').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text('Kitchen Prep Checklist'),
            160,
            scrollable: detailScrollable,
          );
        }
        expect(find.text('Kitchen Prep Checklist'), findsOneWidget);
        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/03-order-detail-dispatch.png',
        );
        if (find.text('Courier & Delivery Dispatch').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text('Courier & Delivery Dispatch'),
            160,
            scrollable: detailScrollable,
          );
        }
        expect(find.text('Courier & Delivery Dispatch'), findsOneWidget);

        // Open 80mm Thermal Kitchen Slip modal preview and capture screenshot
        await tester.scrollUntilVisible(
          find.text('Kitchen Slip'),
          -200,
          scrollable: detailScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kitchen Slip'));
        await tester.pumpAndSettle();
        expect(find.text('80mm Thermal Kitchen Slip'), findsOneWidget);
        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/06-kitchen-slip-preview.png',
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Navigate back to Order Board
        await tester.pageBack();
        await tester.pumpAndSettle();

        // 4. Shift Insights Tab (Tab 2: KPIs, CustomPainter Charts, Top 5 Dishes)
        await tester.tap(find.text('Shift Insights'));
        await tester.pump();
        await tester.pumpAndSettle();

        final insightsScrollable = find
            .descendant(
              of: find.byType(ShiftInsightsView),
              matching: find.byType(Scrollable),
            )
            .first;
        expect(find.text('Completed Orders'), findsOneWidget);
        expect(find.text('Hourly Order Volume'), findsOneWidget);
        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/04-shift-insights-analytics.png',
        );
        if (find.text('Status Distribution').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text('Status Distribution'),
            160,
            scrollable: insightsScrollable,
          );
        }
        expect(find.text('Status Distribution'), findsOneWidget);
        if (find.text('Top 5 Dishes').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text('Top 5 Dishes'),
            160,
            scrollable: insightsScrollable,
          );
        }
        expect(find.text('Top 5 Dishes'), findsOneWidget);

        // Switch back to Live Queue & open Simulator Sheet with live 401 test
        await tester.tap(find.text('Live Queue'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open Simulator'));
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Expire Token & Fire 3 Parallel Requests'),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        if (find.text('Last 401 Queue Verification').evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text('Last 401 Queue Verification'),
            160,
            scrollable: find
                .descendant(
                  of: find.byType(SimulatorSheet),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        expect(find.text('Last 401 Queue Verification'), findsOneWidget);
        await _capturePng(
          tester,
          boundaryKey,
          'docs/screenshots/05-simulator-sheet.png',
        );

        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );
}
