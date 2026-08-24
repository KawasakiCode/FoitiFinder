//Date Preferences: who the user wants to be shown.
//
//These are the HARD FILTERS the feed runs before anything is scored - gender
//preference, age range, and whether to show people outside it. They already
//exist as columns (interests, min_age_range, max_age_range, show_out_of_range)
//and are currently edited from the settings page.
//
//EMPTY ON PURPOSE for now: moving those controls out of settings is a separate
//job, and half-moving them would leave two screens writing the same columns.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class DatePreferencesPage extends StatelessWidget {
  const DatePreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.datePreferences),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            text.comingSoon,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
