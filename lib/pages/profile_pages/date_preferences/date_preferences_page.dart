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
//SLIDERS SAVE ON RELEASE, not on every tick. onChanged fires dozens of times
//a drag, so the drag is local and onChangeEnd sends the one value the user
//let go on.
//
//Gender, age, height and languages filter the feed. Place of residence and
//the four choices are stored and not yet used by the query.

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
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:foitifinder/widgets/polish.dart';
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

    return GlassScaffold(
      appBar: PageAppBar(title: text.datePreferences),
      body: GlassScroll(
        slivers: [
          SliverStagger(
            padding: EdgeInsets.zero,
            children: [
              //Discovery Settings (Interests)
              SectionHeader(text.discovery),
              CardGroup(
                children: [
                  SpringPress(
                    child: Pressable(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => InterestPage()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            //shrinks so the arrow always fits: the Greek
                            //empty-state text is long enough to overflow
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text.interests,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    settings.preferredGender.isEmpty
                                        ? text.emptyInterests
                                        : displayInterests,
                                    overflow: TextOverflow.ellipsis,
                                    style: mutedText(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.chevron_right, color: mutedInk(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              //The two ranges share ONE card, divided like the habits rows
              //below: they are the same kind of setting answered the same way,
              //and two separate cards made them look unrelated.
              CardGroup(
                dividers: true,
                children: [
                  _RangeRow(
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
                  _RangeRow(
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
                ],
              ),
              const SizedBox(height: 16),

              //Languages, in the discovery block: like the two ranges above it
              //decides WHO is shown, not what they are like.
              CardGroup(
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
              const SizedBox(height: 16),
              //Place of residence: a plain yes/no for now. Without coordinates
              //there is no distance to set, only "my prefecture" or not - see
              //constants/greek_prefectures.dart.
              CardGroup(
                children: [
                  SwitchRow(
                    label: text.showOutsideResidence,
                    value: _user.showOutsideResidence,
                    onChanged: _saveShowOutsideResidence,
                  ),
                ],
              ),

              //Their habits: alcohol and smoking, asked as "what do you want?"
              SectionHeader(text.sectionTheirHabits),
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
              SectionHeader(text.sectionWhatTheyWant),
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
        ],
      ),
    );
  }
}

//A label, its current value, and the slider under them. No card of its own -
//the page's CardGroup provides it, so the age and height ranges stay
//visually identical.
class _RangeRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final Widget slider;

  const _RangeRow({
    required this.label,
    required this.valueLabel,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              //the label gives way, the value never does: "≤130 - 220+ cm"
              //next to a Greek label, or with a large system font, is wider
              //than the card and would overflow
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 16),
              Text(valueLabel, style: mutedText(context)),
            ],
          ),
          slider,
        ],
      ),
    );
  }
}
