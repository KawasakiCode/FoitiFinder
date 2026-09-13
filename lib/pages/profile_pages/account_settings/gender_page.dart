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
//Saves itself: the PATCH happens here, so a failed request leaves the page
//open with the choice still selected instead of silently losing it. Pops true
//once saved, false when nothing changed.

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
  bool _saving = false;

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
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final user = profile.currentUser;
    final selected = _selected;
    if (user == null || selected == null) return;

    if (selected == user.gender) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.updateUserData(uid: user.uid, gender: selected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(text.errorOccured)));
      return;
    }

    //local state only changes once the backend has the value
    profile.updateLocalUser(gender: selected);
    //SettingsProvider keeps its own copy of the gender (used by the setup
    //page), so it has to hear about the change too or it goes stale on disk
    await settings.setLocalGender(selected);

    if (!mounted) return;
    Navigator.pop(context, true);
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
            onChanged: (value) {
              if (_saving) return;
              setState(() => _selected = value);
            },
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
          isLoading: _saving,
          onPressed: _selected == null ? null : _save,
        ),
      ),
    );
  }
}
