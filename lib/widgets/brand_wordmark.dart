//The app's name as a picture, which is the only way it is ever drawn now.
//
//IT USED TO BE A FONT. "FoitiFinder" was set in GlutenWordmark, a 4.5 KB
//subset of Gluten carrying the eight distinct letters of the name, and the
//login screen rendered it as Text.rich in two colours. The font is gone and
//the artwork in assets/brand/ is what remains - same letters, same two
//colours, same tracking, drawn once by scripts/make_icon.py instead of on
//every frame.
//
//TWO FILES, PICKED BY THEME, AND THE CHOICE LIVES HERE ONCE. The ink is
//near-black in one file and near-white in the other, so a single image would
//vanish against one of the two backgrounds. Two widgets need that choice -
//the login logo and the app bar - and when each owned a copy of it the second
//one was a near-copy waiting to drift. They are named for the background they
//sit on, not for the colour they are.
//
//SIZED BY ITS INK, NOT BY ITS BOX, and the caller passes that height. The
//files carry 13.15% padding above and below the lettering - the ink is 0.7370
//of the image height, measured at half coverage - so matching an image to
//text means dividing the text's ink height by that fraction, never setting
//the image to the font size. See the two call sites for what each of them
//measured.
//
//MEASURE INK AT HALF COVERAGE, not at "any pixel that is not empty". Both
//text and a resized image carry a soft antialiased edge, and counting it
//reverses the answer - by that rule these images look TALLER than the text
//they replace rather than shorter, and the correction goes the wrong way.

import 'package:flutter/material.dart';

/// The wordmark artwork at [height], labelled [label] for screen readers.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    required this.height,
    required this.label,
  });

  /// The height of the IMAGE, not of the lettering inside it.
  final double height;

  /// What a screen reader says, since an image has no words in it.
  final String label;

  /// The ink's share of the image's height, at half coverage.
  ///
  /// Divide a text ink height by this to get the image height that matches
  /// it. If the padding in `scripts/make_icon.py` changes, so does this.
  static const double inkFraction = 0.7370;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      dark
          ? 'assets/brand/wordmark_on_dark.png'
          : 'assets/brand/wordmark_on_light.png',
      height: height,
      //the source is far larger than this draws it, so the downscale is what
      //decides whether the logo looks crisp or furry
      filterQuality: FilterQuality.medium,
      semanticLabel: label,
    );
  }
}
