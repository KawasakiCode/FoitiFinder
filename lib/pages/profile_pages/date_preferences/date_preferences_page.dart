//Date Preferences: who the user is shown.
//
//These are the HARD FILTERS the feed applies before anything is scored. Moved
//here from the settings page, which is for app preferences, not for who you
//want to date.
//
//Two different owners, for historical reasons:
//  * gender preference and age range write through SettingsProvider (disk +
//    PATCH preferred_gender / min_age_range / max_age_range)
//  * height range, place of residence and the four choices write through
//    ProfileProvider like Edit Profile does (PATCH min/max_height_preference,
//    show_outside_residence, preferred_alcohol/_smoking/_dating_intention/_kids)
//
//SLIDERS SAVE ON RELEASE, not on every tick. onChanged fires dozens of times a
//drag and each one used to be a PATCH; now the drag is local and onChangeEnd
//sends the one value the user let go on.
//
//Only gender and age filter the feed so far - the rest is stored and waiting
//for the feed query to use it.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/profile_options.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/models/user_model.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences/preferred_gender_page.dart';
import 'package:foitifinder/pages/profile_pages/languages_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/choice_dialog.dart';
import 'package:foitifinder/pages/profile_pages/shared/save_profile_field.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
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

  //BOTH ENDS ARE OPEN: a handle left at 130 means "130 or
  //shorter" and at 220 "220 or taller", so nobody is filtered out just for
  //being outside the slider - the profile height box accepts values beyond it.
  static const double _minHeightCm = 130;
  static const double _maxHeightCm = 220;

  //Only set WHILE a slider is being dragged; null the rest of the time, when
  //the value shown is the saved one. Keeps the drag smooth without a request
  //per tick.
  RangeValues? _heightDrag;
  RangeValues? _ageDrag;

  UserModel get _user =>
      Provider.of<ProfileProvider>(context, listen: false).currentUser!;

  //A handle at either end of the slider is stored as null, "no limit", so
  //someone at 225cm is not filtered out by a slider that stops at 220.
  RangeValues get _savedHeightRange => RangeValues(
    (_user.minHeightPreference ?? _minHeightCm).toDouble(),
    (_user.maxHeightPreference ?? _maxHeightCm).toDouble(),
  );

  Future<void> _saveHeightRange(RangeValues values) async {
    final int? min = values.start <= _minHeightCm ? null : values.start.round();
    final int? max = values.end >= _maxHeightCm ? null : values.end.round();
    setState(() => _heightDrag = null);
    if (min == _user.minHeightPreference && max == _user.maxHeightPreference) {
      return;
    }
    await saveProfileField<(int?, int?)>(
      context,
      read: (u) => (u.minHeightPreference, u.maxHeightPreference),
      write: (u, v) => u.copyWith(
        minHeightPreference: () => v.$1,
        maxHeightPreference: () => v.$2,
      ),
      value: (min, max),
      //nulls are sent on purpose: that is how "no limit" is saved
      send: (_) => ApiService.patchUser({
        'min_height_preference': min,
        'max_height_preference': max,
      }),
    );
  }

  //The languages the other person must speak. Same page as the profile side,
  //different sentence at the top and a different column - see LanguagesPage.
  Future<void> _openPreferredLanguages() async {
    final current = _user.preferredLanguages;
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => LanguagesPage(
          initialSelected: current,
          intro: text.preferredLanguagesIntro,
        ),
      ),
    );
    if (!mounted || result == null || listEquals(result, current)) return;

    await saveProfileField<List<String>>(
      context,
      read: (u) => u.preferredLanguages,
      write: (u, value) => u.copyWith(preferredLanguages: value),
      value: result,
      send: (_) => ApiService.patchUser({'preferred_languages': result}),
    );
  }

  Future<void> _saveShowOutsideResidence(bool value) => saveProfileField<bool>(
    context,
    read: (u) => u.showOutsideResidence,
    write: (u, v) => u.copyWith(showOutsideResidence: v),
    value: value,
    send: (_) => ApiService.patchUser({'show_outside_residence': value}),
  );

  //the value shown next to the height slider, marking the open ends
  String _heightLabel(RangeValues range) {
    final start = range.start.round();
    final end = range.end.round();
    final from = start <= _minHeightCm ? '≤$start' : '$start';
    final to = end >= _maxHeightCm ? '$end+' : '$end';
    return '$from - $to ${text.cm}';
  }

  //same summary as edit profile: nothing, the single answer, or a count
  String _choiceSummary(ProfileChoice choice) {
    final picks = _user.choice(choice.key);
    if (picks.isEmpty) return '';
    if (picks.length == 1) return catalogueLabel(text, picks.first);
    return '${picks.length}';
  }

  //the same dialog edit profile opens for these categories
  Future<void> _openChoiceDialog(ProfileChoice choice) async {
    final current = _user.choice(choice.key);
    final result = await showChoiceDialog(
      context,
      choice: choice,
      initialSelected: current,
    );
    //null means dismissed - leave the answer alone. An empty list means cleared.
    if (!mounted || result == null || listEquals(result, current)) return;
    await saveProfileField<List<String>>(
      context,
      read: (u) => u.choice(choice.key),
      write: (u, value) => u.withChoice(choice.key, value),
      value: result,
      //all four are multi-select, so always the list itself
      send: (_) => ApiService.patchUser({choice.key: result}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    //subscribe, so rows redraw when a save lands or is reverted
    Provider.of<ProfileProvider>(context);
    final heightRange = _heightDrag ?? _savedHeightRange;
    final ageRange = _ageDrag ?? settings.ageRange;

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
                    '${ageRange.start.toInt()} - ${ageRange.end.toInt()}',
                slider: RangeSlider(
                  values: ageRange,
                  min: 18,
                  max: 100,
                  divisions: 82,
                  onChanged: (v) => setState(() => _ageDrag = v),
                  onChangeEnd: (v) {
                    setState(() => _ageDrag = null);
                    settings.saveAgeRange(v);
                  },
                ),
              ),
              //Height range - the same card as the age range
              _RangeCard(
                label: text.heightRange,
                valueLabel: _heightLabel(heightRange),
                slider: RangeSlider(
                  values: heightRange,
                  min: _minHeightCm,
                  max: _maxHeightCm,
                  //one step per centimetre
                  divisions: (_maxHeightCm - _minHeightCm).round(),
                  onChanged: (v) => setState(() => _heightDrag = v),
                  onChangeEnd: _saveHeightRange,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
                        value: _user.showOutsideResidence,
                        onChanged: _saveShowOutsideResidence,
                      ),
                    ],
                  ),
                ),
              ),

              //Languages, in the discovery block: like the age and height
              //ranges it decides WHO is shown, not what they are like.
              //the residence switch sits in its own padded container, so this
              //needs the same gap or the two cards touch
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: CardGroup(
                  children: [
                    NavRow(
                      label: text.languagesSpoken,
                      trailing: _user.preferredLanguages.isEmpty
                          ? ''
                          : '${_user.preferredLanguages.length}',
                      onTap: _openPreferredLanguages,
                    ),
                  ],
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
                  for (final choice in const [kPrefDatingIntention, kPrefKids])
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
