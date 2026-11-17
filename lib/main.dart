import 'package:flutter/material.dart';
import 'package:orderpulse_flutter/app.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const OrderPulseApp());
}
