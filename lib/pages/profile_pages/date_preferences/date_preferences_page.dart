//Date Preferences: who the user is shown.
//
//These are the HARD FILTERS the feed applies before anything is scored - the
//gender preference and the age range. Moved here from the settings page, which
//is for app preferences, not for who you want to date.
//
//Every control writes through SettingsProvider, so the backend columns behind
//them (interests, min_age_range, max_age_range) stay in sync.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences/preferred_gender_page.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:provider/provider.dart';

class DatePreferencesPage extends StatefulWidget {
  const DatePreferencesPage({super.key});

  @override
  State<DatePreferencesPage> createState() => _DatePreferencesPageState();
}

class _DatePreferencesPageState extends State<DatePreferencesPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    //Interests start as a map because language can change
    //and we need to display the correct language
    final Map<String, String> interestsMap = {
      'Women': text.women,
      'Men': text.men,
      'Everyone': text.everybody,
    };
    String displayInterests = settings.preferredGender
        .map((rawKey) {
          return interestsMap[rawKey] ?? rawKey;
        })
        .join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(text.datePreferences),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              //Discovery Settings (Interests)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, top: 10),
                  child: Text(
                    text.discovery,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 15),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    side: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Pressable(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => InterestPage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 10,
                        right: 10,
                        bottom: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.interests,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                settings.preferredGender.isEmpty
                                    ? text.emptyInterests
                                    : displayInterests,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Image.asset(
                                'assets/icons/right-arrow.png',
                                width: 10,
                                height: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              //Discovery Settings (Age range and toggle out of range switch)
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 15,
                    right: 15,
                    top: 10,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            text.ageRange,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${settings.ageRange.start.toInt()} - ${settings.ageRange.end.toInt()}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: settings.ageRange,
                        min: 18,
                        max: 100,
                        divisions: 82,
                        onChanged: (v) => settings.saveAgeRange(v),
                      ),
                    ],
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
