import 'package:flutter/material.dart';
import 'package:foitifinder/main.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/pages/main_pages/search_page.dart';
import 'package:foitifinder/pages/main_pages/dm_page.dart';
import 'package:foitifinder/pages/main_pages/profile_page.dart';
import 'package:foitifinder/pages/main_pages/likes_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  //list to hold where the user went so back button doesnt close the app
  final List<int> _navigationHistory = [0];

  //list that holds the 5 main pages loaded to memory
  final List<Widget> _pages = [
    const MyHomePage(),
    const SearchPage(),
    const LikesPage(),
    const DMPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheProfileImage();
    });
  }

  void _precacheProfileImage() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    if(profileProvider.profileImage != null) {
      precacheImage(FileImage(profileProvider.profileImage!), context);
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
      behavior: HitTestBehavior.opaque, // Ensures clicks work even on empty space
      
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // If selected, move UP by 6 pixels. If not, stay at 0.
        transform: Matrix4.translationValues(0, isSelected ? -6.0 : 0.0, 0),
        
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hug content
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconPath,
              width: 28,
              height: 28,
              color: isSelected ? kBrandPurple : Colors.grey[600],
            ),
            const SizedBox(height: 4), // Gap
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[600],
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
      //allow back button to close the app from home page with empty history
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
                  Expanded(child: _buildNavItem(1, 'assets/icons/search.png', 'Search')),
                  Expanded(child: _buildNavItem(2, 'assets/icons/like.png', 'Likes')),
                  Expanded(child: _buildNavItem(3, 'assets/icons/comment.png', 'Chat')),
                  Expanded(child: _buildNavItem(4, 'assets/icons/user.png', 'Profile')),
                ],
              ),
          ),
        ),
      ),
    );
  }
}
