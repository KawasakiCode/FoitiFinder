//Central color + design tokens for the app.
//Nothing else in the app should hardcode a hex color, use these instead so the
//whole look stays consistent and is changeable from one place.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---- Brand (refined violet, deeper/less neon than the old #8A2BE2) ----
  static const Color primary = Color(0xFF7C3AED); // violet-600
  static const Color primaryDark = Color(0xFF6D28D9); // violet-700
  static const Color primaryLight = Color(0xFF8B5CF6); // violet-500
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Signature gradient for primary CTAs (violet -> fuchsia/pink).
  static const Color gradientStart = Color(0xFF7C3AED);
  static const Color gradientEnd = Color(0xFFDB2777); // pink-600
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ---- Semantic (not raw Colors.red/green/orange) ----
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ---- Light neutrals (tuned, not pure grey) ----
  static const Color lightBackground = Color(0xFFF7F7F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F1F4);
  static const Color lightBorder = Color(0xFFE6E6EA);
  static const Color lightTextPrimary = Color(0xFF18181B);
  static const Color lightTextSecondary = Color(0xFF6B6B74);

  // ---- Dark neutrals ----
  static const Color darkBackground = Color(0xFF0A0A0B);
  static const Color darkSurface = Color(0xFF161618);
  static const Color darkSurfaceVariant = Color(0xFF222225);
  static const Color darkBorder = Color(0xFF2A2A2E);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
}

//Corner radius scale, keep these consistent everywhere.
class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
}

//Soft, low-opacity shadows. Material's default elevation shadows read harsh and
//"cheap", these are large-blur and subtle for a premium feel.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.32),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
