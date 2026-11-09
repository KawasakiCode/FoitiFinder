//This is the profile page
//Here the user can edit their profile (bio, age, email..)
//Also here the user can change their pfp

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/main_app_bar.dart';
import 'package:foitifinder/constants/legal.dart';
import 'package:foitifinder/pages/profile_pages/account_settings/account_settings_page.dart';
import 'package:foitifinder/pages/profile_pages/date_preferences/date_preferences_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile/edit_profile_page.dart';
import 'package:foitifinder/pages/profile_pages/app_settings/app_settings_page.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/polish.dart';
import 'package:foitifinder/widgets/pressable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/utils/age.dart';
import 'package:provider/provider.dart';
import 'package:foitifinder/widgets/app_dialog.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppLocalizations get text => AppLocalizations.of(context)!;

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
  //
  //THE DOCUMENT IS OPENED IN THE LANGUAGE THE APP IS IN, which is the same
  //locale the label beside it was just read from - so a Greek dialog cannot
  //hand out English documents. Taken from the active locale rather than from
  //the settings provider so it follows whatever Flutter actually resolved.
  List<({String label, String url})> get _policyDocuments {
    final language = Localizations.localeOf(context).languageCode;
    return [
      (
        label: text.privacyStatement,
        url: legalUrl(LegalDocument.privacyStatement, language)
      ),
      (
        label: text.userTerms,
        url: legalUrl(LegalDocument.userTerms, language)
      ),
      (
        label: text.userGuidelines,
        url: legalUrl(LegalDocument.userGuidelines, language)
      ),
      (
        label: text.cancellationPolicy,
        url: legalUrl(LegalDocument.cancellationPolicy, language)
      ),
      (
        label: text.recommenderSystem,
        url: legalUrl(LegalDocument.recommenderSystem, language)
      ),
    ];
  }

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
                        vertical: 16,
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
    //Else photo 0, which is the profile picture
    else if(profileProvider.currentUser?.profilePictureUrl != null) {
      backgroundImage = CachedNetworkImageProvider(profileProvider.currentUser!.profilePictureUrl!);
    }
    //Else show default pfp
    else {
      backgroundImage = AssetImage('assets/images/default_avatar.png');
    }

    return Scaffold(
      appBar: const MainAppBar(title: 'FoitiFinder'),
      body: Column(
        children: [
          //Main row (pfp, name, age)
          Entrance(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  //Pfp
                  SpringPress(
                    child: GestureDetector(
                      onTap: () async {
                        final result =
                            await profileProvider.updateProfilePicture();
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.card,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey[500],
                          backgroundImage: backgroundImage,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  //Username, age
                  //derived, never stored - see utils/age.dart
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final age = ageFromBirthday(
                          profileProvider.currentUser!.birthday,
                        );
                        final name = profileProvider.currentUser!.name;
                        return Text(
                          age == null ? name : '$name, $age',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          //Everything the profile page leads to. Scrolls on its own so the
          //header stays put on a short screen.
          Expanded(
            child: CustomScrollView(
              slivers: [
                //The four destinations, in one card like the settings page.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Entrance(
                      order: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.card,
                        ),
                        child: Material(
                          //instant, not lerped - see widgets/nav_row.dart
                          animationDuration: Duration.zero,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            side: BorderSide.none,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          //so the pressed tint on the first and last rows
                          //follows the card's rounded corners instead of
                          //squaring them off
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
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Entrance(
                    order: 2,
                    child: _SectionHeader(text.aboutFoitiFinder),
                  ),
                ),
                //Plain rows: no card, no chevron, just hairlines between them.
                //These are reference documents, not places you go to do
                //something, so they get less visual weight than the four above.
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Entrance(
                      order: 3,
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
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

    return SpringPress(
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
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

    return SpringPress(
      child: Pressable(
        onTap: onTap,
        //no background wash here: there is no card behind these, so a tint
        //would draw a box that exists only while the finger is down
        tintBackground: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
