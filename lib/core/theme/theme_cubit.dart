import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the active Material 3 light/dark theme mode.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({ThemeMode initialMode = ThemeMode.light}) : super(initialMode);

  void toggle() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setThemeMode(ThemeMode mode) {
    emit(mode);
  }
}
