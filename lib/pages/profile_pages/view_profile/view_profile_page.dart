//The profile as other people see it.
//
//SHELL ONLY for now: the header and the navigation are here, the content is
//not. What goes below is the same card other users get in the feed, so it
//should be built from the shared card widget rather than a second layout that
//drifts away from it.
//
//Pushed from the edit page rather than swapped into it - see shared/
//profile_tabs.dart for why these are two pages and not a TabBarView. Tapping
//Edit pops back instead of pushing, so the two can never stack up.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/profile_pages/shared/profile_tabs.dart';

class ViewProfilePage extends StatelessWidget {
  const ViewProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        //no back arrow: the Edit tab is the way back, and two controls doing
        //the same thing side by side reads as two different things
        automaticallyImplyLeading: false,
        title: ProfileTabs(
          selected: ProfileTab.view,
          onSwitch: () => Navigator.pop(context),
        ),
      ),
      body: Center(
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
      ),
    );
  }
}
