//What the login and signup forms have in common: the wordmark, the scroll
//that keeps a form centred until the keyboard needs the room, the divider, and
//the card that sends you to the other form.

import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/brand_wordmark.dart';
import 'package:foitifinder/widgets/polish.dart';

class AuthScroll extends StatelessWidget {
  final List<Widget> children;

  const AuthScroll({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//THE LOGO, as artwork rather than as text - see widgets/brand_wordmark.dart
//for why the font it used to be set in is gone.
//
//NOT LOCALISED, DELIBERATELY. It is a name, so it is the same string in both
//languages; the label below is only what a screen reader announces.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  //THE HEIGHT THAT MATCHES THE 40pt TEXT THIS REPLACED, measured rather than
  //guessed. Gluten at weight 500 and size 40 puts down 26.70px of ink for
  //this string, and the ink is 0.7370 of the image's height, so the image
  //reaches the same lettering at 36.23.
  //
  //Setting this to 40 - the obvious move, matching the old fontSize - would
  //draw the logo 10% larger than it used to be, because a font size is not an
  //ink height.
  static const double _inkMatchedHeight = 36.23;

  @override
  Widget build(BuildContext context) {
    //NO LONGER SCALES WITH THE ACCESSIBILITY TEXT SIZE, which the Text it
    //replaced did. That is a real difference and an acceptable one: the
    //reason the old version needed a FittedBox was that 40pt of a wide face
    //at a 3x text scale wanted 1322 logical pixels and ate the login form.
    //An image at a fixed height cannot do that, and the name is a mark rather
    //than something anybody reads for information.
    return const BrandWordmark(
      height: _inkMatchedHeight,
      label: 'FoitiFinder',
    );
  }
}

class OrDivider extends StatelessWidget {
  final String label;

  const OrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(label, style: mutedText(context)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class AuthSwitchCard extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  const AuthSwitchCard({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(prompt, style: mutedText(context))),
          SpringPress(
            child: TextButton(onPressed: onPressed, child: Text(action)),
          ),
        ],
      ),
    );
  }
}
