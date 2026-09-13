//Pick your own gender.
//
//A page rather than a dialog on purpose: more is coming to this screen later,
//and a dialog would have to be rebuilt as a page the moment that lands.
//
//STORED VALUES ARE NOT THE LABELS. "Male" and "Female" are what the backend's
//matching already understands (preference_to_genders in
//backend/preferences/preferences.py maps "Men" -> "Male", "Women" -> "Female"),
//so they are stored exactly as before and only the label shown changes to
//Man / Woman. "Non-conforming" is new: no preference maps to it yet, so for now
//these profiles only appear to people whose preference is "Everyone".
//
//SHOW FIRST, THEN SAVE. Tapping Save updates the account page and closes this
//page immediately; the PATCH runs behind it. If the backend refuses, the old
//gender comes back on the account page at the same moment the error snackbar
//appears. Pops true when a change was made, false when nothing changed.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';

const String kGenderMale = 'Male';
const String kGenderFemale = 'Female';
const String kGenderNonConforming = 'Non-conforming';

const List<String> kGenderOptions = [
  kGenderMale,
  kGenderFemale,
  kGenderNonConforming,
];

//The stored value in the user's language. Anything unrecognised is shown as
//stored rather than hidden, so an odd value in the database is visible.
String genderLabel(AppLocalizations text, String? value) {
  switch (value) {
    case kGenderMale:
      return text.man;
    case kGenderFemale:
      return text.woman;
    case kGenderNonConforming:
      return text.nonConforming;
    default:
      return value ?? '';
  }
}

class GenderPage extends StatefulWidget {
  const GenderPage({super.key});

  @override
  State<GenderPage> createState() => _GenderPageState();
}

class _GenderPageState extends State<GenderPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  String? _selected;

  @override
  void initState() {
    super.initState();
    final current = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser?.gender;
    //an unknown or missing value starts with nothing selected
    _selected = kGenderOptions.contains(current) ? current : null;
  }

  Future<void> _save() async {
    //everything that needs context is read now: the page is closed before the
    //request comes back
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final errorMessage = text.errorOccured;
    final user = profile.currentUser;
    final selected = _selected;
    if (user == null || selected == null) return;

    if (selected == user.gender) {
      Navigator.pop(context, false);
      return;
    }

    final previous = user.gender;

    //updates the local user synchronously, before its first await
    final saved = profile.saveField<String?>(
      read: (u) => u.gender,
      write: (u, value) => u.copyWith(gender: () => value),
      value: selected,
      send: (uid) => ApiService.updateUserData(uid: uid, gender: selected),
    );
    //SettingsProvider keeps its own copy of the gender (used by the setup
    //page), so it follows the same show-first, revert-on-failure rule
    settings.setLocalGender(selected);

    Navigator.pop(context, true);

    if (await saved) return;

    //only undo the settings copy if nothing newer has replaced it
    if (settings.gender == selected) {
      settings.setLocalGender(previous ?? '');
    }
    messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(text.gender),
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(text.addGender, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value),
            child: Column(
              children: [
                for (final option in kGenderOptions)
                  RadioListTile<String>(
                    value: option,
                    title: Text(genderLabel(text, option)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          //LATER: the second part of this page goes here
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: PrimaryButton(
          label: text.save,
          onPressed: _selected == null ? null : _save,
        ),
      ),
    );
  }
}
