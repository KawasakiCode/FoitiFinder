//This is the profile page
//Here the user can edit their profile (bio, age, email..)
//Also here the user can change their pfp

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/legal.dart';
import 'package:foitifinder/pages/profile_pages/account_settings/account_settings_page.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences/date_preferences_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/edit_profile_page.dart';
import 'package:foitifinder/pages/profile_pages/app_settings/app_settings_page.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/utils/age.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/dummy_user_data.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

  final dummy = DummyDataService();

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  //Open one of the legal documents in the browser.
  //
  //External on purpose: Play requires a publicly reachable privacy policy, and
  //hosting the text in-app would mean shipping an update to correct a typo in a
  //legal document.
  Future<void> _openLegal(String url) async {
    //not published yet -> say so instead of opening a blank tab
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.comingSoon)),
      );
      return;
    }

    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text.errorOccured),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  //The documents behind the Policies row.
  //
  //Built here rather than in legal.dart because the labels are localised and
  //there is no BuildContext at file top level. The URLs come from legal.dart;
  //the pairing is the only thing this list adds.
  List<({String label, String url})> get _policyDocuments => [
        (label: text.privacyStatement, url: kPrivacyStatementUrl),
        (label: text.userTerms, url: kUserTermsUrl),
        (label: text.userGuidelines, url: kUserGuidelinesUrl),
        (label: text.cancellationPolicy, url: kCancellationPolicyUrl),
        (label: text.recommenderSystem, url: kRecommenderSystemUrl),
      ];

  //One row on the profile page opens all five documents.
  //
  //A dialog rather than a page: there is nothing to do here except pick a
  //document, and a whole screen for five links is more navigation than the
  //content deserves.
  Future<void> _showPolicies() async {
    final chosen = await showAppDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.policies),
        //rows run edge to edge, so the padding lives on each row instead
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final doc in _policyDocuments)
                Pressable(
                  //pop with the URL rather than opening it here: the browser
                  //would otherwise launch behind a dialog still sitting on
                  //screen, and an unpublished document's snackbar would be
                  //hidden under the barrier
                  onTap: () => Navigator.pop(dialogContext, doc.url),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      child: Text(
                        doc.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(text.close),
          ),
        ],
      ),
    );

    //null means dismissed without picking anything
    if (!mounted || chosen == null) return;
    await _openLegal(chosen);
  }

  //Flutter collects every dependency's licence itself and renders them here.
  //MIT/BSD/Apache all require the notice to ship with the app, so this screen
  //is a licence obligation, not decoration - and it costs one call.
  void _openLicences() {
    showLicensePage(
      context: context,
      applicationName: 'FoitiFinder',
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    ImageProvider backgroundImage;

    //First check if pfp is stored locally
    if(profileProvider.tempProfileImage != null) {
      backgroundImage = ResizeImage(FileImage(profileProvider.tempProfileImage!), width: 300);
    }
    //If not locally grab it from the cloud
    else if(profileProvider.currentUser?.imageUrl != null && profileProvider.currentUser!.imageUrl!.isNotEmpty) {
      backgroundImage = CachedNetworkImageProvider(profileProvider.currentUser!.imageUrl!);
    }
    //Else show default pfp
    else {
      backgroundImage = AssetImage('assets/images/default_avatar.png');
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 2,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('FoitiFinder'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          //Main row (pfp, name, age)
          Row(
            children: [
              //Pfp
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 15, 15),
                child: GestureDetector(
                  onTap: () async {
                    final result = await profileProvider.updateProfilePicture();
                    if (!context.mounted) return;
                    if (result == ProfilePictureUpdate.failed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(text.errorOccured),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: CircleAvatar(  
                    radius: 40,
                    backgroundColor: Colors.grey[500],
                    backgroundImage: backgroundImage,
                  ),
                ),
              ),
              //Username, age
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      //derived, never stored - see utils/age.dart
                      Builder(
                        builder: (context) {
                          final age = ageFromBirthday(
                            profileProvider.currentUser!.birthday,
                          );
                          final name = profileProvider.currentUser!.name;
                          return Text(
                            age == null ? name : '$name, $age',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // FloatingActionButton(  
                  //   onPressed: () {
                  //     dummy.generateDummyUsers(30);
                  //   },
                  // ),
                ],
              ),
            ],
          ),
          //Everything the profile page leads to. Scrolls on its own so the
          //header stays put on a short screen.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                //The four destinations, in one card like the settings page.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Material(
                    //instant, not lerped - see widgets/nav_row.dart
                    animationDuration: Duration.zero,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      side: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    //so the pressed tint on the first and last rows follows the
                    //card's rounded corners instead of squaring them off
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavRow(
                          icon: Icons.person_outline,
                          label: text.editProfile,
                          onTap: () => _push(const EditProfile()),
                        ),
                        _NavRow(
                          icon: Icons.favorite_outline,
                          label: text.datePreferences,
                          onTap: () => _push(const DatePreferencesPage()),
                        ),
                        _NavRow(
                          icon: Icons.manage_accounts_outlined,
                          label: text.accountSettings,
                          onTap: () => _push(const AccountSettingsPage()),
                        ),
                        _NavRow(
                          icon: Icons.settings_outlined,
                          label: text.appSettings,
                          onTap: () => _push(const SettingsPage()),
                        ),
                      ],
                    ),
                  ),
                ),

                _SectionHeader(text.aboutFoitiFinder),
                //Plain rows: no card, no chevron, just hairlines between them.
                //These are reference documents, not places you go to do
                //something, so they get less visual weight than the four above.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlainRow(
                        label: text.policies,
                        onTap: _showPolicies,
                      ),
                      const Divider(),
                      _PlainRow(
                        label: text.openSourceLicences,
                        onTap: _openLicences,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//A heading above a run of related rows.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 28, 15, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

//A row inside the card: icon, label, chevron.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

//An About row: label only, no card and no chevron.
class _PlainRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PlainRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Pressable(
      onTap: onTap,
      //no background wash here: there is no card behind these, so a tint would
      //draw a box that exists only while the finger is down
      tintBackground: false,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(label, style: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }
}
