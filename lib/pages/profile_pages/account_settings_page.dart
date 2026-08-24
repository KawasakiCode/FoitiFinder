//Account Settings: the account itself rather than the profile others see.
//
//Log out and delete account moved here from the settings page. Both are
//destructive and both belong with the account, not with language and
//notification preferences.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/settings/delete_account_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.accountSettings),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Logout Button
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await settings.clearData();
                    if(!context.mounted)return;
                    await Provider.of<ProfileProvider>(context, listen: false).clearData();
                    if (!context.mounted) return;
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false);
                  },
                  child: Text(
                    text.logout,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 255, 18, 18),
                    ),
                  ),
                ),
              ),
              //Delete account button
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeleteAccountPage(),
                      ),
                    );
                  },
                  child: Text(
                    text.deleteAccount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 255, 18, 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
