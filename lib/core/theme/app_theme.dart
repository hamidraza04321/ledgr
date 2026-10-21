import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const brand = Color(0xFF5B4CF0);
  static const brandBright = Color(0xFF8B7CFF);
  static const brandDeep = Color(0xFF4335D6);

  static const income = Color(0xFF15A35A);
  static const incomeDark = Color(0xFF3DD68C);
  static const expense = Color(0xFFE5484D);
  static const expenseDark = Color(0xFFFF6B70);
  static const transfer = Color(0xFF3B82F6);
  static const transferDark = Color(0xFF60A5FA);
  static const warning = Color(0xFFF59E0B);
}

/// App-specific colors that are not part of [ColorScheme].
@immutable
class LedgrPalette extends ThemeExtension<LedgrPalette> {
  const LedgrPalette({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.warning,
    required this.card,
    required this.muted,
    required this.chatBackground,
    required this.bubbleOut,
    required this.bubbleIn,
    required this.heroGradient,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;
  final Color card;
  final Color muted;
  final Color chatBackground;
  final Color bubbleOut;
  final Color bubbleIn;
  final List<Color> heroGradient;

  static const light = LedgrPalette(
    income: AppColors.income,
    expense: AppColors.expense,
    transfer: AppColors.transfer,
    warning: AppColors.warning,
    card: Colors.white,
    muted: Color(0xFF6B7080),
    chatBackground: Color(0xFFEFEDF7),
    bubbleOut: AppColors.brand,
    bubbleIn: Colors.white,
    heroGradient: [Color(0xFF5B4CF0), Color(0xFF7B5CF5), Color(0xFF9B6BF2)],
  );

  static const dark = LedgrPalette(
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    transfer: AppColors.transferDark,
    warning: AppColors.warning,
    card: Color(0xFF181B22),
    muted: Color(0xFF9096A6),
    chatBackground: Color(0xFF0D0F14),
    bubbleOut: Color(0xFF5446E0),
    bubbleIn: Color(0xFF1D2029),
    heroGradient: [Color(0xFF3F33C9), Color(0xFF5B45D8), Color(0xFF7552D9)],
  );

  @override
  LedgrPalette copyWith({Color? income, Color? expense}) => LedgrPalette(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        transfer: transfer,
        warning: warning,
        card: card,
        muted: muted,
        chatBackground: chatBackground,
        bubbleOut: bubbleOut,
        bubbleIn: bubbleIn,
        heroGradient: heroGradient,
      );

  @override
  LedgrPalette lerp(LedgrPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LedgrPalette(
      income: l(income, other.income),
      expense: l(expense, other.expense),
      transfer: l(transfer, other.transfer),
      warning: l(warning, other.warning),
      card: l(card, other.card),
      muted: l(muted, other.muted),
      chatBackground: l(chatBackground, other.chatBackground),
      bubbleOut: l(bubbleOut, other.bubbleOut),
      bubbleIn: l(bubbleIn, other.bubbleIn),
      heroGradient: [
        for (var i = 0; i < heroGradient.length; i++)
          l(heroGradient[i], other.heroGradient[i]),
      ],
    );
  }
}

extension LedgrThemeX on BuildContext {
  LedgrPalette get palette => Theme.of(this).extension<LedgrPalette>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? LedgrPalette.dark : LedgrPalette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.brandBright : AppColors.brand,
      onPrimary: Colors.white,
      surface: isDark ? const Color(0xFF101217) : const Color(0xFFF5F6FA),
      onSurface: isDark ? const Color(0xFFECEDF2) : const Color(0xFF14161C),
      onSurfaceVariant:
          isDark ? const Color(0xFF9096A6) : const Color(0xFF6B7080),
      surfaceContainerLowest: isDark ? const Color(0xFF0B0D11) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF15181E) : Colors.white,
      surfaceContainer:
          isDark ? const Color(0xFF1B1E26) : const Color(0xFFEFF0F5),
      surfaceContainerHigh:
          isDark ? const Color(0xFF22262F) : const Color(0xFFE8E9F0),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2A2E38) : const Color(0xFFE1E3EB),
      outlineVariant:
          isDark ? const Color(0xFF262A33) : const Color(0xFFE4E6EE),
      error: palette.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
      headlineMedium: base.textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineSmall: base.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium:
          base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall:
          base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge:
          base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    final radius14 = BorderRadius.circular(14);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        // Dark sheets/cards are close to surfaceContainer, so lift fields.
        fillColor:
            isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius14,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.outlineVariant),
          selectedBackgroundColor:
              scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
          selectedForegroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: palette.card,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
