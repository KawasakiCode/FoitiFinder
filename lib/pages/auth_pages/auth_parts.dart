//What the login and signup forms have in common: the wordmark, the scroll
//that keeps a form centred until the keyboard needs the room, the divider, and
//the card that sends you to the other form.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
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

//THE LOGO. Set in GlutenWordmark, a subset of Gluten carrying the eight
//distinct letters of this name and nothing else - 4.5 KB instead of 342 KB.
//See scripts/make_wordmark_font.py.
//
//TWO COLOURS, NOT THE GRADIENT IT USED TO BE. The policy site splits the name
//the same way, Foiti in the body colour and Finder in the accent, and the two
//have to look like one brand to somebody who has just come back from reading
//the privacy statement. A ShaderMask also flattened the whole thing into one
//ramp, which is a different mark rather than a recoloured one.
//
//NOT LOCALISED, DELIBERATELY. It is a name, so it is the same string in both
//languages - and the font has no Greek in it at all. Text.rich concatenates
//the spans for screen readers, so this is still announced as "FoitiFinder".
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return FittedBox(
      //A logo is the one thing that must not wrap or clip, and at the larger
      //accessibility text sizes 40pt of a wide face stops fitting a narrow
      //phone. Scaling down is the one legible way to lose that argument.
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Foiti',
              style: TextStyle(
                color: dark ? AppColors.darkWordmarkInk : AppColors.wordmarkInk,
              ),
            ),
            TextSpan(
              text: 'Finder',
              style: TextStyle(
                color: dark
                    ? AppColors.darkWordmarkAccent
                    : AppColors.wordmarkAccent,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        //-2.1 IS 0.0525 OF THE 40pt SIZE, the same fraction of the em that
        //TRACKING takes out of the images in scripts/make_icon.py. Gluten
        //sets this name loosely and it reads as a word rather than a mark;
        //this closes the gaps to almost nothing without letting the tight
        //pairs ("nd", "de") touch. Keep the two in step - the login screen
        //and every picture of the logo are supposed to be one thing.
        style: const TextStyle(
          fontFamily: 'GlutenWordmark',
          fontSize: 40,
          letterSpacing: -2.1,
        ),
      ),
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
