//The app's flagship call-to-action button: a gradient pill. Use this for the
//main action on a screen. Set expand:false for an inline, content-width button
//(e.g. an "Edit profile" chip); expand defaults to full width for form CTAs.

import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';

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

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              //full width for form CTAs; wraps content when expand:false
              width: expand ? double.infinity : null,
              height: 54,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 28),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: isLoading
                      ? const [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        ]
                      : [
                          if (icon != null) ...[
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
