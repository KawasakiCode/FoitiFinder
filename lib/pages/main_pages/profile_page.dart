//This is the profile page
//Here the user can edit their profile (bio, age, email..)
//Also here the user can change their pfp

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/constants/interest_catalogue.dart';
import 'package:foitifinder/pages/profile_pages/interests/bio_page.dart';
import 'package:foitifinder/pages/profile_pages/edit_profile.dart';
import 'package:foitifinder/pages/profile_pages/interests/interest_group_page.dart';
import 'package:foitifinder/pages/profile_pages/interests/placeholder_group_page.dart';
import 'package:foitifinder/pages/settings/settings.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/l10n/catalogue_labels.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/widgets/primary_button.dart';
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

  //Picks made in the tag groups, keyed group title -> section title -> options.
  //
  //IN MEMORY ONLY, deliberately: there is no column to put these in yet. The
  //users table has `interests`, but that is the gender preference
  //("Men"/"Women"/"Everyone") and must not be reused - see the naming warning in
  //interest_catalogue.dart. Once the new column exists, this map is the single
  //place that changes: load it from the profile on entry and save it on return
  //from _openGroup.
  final Map<String, Map<String, List<String>>> _tagSelections = {};

  //how many options are picked in a group, for the row's trailing count
  int _pickCount(String groupTitle) =>
      _tagSelections[groupTitle]?.values.fold(0, (sum, l) => sum! + l.length) ??
      0;

  //Open the page a category row leads to. Three kinds of destination:
  //  Bio            -> a real text editor, because that column already exists
  //  empty groups   -> the placeholder page (Q&A's, Matching pools)
  //  everything else-> the tag grid, which hands its picks back on pop
  Future<void> _openGroup(String groupTitle) async {
    final group = interestGroupByTitle(groupTitle);

    if (groupTitle == kGroupBio) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BioPage()),
      );
      return;
    }

    if (group.sections.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaceholderGroupPage(group: group)),
      );
      return;
    }

    final result = await Navigator.push<Map<String, List<String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => InterestGroupPage(
          group: group,
          initialSelections: _tagSelections[groupTitle] ?? const {},
        ),
      ),
    );

    if (!mounted || result == null) return;
    setState(() => _tagSelections[groupTitle] = result);
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
              //Username, age, edit profile button
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
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: PrimaryButton(
                      label: text.editProfile,
                      icon: Icons.edit_outlined,
                      expand: false,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EditProfile()),
                        );
                      },
                    ),
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
          //Category list. Scrolls on its own so it can grow without pushing the
          //header off a short screen.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                for (final title in const [
                  kGroupHobbies,
                  kGroupTraits,
                  kGroupBio,
                  kGroupQA
                ])
                  _CategoryRow(
                    //the catalogue stores English; only the display translates
                    title: catalogueLabel(text, title),
                    //Bio has no picks to count and the placeholder groups have
                    //nothing to pick yet, so only the tag groups show a number
                    count: title == kGroupBio ? 0 : _pickCount(title),
                    onTap: () => _openGroup(title),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//One row of the category list: title, an optional count of what is picked, and
//a chevron.
class _CategoryRow extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(title, style: theme.textTheme.titleMedium),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Text('$count', style: theme.textTheme.bodyMedium),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
