//The Flutter half of the launch screen.
//
//IT EXISTS TO HIDE A SEAM. The native launch screen is a gradient
//(android/app/src/main/res/drawable*/launch_background.xml) and it stops the
//instant Flutter draws its first frame - which, for anybody already signed
//in, is a wrapper waiting on Firebase Auth and then on the backend. That
//frame used to be a bare Scaffold, so the launch went gradient, white,
//app: a flash of white in the middle of starting up, which reads as the app
//having crashed and restarted rather than as it loading.
//
//THE COLOURS ARE DUPLICATED FROM THE DRAWABLE, deliberately and with a test
//pinning them together. They cannot be shared: the drawable is compiled
//Android XML read by the OS before any Dart exists, and these are Dart. The
//test is what stops them drifting - two gradients that are nearly the same
//look worse than one obvious cut, because the eye reads it as a flicker.

import 'package:flutter/material.dart';

//THE SAME THREE STOPS AS launch_background.xml, in the same order.
const Color kLaunchGradientStart = Color(0xFFC084FC);
const Color kLaunchGradientMiddle = Color(0xFF7C3AED);
const Color kLaunchGradientEnd = Color(0xFF312E81);

/// The gradient the app launches on, with [child] over it.
///
/// Used for the brief states between Flutter starting and the app knowing
/// which screen to show.
class LaunchScreen extends StatelessWidget {
  final Widget? child;

  const LaunchScreen({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            //Android's angle 315 runs top-left to bottom-right; these two
            //alignments are the same line.
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kLaunchGradientStart,
              kLaunchGradientMiddle,
              kLaunchGradientEnd,
            ],
          ),
        ),
        child: Center(
          //WHITE, NOT THE THEME'S ACCENT. The theme is built for a light
          //background and its primary is this gradient's own middle colour -
          //a spinner in it would be nearly invisible against the middle of
          //the screen, which is exactly where it sits.
          child: child ??
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
        ),
      ),
    );
  }
}
