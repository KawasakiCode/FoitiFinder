//Date Preferences: who the user is shown.
//
//These are the HARD FILTERS the feed applies before anything is scored. Moved
//here from the settings page, which is for app preferences, not for who you
//want to date.
//
//The gender preference and the age range write through SettingsProvider, so
//the backend columns behind them (preferred_gender, min_age_range,
//max_age_range) stay in sync.
//
//UI ONLY, FOR NOW: height range, place of residence, alcohol, smoking, dating
//intention and kids. They live in this page's state and are lost when it
//closes - no provider, no API call, and no database columns yet (those need a
//new alembic revision). The kPref* choices in constants/profile_options.dart
//carry the column names they are meant to get.

import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences/preferred_gender_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_dialog.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/widgets/app_switch.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:provider/provider.dart';

class DatePreferencesPage extends StatefulWidget {
  const DatePreferencesPage({super.key});

  @override
  State<DatePreferencesPage> createState() => _DatePreferencesPageState();
}

class _DatePreferencesPageState extends State<DatePreferencesPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  //Breeze's range. BOTH ENDS ARE OPEN: a handle left at 130 means "130 or
  //shorter" and at 220 "220 or taller", so nobody is filtered out just for
  //being outside the slider - the profile height box accepts values beyond it.
  static const double _minHeightCm = 130;
  static const double _maxHeightCm = 220;

  //TODO: local only until the backend columns exist
  RangeValues _heightRange = const RangeValues(_minHeightCm, _maxHeightCm);
  //on by default: a preference that hides people should be opted into
  bool _showOutsideResidence = true;
  //choice key -> acceptable answers. Empty or missing means no preference.
  final Map<String, List<String>> _choiceAnswers = {};

  //the value shown next to the height slider, marking the open ends
  String _heightLabel() {
    final start = _heightRange.start.round();
    final end = _heightRange.end.round();
    final from = start <= _minHeightCm ? '≤$start' : '$start';
    final to = end >= _maxHeightCm ? '$end+' : '$end';
    return '$from - $to ${text.cm}';
  }

  //same summary as edit profile: nothing, the single answer, or a count
  String _choiceSummary(ProfileChoice choice) {
    final picks = _choiceAnswers[choice.key] ?? const [];
    if (picks.isEmpty) return '';
    if (picks.length == 1) return catalogueLabel(text, picks.first);
    return '${picks.length}';
  }

  //the same dialog edit profile opens for these categories
  Future<void> _openChoiceDialog(ProfileChoice choice) async {
    final result = await showChoiceDialog(
      context,
      choice: choice,
      initialSelected: _choiceAnswers[choice.key] ?? const [],
    );
    //null means dismissed - leave the answer alone. An empty list means cleared.
    if (!mounted || result == null) return;
    setState(() => _choiceAnswers[choice.key] = result);
  }

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
          padding: const EdgeInsets.only(bottom: 24),
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
                  //instant, not lerped - see widgets/nav_row.dart
                  animationDuration: Duration.zero,
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
                            children: [
                              //shrinks so the arrow always fits: the Greek
                              //empty-state text is long enough to overflow
                              Expanded(
                                child: Text(
                                  settings.preferredGender.isEmpty
                                      ? text.emptyInterests
                                      : displayInterests,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
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
              _RangeCard(
                label: text.ageRange,
                valueLabel:
                    '${settings.ageRange.start.toInt()} - ${settings.ageRange.end.toInt()}',
                slider: RangeSlider(
                  values: settings.ageRange,
                  min: 18,
                  max: 100,
                  divisions: 82,
                  onChanged: (v) => settings.saveAgeRange(v),
                ),
              ),
              //Height range - the same card as the age range
              _RangeCard(
                label: text.heightRange,
                valueLabel: _heightLabel(),
                slider: RangeSlider(
                  values: _heightRange,
                  min: _minHeightCm,
                  max: _maxHeightCm,
                  //one step per centimetre
                  divisions: (_maxHeightCm - _minHeightCm).round(),
                  onChanged: (v) => setState(() => _heightRange = v),
                ),
              ),
              //Place of residence: a plain yes/no for now. Without coordinates
              //there is no distance to set, only "my prefecture" or not - see
              //constants/greek_prefectures.dart.
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text.showOutsideResidence,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppSwitch(
                        value: _showOutsideResidence,
                        onChanged: (value) =>
                            setState(() => _showOutsideResidence = value),
                      ),
                    ],
                  ),
                ),
              ),

              //Their habits: alcohol and smoking, asked as "what do you want?"
              Align(
                alignment: Alignment.centerLeft,
                child: SectionHeader(text.sectionTheirHabits),
              ),
              CardGroup(
                dividers: true,
                children: [
                  for (final choice in const [kPrefAlcohol, kPrefSmoking])
                    NavRow(
                      label: catalogueLabel(text, choice.title),
                      trailing: _choiceSummary(choice),
                      onTap: () => _openChoiceDialog(choice),
                    ),
                ],
              ),

              //What they want: dating intention and kids
              Align(
                alignment: Alignment.centerLeft,
                child: SectionHeader(text.sectionWhatTheyWant),
              ),
              CardGroup(
                dividers: true,
                children: [
                  for (final choice in const [
                    kPrefDatingIntention,
                    kPrefKids,
                  ])
                    NavRow(
                      label: catalogueLabel(text, choice.title),
                      trailing: _choiceSummary(choice),
                      onTap: () => _openChoiceDialog(choice),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//A label, its current value on the right, and a range slider underneath, in
//the page's filled card. Shared by the age and height ranges so the two stay
//visually identical.
class _RangeCard extends StatelessWidget {
  final String label;
  final String valueLabel;
  final Widget slider;

  const _RangeCard({
    required this.label,
    required this.valueLabel,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              children: [
                //the label gives way, the value never does: "≤130 - 220+ cm"
                //next to a Greek label, or with a large system font, is wider
                //than the card and used to overflow
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  valueLabel,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            slider,
          ],
        ),
      ),
    );
  }
}
