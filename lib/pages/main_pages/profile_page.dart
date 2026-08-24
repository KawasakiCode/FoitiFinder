//This is the profile page
//Here the user can edit their profile (bio, age, email..)
//Also here the user can change their pfp

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/legal.dart';
import 'package:foitifinder/pages/profile_pages/account_settings_page.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile.dart';
import 'package:foitifinder/pages/settings/settings.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/dummy_user_data.dart';

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
            IconButton(
              icon: Image.asset(
                'assets/icons/settings.png',
                width: 25,
                height: 25,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          //Main row (pfp, username, age)
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
                      Text(
                        profileProvider.currentUser!.age != null ?
                        "${profileProvider.currentUser!.username}, "
                        : profileProvider.currentUser!.username,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profileProvider.currentUser!.age != null ?
                        "${profileProvider.currentUser!.age}"
                        : profileProvider.currentUser!.age == 0 ? 
                        "" : "",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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

                _SectionHeader(text.aboutFoitiFinder),
                _NavRow(
                  icon: Icons.privacy_tip_outlined,
                  label: text.privacyPolicy,
                  onTap: () => _openLegal(kPrivacyPolicyUrl),
                ),
                _NavRow(
                  icon: Icons.description_outlined,
                  label: text.terms,
                  onTap: () => _openLegal(kTermsOfServiceUrl),
                ),
                _NavRow(
                  icon: Icons.code_outlined,
                  label: text.openSourceLicences,
                  onTap: _openLicences,
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
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 4),
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

//One tappable row: icon, label, chevron.
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

    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: theme.textTheme.titleMedium),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
