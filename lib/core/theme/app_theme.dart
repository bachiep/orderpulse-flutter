import 'package:flutter/material.dart';

/// Semantic high-contrast Kitchen Display System (KDS) color tokens.
@immutable
class KdsColors extends ThemeExtension<KdsColors> {
  const KdsColors({
    required this.canvas,
    required this.card,
    required this.cardElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brandAccent,
    required this.onBrandAccent,
    required this.statusNew,
    required this.statusNewContainer,
    required this.onStatusNewContainer,
    required this.statusPreparing,
    required this.statusPreparingContainer,
    required this.onStatusPreparingContainer,
    required this.statusReady,
    required this.statusReadyContainer,
    required this.onStatusReadyContainer,
    required this.statusCompleted,
    required this.statusCompletedContainer,
    required this.onStatusCompletedContainer,
    required this.statusRejected,
    required this.statusRejectedContainer,
    required this.onStatusRejectedContainer,
  });

  final Color canvas;
  final Color card;
  final Color cardElevated;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color brandAccent;
  final Color onBrandAccent;

  final Color statusNew;
  final Color statusNewContainer;
  final Color onStatusNewContainer;

  final Color statusPreparing;
  final Color statusPreparingContainer;
  final Color onStatusPreparingContainer;

  final Color statusReady;
  final Color statusReadyContainer;
  final Color onStatusReadyContainer;

  final Color statusCompleted;
  final Color statusCompletedContainer;
  final Color onStatusCompletedContainer;

  final Color statusRejected;
  final Color statusRejectedContainer;
  final Color onStatusRejectedContainer;

  static const KdsColors dark = KdsColors(
    canvas: Color(0xFF0C0F17),
    card: Color(0xFF151B28),
    cardElevated: Color(0xFF1C2436),
    border: Color(0xFF263248),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    brandAccent: Color(0xFF14B8A6),
    onBrandAccent: Color(0xFF042F2E),
    statusNew: Color(0xFFF59E0B),
    statusNewContainer: Color(0xFF2E2108),
    onStatusNewContainer: Color(0xFFFCD34D),
    statusPreparing: Color(0xFF0284C7),
    statusPreparingContainer: Color(0xFF0B273F),
    onStatusPreparingContainer: Color(0xFF38BDF8),
    statusReady: Color(0xFF16A34A),
    statusReadyContainer: Color(0xFF0D2B1B),
    onStatusReadyContainer: Color(0xFF4ADE80),
    statusCompleted: Color(0xFF64748B),
    statusCompletedContainer: Color(0xFF1E293B),
    onStatusCompletedContainer: Color(0xFFCBD5E1),
    statusRejected: Color(0xFFDC2626),
    statusRejectedContainer: Color(0xFF351319),
    onStatusRejectedContainer: Color(0xFFFCA5A5),
  );

  static const KdsColors light = KdsColors(
    canvas: Color(0xFFF8FAFC),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    brandAccent: Color(0xFF0F766E),
    onBrandAccent: Color(0xFFFFFFFF),
    statusNew: Color(0xFFF59E0B),
    statusNewContainer: Color(0xFFFEF3C7),
    onStatusNewContainer: Color(0xFF92400E),
    statusPreparing: Color(0xFF0284C7),
    statusPreparingContainer: Color(0xFFE0F2FE),
    onStatusPreparingContainer: Color(0xFF0369A1),
    statusReady: Color(0xFF16A34A),
    statusReadyContainer: Color(0xFFDCFCE7),
    onStatusReadyContainer: Color(0xFF15803D),
    statusCompleted: Color(0xFF64748B),
    statusCompletedContainer: Color(0xFFF1F5F9),
    onStatusCompletedContainer: Color(0xFF334155),
    statusRejected: Color(0xFFDC2626),
    statusRejectedContainer: Color(0xFFFEE2E2),
    onStatusRejectedContainer: Color(0xFFB91C1C),
  );

  static KdsColors of(BuildContext context) {
    final ext = Theme.of(context).extension<KdsColors>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  KdsColors copyWith({
    Color? canvas,
    Color? card,
    Color? cardElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? brandAccent,
    Color? onBrandAccent,
    Color? statusNew,
    Color? statusNewContainer,
    Color? onStatusNewContainer,
    Color? statusPreparing,
    Color? statusPreparingContainer,
    Color? onStatusPreparingContainer,
    Color? statusReady,
    Color? statusReadyContainer,
    Color? onStatusReadyContainer,
    Color? statusCompleted,
    Color? statusCompletedContainer,
    Color? onStatusCompletedContainer,
    Color? statusRejected,
    Color? statusRejectedContainer,
    Color? onStatusRejectedContainer,
  }) {
    return KdsColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brandAccent: brandAccent ?? this.brandAccent,
      onBrandAccent: onBrandAccent ?? this.onBrandAccent,
      statusNew: statusNew ?? this.statusNew,
      statusNewContainer: statusNewContainer ?? this.statusNewContainer,
      onStatusNewContainer: onStatusNewContainer ?? this.onStatusNewContainer,
      statusPreparing: statusPreparing ?? this.statusPreparing,
      statusPreparingContainer:
          statusPreparingContainer ?? this.statusPreparingContainer,
      onStatusPreparingContainer:
          onStatusPreparingContainer ?? this.onStatusPreparingContainer,
      statusReady: statusReady ?? this.statusReady,
      statusReadyContainer: statusReadyContainer ?? this.statusReadyContainer,
      onStatusReadyContainer:
          onStatusReadyContainer ?? this.onStatusReadyContainer,
      statusCompleted: statusCompleted ?? this.statusCompleted,
      statusCompletedContainer:
          statusCompletedContainer ?? this.statusCompletedContainer,
      onStatusCompletedContainer:
          onStatusCompletedContainer ?? this.onStatusCompletedContainer,
      statusRejected: statusRejected ?? this.statusRejected,
      statusRejectedContainer:
          statusRejectedContainer ?? this.statusRejectedContainer,
      onStatusRejectedContainer:
          onStatusRejectedContainer ?? this.onStatusRejectedContainer,
    );
  }

  @override
  KdsColors lerp(ThemeExtension<KdsColors>? other, double t) {
    if (other is! KdsColors) return this;
    return KdsColors(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      card: Color.lerp(card, other.card, t) ?? card,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t) ?? cardElevated,
      border: Color.lerp(border, other.border, t) ?? border,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t) ?? brandAccent,
      onBrandAccent:
          Color.lerp(onBrandAccent, other.onBrandAccent, t) ?? onBrandAccent,
      statusNew: Color.lerp(statusNew, other.statusNew, t) ?? statusNew,
      statusNewContainer:
          Color.lerp(statusNewContainer, other.statusNewContainer, t) ??
              statusNewContainer,
      onStatusNewContainer:
          Color.lerp(onStatusNewContainer, other.onStatusNewContainer, t) ??
              onStatusNewContainer,
      statusPreparing: Color.lerp(statusPreparing, other.statusPreparing, t) ??
          statusPreparing,
      statusPreparingContainer: Color.lerp(
            statusPreparingContainer,
            other.statusPreparingContainer,
            t,
          ) ??
          statusPreparingContainer,
      onStatusPreparingContainer: Color.lerp(
            onStatusPreparingContainer,
            other.onStatusPreparingContainer,
            t,
          ) ??
          onStatusPreparingContainer,
      statusReady: Color.lerp(statusReady, other.statusReady, t) ?? statusReady,
      statusReadyContainer:
          Color.lerp(statusReadyContainer, other.statusReadyContainer, t) ??
              statusReadyContainer,
      onStatusReadyContainer:
          Color.lerp(onStatusReadyContainer, other.onStatusReadyContainer, t) ??
              onStatusReadyContainer,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t) ??
          statusCompleted,
      statusCompletedContainer: Color.lerp(
            statusCompletedContainer,
            other.statusCompletedContainer,
            t,
          ) ??
          statusCompletedContainer,
      onStatusCompletedContainer: Color.lerp(
            onStatusCompletedContainer,
            other.onStatusCompletedContainer,
            t,
          ) ??
          onStatusCompletedContainer,
      statusRejected:
          Color.lerp(statusRejected, other.statusRejected, t) ?? statusRejected,
      statusRejectedContainer: Color.lerp(
            statusRejectedContainer,
            other.statusRejectedContainer,
            t,
          ) ??
          statusRejectedContainer,
      onStatusRejectedContainer: Color.lerp(
            onStatusRejectedContainer,
            other.onStatusRejectedContainer,
            t,
          ) ??
          onStatusRejectedContainer,
    );
  }
}

/// Applies tabular figures for aligned numerical metrics, prices, and SLA countdowns.
TextStyle? tabularStyle(TextStyle? base) {
  return base?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// Material 3 theme definitions tuned for high-contrast Kitchen Display System (KDS) boards.
class AppTheme {
  static ThemeData light() {
    const kds = KdsColors.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kds.brandAccent,
      secondary: kds.statusNew,
      error: kds.statusRejected,
      brightness: Brightness.light,
    ).copyWith(
      primary: kds.brandAccent,
      onPrimary: kds.onBrandAccent,
      surface: kds.card,
      onSurface: kds.textPrimary,
      onSurfaceVariant: kds.textSecondary,
      surfaceContainerLowest: kds.card,
      surfaceContainerLow: kds.card,
      surfaceContainer: kds.cardElevated,
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: kds.border,
      outlineVariant: kds.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: kds.canvas,
      extensions: const [kds],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: kds.card,
        foregroundColor: kds.textPrimary,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: kds.border)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: kds.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kds.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: kds.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kds.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.brandAccent, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kds.card,
        selectedColor: kds.brandAccent.withValues(alpha: 0.14),
        side: BorderSide(color: kds.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kds.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: kds.brandAccent.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? kds.brandAccent : kds.textSecondary,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? kds.brandAccent : kds.textSecondary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kds.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const kds = KdsColors.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kds.brandAccent,
      secondary: kds.statusNew,
      error: kds.statusRejected,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kds.brandAccent,
      onPrimary: kds.onBrandAccent,
      primaryContainer: const Color(0xFF0F3534),
      onPrimaryContainer: const Color(0xFF5EEAD4),
      secondaryContainer: const Color(0xFF1E2B3D),
      onSecondaryContainer: const Color(0xFFE2E8F0),
      errorContainer: kds.statusRejectedContainer,
      onErrorContainer: kds.onStatusRejectedContainer,
      surface: kds.card,
      onSurface: kds.textPrimary,
      onSurfaceVariant: kds.textSecondary,
      surfaceContainerLowest: kds.canvas,
      surfaceContainerLow: kds.card,
      surfaceContainer: kds.cardElevated,
      surfaceContainerHighest: const Color(0xFF243047),
      outline: kds.border,
      outlineVariant: kds.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: kds.canvas,
      extensions: const [kds],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: kds.card,
        foregroundColor: kds.textPrimary,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: kds.border)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: kds.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kds.border, width: 1),
        ),
      ),
      dividerTheme: DividerThemeData(color: kds.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kds.cardElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kds.brandAccent, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kds.card,
        selectedColor: kds.brandAccent.withValues(alpha: 0.2),
        side: BorderSide(color: kds.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kds.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: kds.brandAccent.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? kds.brandAccent : kds.textSecondary,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? kds.brandAccent : kds.textSecondary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kds.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: kds.border),
        ),
      ),
    );
  }
}
