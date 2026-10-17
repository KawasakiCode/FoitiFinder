//The first thing setup asks for: the Instagram handle.
//
//FIRST ON PURPOSE, AND THAT IS THE WHOLE DESIGN OF THIS PAGE. It is the most
//personal thing the app asks for and the one most likely to make someone
//close the app, so it is asked while they still have nothing invested - not
//after six photos and a bio. Someone who is not willing to share it should
//find that out here, and someone who is should understand exactly what they
//are agreeing to before they type it.
//
//Hence the three lines above the field, which are the only content on the
//page: there is no chat, a match swaps handles, and nobody can find it by
//browsing. Everything else about setup can be explored by poking at it. This
//cannot, because the consequence happens later and to someone else.
//
//REQUIRED, with no way past it. The column is nullable (registration happens
//before setup) but SetupWrapper sends the user back here on every launch
//until it is filled, the same way it does for photos - a match with no handle
//has no way to continue, and telling someone afterwards that their match
//"did not go through" puts the cost on whoever did everything right.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/main_screen.dart';
import 'package:foitifinder/pages/sign_up_set_up/add_photos.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/utils/instagram_handle.dart';
import 'package:foitifinder/widgets/loading_overlay.dart';
import 'package:foitifinder/widgets/primary_button.dart';
import 'package:provider/provider.dart';

class InstagramPage extends StatefulWidget {
  const InstagramPage({super.key});

  @override
  State<InstagramPage> createState() => _InstagramPageState();
}

class _InstagramPageState extends State<InstagramPage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  //set after a failed save attempt, not while typing: complaining about an
  //unfinished handle as it is being typed is just noise
  String? _error;

  @override
  void initState() {
    super.initState();
    //already set (they got here by reopening the app mid-setup, or came back
    //to change it), so show what is stored rather than an empty field
    final existing = context.read<ProfileProvider>().currentUser?.instagramHandle;
    if (existing != null) _controller.text = existing;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    //cleaned here as well as on the server, so what gets saved is what the
    //user was shown - a pasted profile link becomes a handle in front of them
    final handle = normaliseInstagramHandle(_controller.text);
    if (handle == null) {
      setState(() => _error = text.instagramInvalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    //both read before the first await, so nothing touches context afterwards
    final profile = context.read<ProfileProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      await ApiService.patchUser({'instagram_handle': handle});

      //REFRESH THE CACHE, do not just move on. SetupWrapper reads the cached
      //user on the next launch, so a successful save that never reaches disk
      //would send the user back to this page with the handle already stored.
      if (uid != null) await profile.fetchUserFromApi(uid);

      if (!mounted) return;
      //WHERE NEXT DEPENDS ON WHY THEY ARE HERE. A new user is part way
      //through setup and carries on to the photos. Someone who finished setup
      //before this page existed is only here to fill in the one missing
      //field, and sending them through onboarding again would be absurd.
      final onboarding = !(profile.currentUser?.hasFinishedSetUp ?? false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => onboarding
              ? const AddPhotos()
              : MainScreen(uid: uid ?? ''),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.errorOccured)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(text.instagramTitle),
          //nothing to go back to: this is the first step, and the step before
          //it was verifying an email
          automaticallyImplyLeading: false,
        ),
        body: LoadingOverlay(
          isLoading: _saving,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(text.instagramIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Text(text.instagramPrivacy, style: muted),
              const SizedBox(height: 28),

              TextField(
                controller: _controller,
                autofocus: true,
                //a handle has no spaces, no capitals that matter and no
                //autocorrect worth running on it
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                //NOT maxLength: a pasted profile URL is legitimate input and
                //is longer than any handle. The normaliser shortens it.
                inputFormatters: [FilteringTextInputFormatter.deny(' ')],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixText: '@',
                  labelText: text.instagramLabel,
                  hintText: text.instagramHint,
                  errorText: _error,
                  helperText: text.instagramPasteOk,
                  helperMaxLines: 2,
                ),
                onChanged: (_) {
                  //clear a stale error as soon as they start fixing it
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),

              const SizedBox(height: 16),
              Text(text.instagramRequiredNote, style: muted),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: text.submit,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}
