//Central color + design tokens for the app.
//Nothing else in the app should hardcode a hex color, use these instead so the
//whole look stays consistent and is changeable from one place.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ---- Brand (refined violet) ----
  static const Color primary = Color(0xFF7C3AED); // violet-600
  static const Color primaryDark = Color(0xFF6D28D9); // violet-700
  static const Color primaryLight = Color(0xFF8B5CF6); // violet-500
  //violet-800. For small solid badges on top of photos, where the bright
  //primary is too loud.
  static const Color primaryDeep = Color(0xFF5B21B6);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Signature gradient for primary CTAs (violet -> fuchsia/pink).
  static const Color gradientStart = Color(0xFF7C3AED);
  static const Color gradientEnd = Color(0xFFDB2777); // pink-600
  static const LinearGradient brandGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  //Per-action gradients for the swipe-deck buttons (Tinder-style colour coding).
  static const LinearGradient rewindGradient = LinearGradient(
    colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)], // amber / gold
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient passGradient = LinearGradient(
    colors: [Color(0xFFFF6A88), Color(0xFFFF2D55)], // rose / red
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient superLikeGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF4F46E5)], // sky / indigo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  //THE SAME BUTTON, OUT OF STOCK. Grey rather than hidden or removed: a
  //button that disappears when you run out leaves people wondering what used
  //to be there, while a grey one says "this exists and you have none left" -
  //which is also what makes it worth tapping to find out when it comes back.
  static const LinearGradient spentGradient = LinearGradient(
    colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)], // grey 400 / grey 500
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient likeGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF059669)], // green (the "yes")
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient dmGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFF6366F1)], // violet / indigo
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---- Semantic (not raw Colors.red/green/orange) ----
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // ---- Light neutrals (tuned, not pure grey) ----
  static const Color lightBackground = Color(0xFFECECEF); // soft gray canvas (cards sit on top in white)
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F1F4);
  static const Color lightBorder = Color(0xFFE6E6EA);
  static const Color lightTextPrimary = Color(0xFF2A2A30); // dark gray, softer than pure black
  static const Color lightTextSecondary = Color(0xFF6B6B74);

  // ---- Dark neutrals ----
  //
  //TRUE NEUTRAL (R == G == B), not "tuned". A few units of blue bias
  //(#0A0A0B, #1A1A1E and so on) are invisible at rest but not when a surface
  //is DIMMED: darkening scales all three channels toward zero, so the ratio
  //between them is preserved while the absolute values shrink, and a bias
  //that is 4/255 at full brightness is proportionally a third of the signal
  //at quarter brightness. That is what makes a card flash blue while a
  //dialog's barrier fades in over it - and why light mode never does, since
  //white dimming toward grey has no hue to amplify.
  //
  //Keep these grey. A tint here is a tint that only shows up mid-animation.
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkSurfaceVariant = Color(0xFF202020);
  static const Color darkBorder = Color(0xFF282828);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
}

//How long things take, and how they ease.
//
//WHY A SCALE AND NOT A NUMBER AT EACH CALL SITE. This app had 19 distinct
//durations and 7 curves in it. None was wrong on its own, and that was exactly
//the problem: two things animating beside each other at 160ms/easeOut and
//240ms/easeOutCubic do not read as two decisions, they read as something
//slightly broken. The eye notices the mismatch without being able to name it,
//which is the hardest kind of wrong to find by looking.
//
//FOUR DURATIONS AND THREE CURVES is enough for every transition here. Anything
//that wants a fifth needs a reason that can be written down.
//
//PRESS IS NOT REALLY ON THE SCALE. 90ms is below the point where a duration
//reads as motion at all - it is the delay that makes a finger feel answered,
//and stretching it to fast would feel like lag.
//
//WHAT IS DELIBERATELY NOT HERE. The photo flight in profile_detail_page and
//photo_detail_page sets its own duration from how far the card has to travel,
//because a flight that took the same time regardless of distance would move at
//a different speed every time - see _kFlightShortest and _kFlightLongest, and
//the test in test/profile_flight_duration_test.dart. The shimmer's 1600ms is a
//loop period, not a transition. Route transitions belong to
//pageTransitionsTheme. None of those three are inconsistencies to fix.
class AppMotion {
  AppMotion._();

  //a finger being answered, not a thing moving
  static const Duration press = Duration(milliseconds: 90);
  //small state: a tick appearing, a label swapping, a colour settling
  static const Duration fast = Duration(milliseconds: 160);
  //THE DEFAULT. With no reason to choose another, choose this one.
  static const Duration base = Duration(milliseconds: 240);
  //whole surfaces: a sheet, a dialog, a tab sliding across
  static const Duration slow = Duration(milliseconds: 320);

  //DECELERATING, so a thing arrives under its own weight and settles instead
  //of stopping dead. This is the one to reach for.
  static const Curve standard = Curves.easeOutCubic;
  //overshoots a little, for something that should feel picked up rather than
  //placed - a selection indicator, a dialog arriving
  static const Curve emphasized = Curves.easeOutBack;
  //LEAVING SHOULD NOT DECELERATE. Something on its way out wants to be out of
  //the way, so it accelerates instead of easing to a stop.
  static const Curve exit = Curves.easeIn;
}

//Corner radius scale, keep these consistent everywhere.
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
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

  //wide and faint, so a card lifts off the page without drawing an outline
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.04),
      blurRadius: 24,
      spreadRadius: 8,
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
