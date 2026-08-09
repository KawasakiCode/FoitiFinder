//the 4 main pages (home, likes, messages and profile) get build on top of mainScreen
//mainscreen makes it easier to handle the bottom nav bar by making it custom

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/pages/main_pages/dm_page.dart';
import 'package:foitifinder/pages/main_pages/profile_page.dart';
import 'package:foitifinder/pages/main_pages/likes_page.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainScreen extends StatefulWidget {
  final String uid;
  const MainScreen({super.key, required this.uid});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<LikesPageState> _likesPageKey = GlobalKey<LikesPageState>();
  final GlobalKey<DMPageState> _dmPageKey = GlobalKey<DMPageState>();

  //drives the swipeable PageView; kept in sync with the bottom nav bar
  final PageController _pageController = PageController();

  //measures the home swipe-card region so we can block page-swiping only over
  //the card (plus a small margin); the rest of home stays swipeable
  final GlobalKey _homeCardAreaKey = GlobalKey();
  //true = page-swipe is currently blocked (a touch landed on the card)
  bool _lockHomeSwipe = true;
  static const double _cardSwipeMargin = 12; // extra no-swipe px above/below card

  //On every touch, if we're on the home page, decide whether the press landed
  //on the card region (then block page-swipe so the deck owns the drag) or
  //elsewhere (then allow page-swipe).
  void _handleHomePointerDown(PointerDownEvent event) {
    if (_selectedIndex != 0) return;

    bool onCard = true; // default to locked if we can't measure yet (card-safe)
    final RenderObject? obj = _homeCardAreaKey.currentContext?.findRenderObject();
    if (obj is RenderBox && obj.hasSize) {
      final double top = obj.localToGlobal(Offset.zero).dy;
      final double bottom = top + obj.size.height;
      final double y = event.position.dy;
      onCard = y >= (top - _cardSwipeMargin) && y <= (bottom + _cardSwipeMargin);
    }

    if (onCard != _lockHomeSwipe) {
      setState(() => _lockHomeSwipe = onCard);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _updateFcmToken();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'new_like') {
        _likesPageKey.currentState?.loadLikes();
      }
      else if (message.data['type'] == 'new_match') {
        _dmPageKey.currentState?.loadDMs();
      }
    });

    //after build has finished cache the users pfp so it loads faster 
    //and grab data from the database
    //if database data different from disk data change disk else leave as is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheProfileImage();
      _runBgTasks();
    });
  }

  //Function to store the fcm token in the firebase firestore database
  //so python backend can grab it and send notifications to users
  void _updateFcmToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (user != null) {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {  
        await FirebaseFirestore.instance  
          .collection('users')
          .doc(user.uid)
          .set({  
            'fcm_token': token,
            'last_active': FieldValue.serverTimestamp(),
            'like_notifications': settings.likeNotificationsEnabled,
            'message_notifications': settings.messageNotificationsEnabled
          }, SetOptions(merge: true));
      }
    }
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

  //bottom nav tap -> slide the PageView there (onPageChanged syncs the index)
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  //fired when the page settles (from a swipe OR a nav tap) -> sync the nav bar
  void _onPageChanged(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
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
              color: isSelected ? AppColors.primary : Colors.grey[600]
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
    final List<Widget> pages = [
      MyHomePage(cardAreaKey: _homeCardAreaKey),
      LikesPage(key: _likesPageKey),
      DMPage(key: _dmPageKey),
      const ProfilePage(),
    ];

    return PopScope(
      //on home a back press exits; on any other tab it returns to home first
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      },
      child: Scaffold(
        //Listener (passive, doesn't claim gestures) lets us see where each touch
        //lands so we can block page-swiping only over the home card.
        body: Listener(
          onPointerDown: _handleHomePointerDown,
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            //home: block swiping only when the touch landed on the card region
            //(_lockHomeSwipe); the rest of home and the other pages stay swipeable
            physics: (_selectedIndex == 0 && _lockHomeSwipe)
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            children:
                pages.map((page) => _KeepAlivePage(child: page)).toList(),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 70,
            decoration: BoxDecoration(  
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBackground
                  : AppColors.lightSurface,
              border: Border(  
                top: BorderSide(  
                  color: Theme.of(context).brightness == Brightness.dark  
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
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

//Keeps a PageView child alive when it's scrolled off-screen, so the 4 tabs
//preserve their state (like the swipe deck) just like the old IndexedStack did.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
