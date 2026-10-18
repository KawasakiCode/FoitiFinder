//Account Settings: the account itself rather than the profile others see.
//
//The identity fields (name, gender, birthday, height, place of
//residence, education) moved here from the edit profile page, which is now
//purely about what other people look at - photos, stories, tags, prompts.
//
//Log out and delete account sit OUTSIDE the card, unstyled and red, so a
//destructive action never looks like one more row in a list of settings.
//
//Education is deliberately NOT here. Edit profile owns it, where it is the
//detailed version (school, degree name) rather than the one-word answer an
//account row would hold. One home per fact.
//
//Name, birthday, height, place of residence and the Instagram handle open a
//dialog, gender pushes its own page, and email is not a button at all - the
//account is keyed on it, so it must not be editable here.
//
//THE INSTAGRAM ROW HAS NO CLEAR OPTION, unlike place of residence. With no
//chat in the app the handle is the entire payoff of a match, so emptying it
//would quietly put the account back in the state SetupWrapper refuses to let
//anyone leave setup in - and the next match would have nowhere to go. It can
//be changed, never removed.
//
//SHOW FIRST, THEN SAVE. Every edit changes the row the moment the dialog
//closes and the PATCH runs behind it - waiting on the network first made the
//row lag visibly behind the dialog. If the backend refuses, the old value comes
//back at the same moment the error snackbar appears (ProfileProvider.saveField).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/pages/profile_pages/account_settings/delete_account_page.dart';
import 'package:foitifinder/pages/profile_pages/account_settings/gender_page.dart';
import 'package:foitifinder/pages/profile_pages/shared/save_profile_field.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/pages/profile_pages/shared/prefecture_dialog.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/utils/age.dart';
import 'package:foitifinder/utils/instagram_handle.dart';
import 'package:foitifinder/widgets/app_dialog.dart';
import 'package:foitifinder/widgets/nav_row.dart';
import 'package:provider/provider.dart';

//Height is a plain number box instead of a slider, precisely so people outside
//a slider's range (Breeze's is 130-220) can still enter their real height.
//These bounds only exist to catch typos like 1800.
const int kMinHeightCm = 50;
const int kMaxHeightCm = 275;

//Same rule as signup (pages/auth_pages/signup.dart), so a name that was valid
//when the account was made stays valid when it is edited.
final RegExp _nameRegex = RegExp(r"^(?=.*[a-zA-Z])[a-zA-Z\s\-']+$");

//The trimmed name when it is acceptable, otherwise null.
String? validName(String input) {
  final name = input.trim();
  return _nameRegex.hasMatch(name) ? name : null;
}

//Centimetres when the input is a whole number inside the allowed range,
//otherwise null.
int? validHeightCm(String input) {
  final value = int.tryParse(input.trim());
  if (value == null || value < kMinHeightCm || value > kMaxHeightCm) {
    return null;
  }
  return value;
}

class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    //listen: true so an edit - and a revert after a failed save - shows up
    //here immediately
    final user = Provider.of<ProfileProvider>(context).currentUser;
    final birthday = user?.birthday;
    final heightCm = user?.heightCm;

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
                  label: text.name,
                  trailing: user?.name ?? '',
                  onTap: () => _editName(context),
                ),
                //pushes its own page - more options than a dialog holds
                NavRow(
                  label: text.gender,
                  trailing: genderLabel(text, user?.gender),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GenderPage()),
                  ),
                ),
                //Stored as a date rather than an age, so age is derived and
                //stays correct without anyone editing it on their birthday.
                NavRow(
                  label: text.birthday,
                  trailing: birthday == null
                      ? ''
                      : '${birthday.day}/${birthday.month}/${birthday.year}',
                  onTap: () => _editBirthday(context),
                ),
                NavRow(
                  label: text.height,
                  trailing: heightCm == null ? '' : '$heightCm ${text.cm}',
                  onTap: () => _editHeight(context),
                ),
                NavRow(
                  label: text.placeOfResidence,
                  //stored English, shown in the user's language
                  trailing: user?.city == null
                      ? ''
                      : catalogueLabel(text, user!.city!),
                  onTap: () => _editCity(context),
                ),
                //shown with the @ people read it with, stored without one
                NavRow(
                  label: text.instagram,
                  trailing: user?.instagramHandle == null
                      ? ''
                      : '@${user!.instagramHandle!}',
                  onTap: () => _editInstagram(context),
                ),
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
                    //the next account must not inherit this one's bell
                    Provider.of<NotificationsProvider>(
                      context,
                      listen: false,
                    ).clear();
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

//Edit the name: a text box, validated with the same rule as signup.
Future<void> _editName(BuildContext context) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final current = profileProvider.currentUser?.name ?? '';

  final result = await showAppDialog<String>(
    context: context,
    builder: (_) => _NameDialog(initial: current),
  );

  //null means dismissed
  if (result == null || result == current || !context.mounted) return;

  await saveProfileField<String>(
    context,
    read: (u) => u.name,
    write: (u, value) => u.copyWith(name: value),
    value: result,
    send: (uid) => ApiService.updateUserData(uid: uid, name: result),
  );
}

//Edit the Instagram handle.
//
//Same normaliser as the setup page and the backend, so a pasted profile link
//becomes a handle here too and the three places cannot disagree. There is no
//Clear action: the dialog can only return a valid handle, because the
//normaliser turns anything else - including an empty box - into an error.
Future<void> _editInstagram(BuildContext context) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final current = profileProvider.currentUser?.instagramHandle ?? '';

  final result = await showAppDialog<String>(
    context: context,
    builder: (_) => _InstagramDialog(initial: current),
  );

  //null means dismissed
  if (result == null || result == current || !context.mounted) return;

  await saveProfileField<String?>(
    context,
    read: (u) => u.instagramHandle,
    write: (u, value) => u.copyWith(instagramHandle: () => value),
    value: result,
    send: (uid) => ApiService.patchUser({'instagram_handle': result}),
  );
}

//Edit the birthday with the same date picker, and the same bounds, as the
//setup page: 18 years ago is the latest pickable date, so an under-age
//birthday cannot be chosen at all.
Future<void> _editBirthday(BuildContext context) async {
  final text = AppLocalizations.of(context)!;
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final current = profileProvider.currentUser?.birthday;

  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? birthdayForAge(20),
    firstDate: birthdayForAge(100),
    lastDate: birthdayForAge(18),
    helpText: text.birthday,
  );

  if (picked == null || !context.mounted) return;
  if (current != null && DateUtils.isSameDay(picked, current)) return;

  await saveProfileField<DateTime?>(
    context,
    read: (u) => u.birthday,
    write: (u, value) => u.copyWith(birthday: () => value),
    value: picked,
    send: (uid) => ApiService.updateUserData(uid: uid, birthday: picked),
  );
}

//Edit the height: a plain number box in centimetres.
Future<void> _editHeight(BuildContext context) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final current = profileProvider.currentUser?.heightCm;

  final result = await showAppDialog<int>(
    context: context,
    builder: (_) => _HeightDialog(initial: current),
  );

  if (result == null || result == current || !context.mounted) return;

  await saveProfileField<int?>(
    context,
    read: (u) => u.heightCm,
    write: (u, value) => u.copyWith(heightCm: () => value),
    value: result,
    send: (uid) => ApiService.updateUserData(uid: uid, heightCm: result),
  );
}

//Edit the place of residence.
//
//A prefecture from a closed list, never free text. Place of residence has to
//be FILTERABLE, and free text cannot be: "Thessaloniki", "thessaloniki" and
//"Stavroupoli" would all be different values that never match each other.
//
//Prefecture rather than city or municipality because without coordinates a
//radius filter is impossible - see constants/greek_prefectures.dart.
Future<void> _editCity(BuildContext context) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final current = profileProvider.currentUser?.city ?? '';

  final result = await showPrefectureDialog(
    context,
    initialSelected: current.isEmpty ? null : current,
  );

  //null means dismissed - leave it alone. '' means cleared.
  if (result == null || result == current || !context.mounted) return;

  await saveProfileField<String?>(
    context,
    read: (u) => u.city,
    //cleared is stored as null locally, the same as the backend stores it
    write: (u, value) => u.copyWith(city: () => value),
    value: result.isEmpty ? null : result,
    //'' is SENT, not skipped: it is how the backend is told to clear it
    send: (uid) => ApiService.updateUserData(uid: uid, city: result),
  );
}

//Text box for the name. Pops the trimmed name, or null when dismissed.
//The handle dialog: prefilled with the current one, and it cannot return
//nothing. Cancel and Save only - see the note at the top of the file for why
//there is no Clear.
class _InstagramDialog extends StatefulWidget {
  final String initial;

  const _InstagramDialog({required this.initial});

  @override
  State<_InstagramDialog> createState() => _InstagramDialogState();
}

class _InstagramDialogState extends State<_InstagramDialog> {
  late final TextEditingController _controller;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final handle = normaliseInstagramHandle(_controller.text);
    //null covers an empty box, a half-typed handle and a pasted URL that
    //turned out not to contain one. All of them are the same answer here: not
    //yet something we can hand to a match.
    if (handle == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, handle);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(text.instagram),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //worth repeating here: this dialog may be opened months after
          //setup, by someone who no longer remembers who ever sees this
          Text(
            text.instagramPrivacy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.done,
            //a handle has no spaces; a pasted link has none either, so this
            //never blocks legitimate input
            inputFormatters: [FilteringTextInputFormatter.deny(' ')],
            decoration: InputDecoration(
              prefixText: '@',
              hintText: text.instagramHint,
              errorText: _showError ? text.instagramInvalid : null,
              errorMaxLines: 3,
            ),
            //the error goes away as soon as they start fixing it
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(text.save)),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = validName(_controller.text);
    if (name == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(text.name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          errorText: _showError ? text.nameRestriction : null,
          errorMaxLines: 3,
        ),
        //the error goes away as soon as they start fixing it
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(text.save)),
      ],
    );
  }
}

//Number box for the height. Pops centimetres, or null when dismissed.
class _HeightDialog extends StatefulWidget {
  final int? initial;

  const _HeightDialog({required this.initial});

  @override
  State<_HeightDialog> createState() => _HeightDialogState();
}

class _HeightDialogState extends State<_HeightDialog> {
  late final TextEditingController _controller;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final heightCm = validHeightCm(_controller.text);
    if (heightCm == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, heightCm);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(text.height),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        //digits only, so "1,80" or "180cm" can't even be typed
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          suffixText: text.cm,
          errorText: _showError
              ? text.invalidHeight(kMinHeightCm, kMaxHeightCm)
              : null,
          errorMaxLines: 2,
        ),
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(text.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(text.save)),
      ],
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
