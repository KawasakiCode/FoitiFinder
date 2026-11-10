//The app's flagship call-to-action button: a gradient pill. Use this for the
//main action on a screen. Set expand:false for an inline, content-width button
//(e.g. an "Edit profile" chip); expand defaults to full width for form CTAs.
//
//WHILE LOADING THE LABEL STAYS AND SHIMMERS. A spinner in place of the words
//collapses a content-width button and forgets what was asked for; this keeps
//the button its own size and still says what it is doing.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/polish.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.6,
      duration: AppMotion.base,
      curve: AppMotion.standard,
      child: SpringPress(
        enabled: enabled,
        child: Semantics(
          container: true,
          button: true,
          enabled: enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onPressed : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.card,
              ),
              child: SizedBox(
                //full width for form CTAs; wraps content when expand:false
                width: expand ? double.infinity : null,
                height: 56,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 32),
                  child: AnimatedSwitcher(
                    duration: AppMotion.base,
                    child: isLoading
                        ? Shimmer(
                            key: const ValueKey('loading'),
                            base: Colors.white.withValues(alpha: 0.48),
                            highlight: Colors.white,
                            child: content,
                          )
                        : KeyedSubtree(
                            key: const ValueKey('idle'),
                            child: content,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
