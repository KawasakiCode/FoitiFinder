//The profile as other people see it - the View half of the edit page.
//
//A BODY, NOT A PAGE: it has no Scaffold and no app bar, because it lives
//inside the edit page's PageView. That is what lets the header stay still
//while this slides in beneath it.
//
//SHELL ONLY for now: the content is not built. What belongs here is the same
//card the feed draws, not a second layout - two layouts for "a profile" drift
//apart, and then the preview stops previewing anything.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class ViewProfileBody extends StatelessWidget {
  const ViewProfileBody({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text.profilePreviewSoon,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
