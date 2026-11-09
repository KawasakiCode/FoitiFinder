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

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: AppColors.brandGradient.createShader,
      child: const Text(
        'FoitiFinder',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: Colors.white,
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
