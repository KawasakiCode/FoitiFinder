//The Bio category from the profile page's list.
//
//Unlike the tag groups, this one PERSISTS today: `bio` is already a column on
//the users table and a field on UserModel, so it saves straight through
//ApiService like the bio field in edit_profile does.
//
//Saves on the way out (Save button or back button) and only when the text
//actually changed, so opening and closing the page never hits the backend.

import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';

//keeps the counter honest and stops a novel being posted to the backend
const int kBioMaxLength = 300;

class BioPage extends StatefulWidget {
  const BioPage({super.key});

  @override
  State<BioPage> createState() => _BioPageState();
}

class _BioPageState extends State<BioPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  late final TextEditingController _controller;
  late final String _originalBio;
  bool _isSaving = false;
  //set once the save succeeds so the pop that follows doesn't try again
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final user =
        Provider.of<ProfileProvider>(context, listen: false).currentUser;
    _originalBio = user?.bio ?? '';
    _controller = TextEditingController(text: _originalBio);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges => _controller.text.trim() != _originalBio.trim();

  //Returns true when it is safe to leave: either nothing changed, the save
  //worked, or the user chose to discard after a failure.
  Future<bool> _save() async {
    if (_saved || !_hasChanges) return true;

    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final uid = profileProvider.currentUser?.uid;
    //no signed-in profile to attach the bio to - nothing to save, and leaving
    //is still correct
    if (uid == null) return true;

    final newBio = _controller.text.trim();

    setState(() => _isSaving = true);
    try {
      await ApiService.updateUserData(uid: uid, bio: newBio);
      //only touch the local copy once the backend accepted it, so the profile
      //never shows a bio the server doesn't have
      profileProvider.updateLocalUser(bio: newBio);
      _saved = true;
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      //keep the user on the page with their text intact so they can retry
      return false;
    }
  }

  Future<void> _saveAndExit() async {
    final ok = await _save();
    if (!ok || !mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        //the back button saves too, matching edit_profile's behaviour
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _saveAndExit();
        },
        child: LoadingOverlay(
          isLoading: _isSaving,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Bio'),
              automaticallyImplyLeading: true,
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell people who you are.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    maxLength: kBioMaxLength,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    //redraw so the Save label tracks whether anything changed
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(
                //TODO: hardcoded like the rest of the catalogue UI - move to
                //app_en.arb / app_el.arb along with the group labels
                label: 'Save',
                onPressed: _saveAndExit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
