import 'package:flutter/material.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/pages/main_pages/search_page.dart';
import 'package:foitifinder/pages/main_pages/dm_page.dart'; // Make sure you have this or a placeholder
import 'package:foitifinder/pages/main_pages/profile_page.dart';
import 'package:foitifinder/pages/main_pages/likes_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>{
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

  //switching tabs
  void _onItemTapped(int index) {
    if(_selectedIndex == index)return;

    setState(() {
      _selectedIndex = index;
      _navigationHistory.remove(index);
      _navigationHistory.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(  
      //allow back button to close the app from home page with empty history
      canPop: _selectedIndex == 0 && _navigationHistory.length == 1,
      onPopInvokedWithResult: (didPop, result) {
        if(didPop)return;

        setState(() {
          _navigationHistory.removeLast();
          _selectedIndex = _navigationHistory.last;
        },);
      },
      child: Scaffold(  
        body: IndexedStack(  
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(  
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.transparent,
          indicatorColor: Colors.transparent,
          destinations: [
            NavigationDestination(
              icon: Image.asset(
                'assets/icons/home_page.png',
                width: 35,
                height: 35,
                key: UniqueKey()),
              label: 'Home'
            ),
            NavigationDestination(
              icon: Image.asset(
                'assets/icons/search.png',
                width: 30,
                height: 30,
                key: UniqueKey()),
              label: 'Explore'
            ),
            NavigationDestination(
              icon: Image.asset(
                'assets/icons/like.png',
                width: 35,
                height: 35,
                key: UniqueKey()),
              label: 'Likes'
            ),
            NavigationDestination(
              icon: Image.asset(
                'assets/icons/comment.png',
                width: 32,
                height: 32,
                key: UniqueKey()),
              label: 'Chat'
            ),
            NavigationDestination(
              icon: Image.asset(
                'assets/icons/user.png',
                width: 30,
                height: 30,
                key: UniqueKey()),
              label: 'Profile'
            ),
          ]
        )
      )
    );
  }
}


