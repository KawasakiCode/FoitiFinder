//This page is for the user to select who they are interested in
//The interests are sent to the settings provider where they are 
//also stored in the database and Shared Preferences

import 'package:flutter/material.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/polish.dart';

//Use a set for the interests since no duplicates are allowed
//and available options are only 3
Set<String> _selectedInterests = {};

class InterestPage extends StatefulWidget {
  const InterestPage({super.key});

  @override
  State<InterestPage> createState() => _InterestPageState();
}

class _InterestPageState extends State<InterestPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext buildContext) {
    final settings = Provider.of<SettingsProvider>(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic result) async {
        if (didPop) return;
          Navigator.pop(context, _selectedInterests);
      },
      child: GlassScaffold(
        appBar: PageAppBar(title: text.interestedIn),
        body: GlassScroll(
          slivers: [
            SliverStagger(
              padding: const EdgeInsets.only(top: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(text.selectInterests, style: mutedText(context)),
                ),
                CardGroup(
                  dividers: true,
                  children: [
                    CheckRow(
                      label: text.men,
                      selected: settings.preferredGender.contains("Men"),
                      onTap: () => settings.addRemovePreferredGender("Men"),
                    ),
                    CheckRow(
                      label: text.women,
                      selected: settings.preferredGender.contains("Women"),
                      onTap: () => settings.addRemovePreferredGender("Women"),
                    ),
                    CheckRow(
                      label: text.everybody,
                      selected: settings.preferredGender.contains("Everyone"),
                      onTap: () => settings.addRemovePreferredGender("Everyone"),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}