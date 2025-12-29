import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/dummy_user_data.dart';
import 'package:foitifinder/pages/extra_pages/edit_profile.dart';
import 'package:foitifinder/pages/settings/settings.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final text = AppLocalizations.of(context)!;
    ImageProvider backgroundImage;

    //first check if pfp is stored locally
    if(profileProvider.tempProfileImage != null) {
      backgroundImage = ResizeImage(FileImage(profileProvider.tempProfileImage!), width: 300);
    }
    //if not locally grab it from the cloud
    else if(profileProvider.currentUser?.imageUrl != null && profileProvider.currentUser!.imageUrl!.isNotEmpty) {
      backgroundImage = CachedNetworkImageProvider(profileProvider.currentUser!.imageUrl!);
    }
    //else show default pfp
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
          //main row (pfp, username, age)
          Row(
            children: [
              //pfp
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 15, 15),
                child: GestureDetector(
                  onTap: () async {
                    await profileProvider.updateProfilePicture();
                  },
                  child: CircleAvatar(  
                    radius: 40,
                    backgroundColor: Colors.grey[500],
                    backgroundImage: backgroundImage,
                  ),
                ),
              ),
              //username, age, edit profile button
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
                        : "",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: FloatingActionButton.extended(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        label: Text(
                          text.editProfile,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(  
                            context,
                            MaterialPageRoute(builder:(context) => EditProfile(),)
                          );
                        },
                      ),
                  ),
                ],
              ),
            ],
          ),
          FloatingActionButton(
            onPressed: () async {
              await DummyDataService().generateDummyUsers(15);
            }
          )
        ],
      ),
    );
  }
}
