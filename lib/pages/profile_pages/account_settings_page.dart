//Account Settings: the account itself rather than the profile shown to others
//- email, password, logging out, deleting the account.
//
//EMPTY ON PURPOSE for now: log out and delete account still live on the
//settings page, and moving them is a separate job. Two screens offering
//account deletion would be worse than one.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.accountSettings),
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
