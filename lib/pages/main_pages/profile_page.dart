import 'package:flutter/material.dart';
import 'package:foitifinder/pages/settings/settings.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'dart:io';
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
                  onTap: () {
                    profileProvider.pickAndSaveImage();},
                  child: CircleAvatar(  
                    radius: 40,
                    backgroundColor: Colors.grey[500],
                    backgroundImage: profileProvider.profileImage != null 
                    ? ResizeImage(FileImage(profileProvider.profileImage!), width: 300) as ImageProvider
                    : AssetImage('assets/images/default_avatar.png'),
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
                        "Username, ",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Age",
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
                        onPressed: () {},
                      ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
