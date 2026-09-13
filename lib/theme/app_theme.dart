//Builds the light and dark ThemeData from the design tokens in app_colors.dart.
//Centralising it here keeps main.dart small and the look consistent.

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'PlusJakartaSans';

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color background =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color surfaceVariant =
        isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    //fromSeed fills every required slot, then we pin the colors we care about
    //and kill the M3 surface tint so surfaces don't get a coloured overlay.
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: surface,
      onSurface: textPrimary,
      surfaceTint: Colors.transparent,
      error: AppColors.error,
      //THE CARD COLOUR - and all five of its neighbours.
      //
      //fromSeed generates the whole surfaceContainer ramp by TINTING the seed,
      //so with a violet seed every one of these is a lavender grey. Pinning
      //only surfaceContainerHighest left the other four tinted, and any widget
      //that reaches for one of them (AlertDialog uses surfaceContainerHigh,
      //BottomSheet uses surfaceContainerLow) renders visibly blue against our
      //neutral cards. They all resolve to the same neutral now, so there is no
      //tinted surface anywhere in the scheme to leak through.
      surfaceContainerLowest: isDark ? const Color(0xFF101010) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF141414) : Colors.white,
      surfaceContainer: isDark ? const Color(0xFF141414) : Colors.white,
      surfaceContainerHigh: isDark ? const Color(0xFF181818) : Colors.white,
      surfaceContainerHighest:
          isDark ? const Color(0xFF181818) : Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: _textTheme(textPrimary, textSecondary),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      //NO INK RIPPLES ANYWHERE.
      //
      //Pressable is the app's press feedback (dim the content, no expanding
      //splash) but it can only cover rows we build ourselves. Material widgets
      //with a built-in InkWell - RadioListTile, CheckboxListTile, ListTile -
      //paint their own ripple internally and no wrapper can suppress it, so it
      //has to be switched off at the theme.
      //
      //splashFactory kills the expanding circle; the two transparent colours
      //kill the flat wash InkResponse falls back to underneath it. Without all
      //three the ripple colour fights whatever surface the row sits on and
      //reads as a glitch rather than a press.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      //Flutter's Android default is ZoomPageTransitionsBuilder, which scales
      //and fades the incoming route over a scrim. Wherever the incoming page's
      //background doesn't match what is underneath, that scrim reads as a
      //flash. A plain horizontal slide has no scrim and no cross-fade, so
      //there is nothing to flash.
      //
      //Applied to every platform so a push looks the same everywhere.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      //Solid primary buttons. The gradient hero CTA is the PrimaryButton widget.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? Colors.grey[400] : Colors.grey[600];
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return isDark
              ? AppColors.darkSurfaceVariant
              : const Color(0xFFD4D4D8);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      //ROUND CHECKBOXES, everywhere.
      //
      //The single-answer choice lists use radio buttons, which are round. The
      //multi-answer ones (every date preference, religion, political view) use
      //checkboxes, and Material's square box made those look like a different
      //control from a different app sitting in the same dialog. Set here rather
      //than per CheckboxListTile so no list can forget it.
      checkboxTheme: const CheckboxThemeData(shape: CircleBorder()),

      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor:
            isDark ? AppColors.darkSurfaceVariant : const Color(0xFFE4E4E7),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 70,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 28);
          }
          return IconThemeData(color: textSecondary, size: 26);
        }),
      ),

      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(surfaceVariant),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        hintStyle: WidgetStateProperty.all(
          TextStyle(color: textSecondary, fontWeight: FontWeight.w400),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? AppColors.darkSurfaceVariant : const Color(0xFF26262B),
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        //In dark mode the dialog sits ABOVE the cards rather than level with
        //them (#202020 against their #1a1a1a). With a lighter scrim the cards
        //no longer collapse to black, so the dialog needs its own separation
        //instead of relying on everything behind it going dark.
        backgroundColor: isDark ? const Color(0xFF202020) : surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: textSecondary,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge:
          TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: primary),
      headlineMedium:
          TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: primary),
      titleLarge:
          TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3, color: primary),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, color: primary),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, color: primary),
      //default text style for most widgets -> use the visible primary color,
      //not the faint secondary (that was making labels look washed out)
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, color: primary),
      bodySmall: TextStyle(fontWeight: FontWeight.w400, color: secondary),
      labelLarge:
          TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2, color: primary),
    ).apply(fontFamily: fontFamily);
  }
}
