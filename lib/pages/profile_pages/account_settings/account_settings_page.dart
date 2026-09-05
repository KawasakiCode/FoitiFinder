//Account Settings: the account itself rather than the profile others see.
//
//The identity fields (username, full name, gender, birthday, height, place of
//residence, education) moved here from the edit profile page, which is now
//purely about what other people look at - photos, stories, tags, prompts.
//
//Log out and delete account sit OUTSIDE the card, unstyled and red, so a
//destructive action never looks like one more row in a list of settings.
//
//NO FUNCTIONALITY YET. Every row is a placeholder: gender will push a page,
//birthday / height / education will open a dialog, and email is not a button
//at all - the account is keyed on it, so it must not be editable here.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/profile_pages/account_settings/delete_account_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:provider/provider.dart';

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    //listen: true so a value edited from one of these rows shows up here as
    //soon as it is saved, once the rows actually do something
    final user = Provider.of<ProfileProvider>(context).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.accountSettings),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 15, bottom: 24),
          children: [
            CardGroup(
              dividers: true,
              children: [
                NavRow(
                  label: text.username,
                  trailing: user?.username ?? '',
                  onTap: () {},
                ),
                NavRow(
                  label: text.fullName,
                  trailing: user?.fullName ?? '',
                  onTap: () {},
                ),
                //pushes its own page - more options than a dialog holds
                NavRow(
                  label: text.gender,
                  trailing: user?.gender ?? '',
                  onTap: () {},
                ),
                //dialog with a date picker. Stored as a date rather than the
                //age integer we have now, so age can be derived and stays
                //correct without anyone editing it on their birthday.
                NavRow(label: text.birthday, onTap: () {}),
                //dialog
                NavRow(label: text.height, onTap: () {}),
                NavRow(label: text.placeOfResidence, onTap: () {}),
                //dialog
                NavRow(label: text.education, onTap: () {}),
                //NOT a button: the Firebase account is keyed on this address
                //and the university domain behind it is what proves the user
                //is a student, so changing it is not a profile edit.
                _ReadOnlyRow(
                  label: text.email,
                  value: FirebaseAuth.instance.currentUser?.email ?? '',
                ),
              ],
            ),

            const SizedBox(height: 8),

            //Logout Button
            //
            //Align, because a ListView stretches its children to the full width
            //and the TextButton's tap target ran edge to edge - a destructive
            //action that reacts to a tap far away from its own label.
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    await settings.clearData();
                    if (!context.mounted) return;
                    await Provider.of<ProfileProvider>(
                      context,
                      listen: false,
                    ).clearData();
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
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
            ),
            //Delete account button
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
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
            ),
          ],
        ),
      ),
    );
  }
}

//A row that shows a value but cannot be tapped: same metrics as NavRow so it
//lines up with the rest of the card, minus the chevron and the press feedback
//that would promise an editor there isn't one for.
class _ReadOnlyRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
          if (value.isNotEmpty)
            //email addresses are long: let it take the width a chevron and its
            //gap would have used, and ellipsise rather than overflow
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
