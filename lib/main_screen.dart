//the 4 main pages (home, likes, messages and profile) get build on top of mainScreen
//mainscreen makes it easier to handle the bottom nav bar by making it custom

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/main.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/pages/main_pages/dm_page.dart';
import 'package:foitifinder/pages/main_pages/profile_page.dart';
import 'package:foitifinder/pages/main_pages/likes_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  final String uid;
  const MainScreen({super.key, required this.uid});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  //list to hold where the user went so back button doesnt close the app
  final List<int> _navigationHistory = [0];

  final List<Widget> _pages = [
    const MyHomePage(),
    const LikesPage(),
    const DMPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    //after build has finished cache the users pfp so it loads faster 
    //and grab data from the database
    //if database data different from disk data change disk else leave as is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheProfileImage();
      _runBgTasks();
    });
  }

  Future<void> _runBgTasks() async {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);

    settingsProv.fetchSettingsFromApi(widget.uid);
    profileProv.fetchUserFromApi(widget.uid);

    if (mounted) {
      final user = profileProv.currentUser;

      //the stream builder grabs a firebase user from local phone cache so the user could be deleted
      //but still login
      //If database says user is null then the user has been deleted or banned and so we sign out
      if(user == null) {
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  void _precacheProfileImage() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if(profileProvider.tempProfileImage != null) {
      precacheImage(FileImage(profileProvider.tempProfileImage!), context);
    }
  }

  //switching tabs
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _navigationHistory.remove(index);
      _navigationHistory.add(index);
    });
  }

  Widget _buildNavItem(int index, String iconPath, String label) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isSelected ? -6.0 : 0.0, 0),
        
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath,
              width: 28,
              height: 28,
              color: isSelected ? kBrandPurple : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark 
                ? (isSelected ? Colors.white : Colors.grey[600]) 
                : (isSelected ? Colors.grey[900] : Colors.grey[600])
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0 && _navigationHistory.length == 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _navigationHistory.removeLast();
          _selectedIndex = _navigationHistory.last;
        });
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 70,
            color: Colors.transparent,
          
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _buildNavItem(0, 'assets/icons/home_page.png', 'Home')),
                  Expanded(child: _buildNavItem(1, 'assets/icons/like.png', 'Likes')),
                  Expanded(child: _buildNavItem(2, 'assets/icons/comment.png', 'Chat')),
                  Expanded(child: _buildNavItem(3, 'assets/icons/user.png', 'Profile')),
                ],
              ),
          ),
        ),
      ),
    );
  }
}
