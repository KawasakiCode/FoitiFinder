//the 3 main pages (home, matches and profile) get build on top of mainScreen
//mainscreen makes it easier to handle the bottom nav bar by making it custom

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/pages/main_pages/home_page.dart';
import 'package:foitifinder/pages/main_pages/profile_page.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/pages/main_pages/matches_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/services/error_reporting.dart';
import 'package:foitifinder/widgets/top_banner.dart';
import 'package:foitifinder/providers/notifications_provider.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/swipe_queue.dart';
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which match a tapped push is about, or null if it does not say.
///
/// A FUNCTION OF ITS OWN because the feature hinges on it and its failure is
/// silent: get this wrong and the banner opens the list instead of the match,
/// with nothing in any log to say why. A test can call this; it cannot tap a
/// notification.
///
/// PARSED, NOT CAST. FCM data values are strings over the wire whatever the
/// sender put in, so an int arrives as "57" - and anything unparseable
/// (absent, empty, the literal "None" a careless sender would produce) means
/// "not said" rather than an error, because the tab is still worth opening.
int? matchIdFromPush(Map<String, dynamic> data) =>
    int.tryParse(data['match_id']?.toString() ?? '');

class MainScreen extends StatefulWidget {
  final String uid;
  const MainScreen({super.key, required this.uid});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<MatchesPageState> _matchesPageKey =
      GlobalKey<MatchesPageState>();

  //position of MatchesPage in the PageView built below. A named constant
  //because _onPageChanged compares against it, and a bare 1 there is the kind
  //of thing that quietly starts refreshing the wrong page when a tab is added.
  static const int _kMatchesTab = 1;

  //THE SAME TAP CAN ARRIVE TWICE ON A COLD START. getInitialMessage hands
  //over the message that launched the app, and onMessageOpenedApp streams the
  //same intent alongside it - so the handler ran twice, two identical
  //profiles stacked, and the first back press looked broken because what it
  //revealed was the second one.
  String? _handledPushId;
  bool _openingFromPush = false;

  //drives the swipeable PageView; kept in sync with the bottom nav bar
  final PageController _pageController = PageController();

  //measures the home swipe-card region so we can block page-swiping only over
  //the card (plus a small margin); the rest of home stays swipeable
  final GlobalKey _homeCardAreaKey = GlobalKey();
  //true = page-swipe is currently blocked (a touch landed on the card)
  bool _lockHomeSwipe = true;
  static const double _cardSwipeMargin =
      12; // extra no-swipe px above/below card

  //On every touch, if we're on the home page, decide whether the press landed
  //on the card region (then block page-swipe so the deck owns the drag) or
  //elsewhere (then allow page-swipe).
  void _handleHomePointerDown(PointerDownEvent event) {
    if (_selectedIndex != 0) return;

    bool onCard = true; // default to locked if we can't measure yet (card-safe)
    final RenderObject? obj = _homeCardAreaKey.currentContext
        ?.findRenderObject();
    if (obj is RenderBox && obj.hasSize) {
      final double top = obj.localToGlobal(Offset.zero).dy;
      final double bottom = top + obj.size.height;
      final double y = event.position.dy;
      onCard =
          y >= (top - _cardSwipeMargin) && y <= (bottom + _cardSwipeMargin);
    }

    if (onCard != _lockHomeSwipe) {
      setState(() => _lockHomeSwipe = onCard);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  //RESUME IS THE OTHER MOMENT WORTH TRYING. Coming back to the app is the
  //most likely time for a phone to have regained signal since the swipe that
  //failed, and it costs nothing when the queue is empty.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      SwipeQueue.instance.flush(uid: widget.uid);
      _notificationsProvider.load();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _updateFcmToken();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      //ANYTHING ABOUT A MATCH REFRESHES THE MATCHES PAGE, whatever the kind.
      //The push is only a nudge now: nothing about a match is stored in the
      //bell any more, so this list IS the delivery, and it is reloaded here so
      //the page is already right if the user opens it from the banner.
      //
      //NOTHING ELSE ARRIVES. 'match' and 'match_revealed' are the only two
      //pushes the backend sends - a like push existed while there was a
      //likes page to open it, and there is nothing left for one to refresh.
      final kind = message.data['type'] as String?;
      if (kind != null && kind.startsWith('match')) {
        _matchesPageKey.currentState?.loadMatches();

        //AND SAY SO, because nothing else will. Android does not draw a
        //system banner while the app is in the foreground, so refreshing the
        //list on its own meant a match being revealed changed a row on a page
        //the user was not looking at - invisible unless they went and counted.
        //
        //The same tap target as the real banner: it opens that match.
        if (mounted) {
          showTopBanner(
            context,
            message: _bannerTextFor(kind),
            onTap: () => _openFromNotification(message),
          );
        }
      }
    });

    //TAPPED WHILE THE APP WAS MERELY IN THE BACKGROUND. The system drew the
    //banner, nothing in this isolate ran, and the tap brings the app forward
    //with the message in hand.
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromNotification);

    //after build has finished cache the users pfp so it loads faster
    //and grab data from the database
    //if database data different from disk data change disk else leave as is
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheProfileImage();
      _runBgTasks();

      //TAPPED WHILE THE APP WAS SHUT, which is a different question with a
      //different answer: there was no listener to receive it, so the message
      //is waiting to be asked for instead. Firebase hands it over exactly
      //once, so this cannot double up with onMessageOpenedApp above.
      //
      //AFTER THE FIRST FRAME, because opening a match needs the matches page
      //to exist - its GlobalKey has no state attached until the PageView has
      //built it.
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _openFromNotification(message);
      });
    });
  }

  //Take a tapped notification to the match it is about.
  //
  //NO BACKGROUND HANDLER ACCOMPANIES THIS. onBackgroundMessage exists to run
  //Dart while the app is not, and the only thing wanted here is navigation,
  //which cannot happen then anyway - these are notification messages, so the
  //system draws the banner without any code of ours running.
  //
  //THE KIND IS NOT CONSULTED. 'match' and 'match_revealed' are about the same
  //match and open the same screen; the difference is what the action bar
  //shows once it is there, which it reads from the server rather than from
  //the banner that brought the user in.
  //WHAT THE IN-APP BANNER SAYS, translated here rather than taken from
  //message.notification. The server builds that text in English only, and
  //the app has both languages - so a Greek user reading a Greek app would
  //get an English line for no reason other than where the string was built.
  //
  //AS VAGUE AS THE PUSH ABOUT WHO. Not for privacy, since this one is only
  //ever on screen for somebody already signed in - the payload simply does
  //not carry a name, and the match page is one tap away with all of them.
  String _bannerTextFor(String kind) {
    final text = AppLocalizations.of(context)!;
    return kind == 'match_revealed'
        ? text.bannerMatchRevealed
        : text.bannerMatch;
  }

  //The guarded entry point. Every delivery route goes through here.
  Future<void> _openFromNotification(RemoteMessage message) async {
    if (_openingFromPush) return;
    //messageId IS THE DEDUPE KEY. _openingFromPush covers the window before
    //one is known - the two deliveries land milliseconds apart, well inside
    //the request made below before anything appears on screen.
    final pushId = message.messageId;
    if (pushId != null && pushId == _handledPushId) return;
    _openingFromPush = true;
    _handledPushId = pushId;
    try {
      await _takeTapToItsMatch(message);
    } finally {
      _openingFromPush = false;
    }
  }

  Future<void> _takeTapToItsMatch(RemoteMessage message) async {
    //DATA VALUES ARE STRINGS over the wire, so this is parsed rather than
    //cast - and a payload without a usable id still opens the tab, which is
    //better than the tap appearing to do nothing.
    final matchId = matchIdFromPush(message.data);

    //THE MATCH IS FETCHED BEFORE ANYTHING MOVES, which is what makes this
    //land on the profile rather than travel to it. Switching tabs first meant
    //the user watched the app launch, slide to the matches page, wait on a
    //request and only then animate a profile in - three transitions replaying
    //a journey they never made. The request happens while the app is still
    //showing whatever it opened on, and by the time anything changes there is
    //a profile ready to put there.
    MatchModel? match;
    if (matchId != null) {
      try {
        final matches = await ApiService.getMatches(
          uid: FirebaseAuth.instance.currentUser!.uid,
        );
        match = matches
            .where((candidate) => candidate.matchId == matchId)
            .firstOrNull;
      } catch (error, stack) {
        //A FAILED LOAD LANDS THE USER ON THE LIST, which is a fine outcome
        //and a terrible silence: the tap looks like it half worked and there
        //is nothing anywhere saying the request failed. reportError is
        //stripped from release builds the same way debugPrint is.
        reportError(error,
            stack: stack, context: 'opening a match from a push');
      }
    }
    if (!mounted) return;

    //JUMPED, NOT SLID. The slide is for somebody choosing a tab; arriving
    //here was decided by tapping a banner, and animating it only delays the
    //thing they asked for.
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_kMatchesTab);
    }
    if (_selectedIndex != _kMatchesTab) {
      setState(() => _selectedIndex = _kMatchesTab);
    }

    //GONE IS A NORMAL OUTCOME, not an error. Between the push being sent and
    //the banner being tapped, the other side can decline, either side can
    //remove it, and a match left unanswered for three days expires. Landing
    //on the list is then the honest answer: the notification was true when it
    //was sent, and the page says what is true now.
    if (match == null) {
      _matchesPageKey.currentState?.loadMatches();
      return;
    }

    final page = await _matchesPageWhenBuilt();
    if (page == null) return;
    //RELEASED BEFORE THE PROFILE OPENS. openMatch does not return until the
    //user backs out of it, and holding the guard that long would make a
    //genuine second notification unanswerable.
    _openingFromPush = false;
    await page.openMatch(match);
  }

  //Wait for the matches page to exist, for as long as that is reasonable.
  //
  //A GlobalKey HAS NO STATE UNTIL THE WIDGET IS BUILT, and on a cold start
  //the PageView may still be building it when a tapped notification is
  //already asking for it. Awaiting the slide above is usually enough; this is
  //what stops a slow frame turning the tap into nothing at all.
  //
  //BOUNDED, because the alternative is waiting forever for a page that is
  //never coming - at which point landing on the tab is the right answer.
  Future<MatchesPageState?> _matchesPageWhenBuilt() async {
    for (var frame = 0; frame < 60; frame++) {
      final state = _matchesPageKey.currentState;
      if (state != null) return state;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
    }
    return null;
  }

  //Function to store the fcm token in the firebase firestore database
  //so python backend can grab it and send notifications to users
  void _updateFcmToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (user != null) {
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcm_token': token,
          'last_active': FieldValue.serverTimestamp(),
          'match_notifications': settings.matchNotificationsEnabled,
        }, SetOptions(merge: true));
      }
    }
  }

  NotificationsProvider get _notificationsProvider =>
      Provider.of<NotificationsProvider>(context, listen: false);

  Future<void> _runBgTasks() async {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);

    settingsProv.fetchSettingsFromApi(widget.uid);
    profileProv.fetchUserFromApi(widget.uid);
    //THE LAUNCH CHECK. A match waiting on this user reaches them here even if
    //the push was never delivered, dismissed, or killed by the OS - which is
    //the whole reason notifications are a table on the server rather than a
    //push and nothing else.
    _notificationsProvider.load();
    //and anything the deck could not deliver last time, now that there is
    //probably a network again
    SwipeQueue.instance.flush(uid: widget.uid);

    if (mounted) {
      final user = profileProv.currentUser;

      //the stream builder grabs a firebase user from local phone cache so the user could be deleted
      //but still login
      //If database says user is null then the user has been deleted or banned and so we sign out
      if (user == null) {
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  void _precacheProfileImage() {
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    if (profileProvider.tempProfileImage != null) {
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

    //OPENING THE TAB IS WHAT REFRESHES IT, and the FCM hook in initState is
    //not enough on its own: the push for a new match goes to the OTHER
    //person. Whoever completed the match by swiping gets nothing - which is
    //why a match made in the deck used to sit invisible here until the list
    //was pulled down by hand.
    //
    //It also covers the paths no push exists for at all: a swipe the retry
    //queue delivered long after the fact, and a match the other side
    //withdrew while this page was built but not looked at.
    //
    //The page keeps its State across tabs (see _KeepAlivePage), so initState
    //runs once per login and cannot be the refresh.
    if (index == _kMatchesTab) {
      _matchesPageKey.currentState?.loadMatches();
    }
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
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? (isSelected ? Colors.white : Colors.grey[600])
                    : (isSelected ? Colors.grey[900] : Colors.grey[600]),
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
      MatchesPage(key: _matchesPageKey),
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
            children: pages.map((page) => _KeepAlivePage(child: page)).toList(),
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
                Expanded(
                  child: _buildNavItem(0, 'assets/icons/home_page.png', 'Home'),
                ),
                Expanded(
                  child: _buildNavItem(1, 'assets/icons/like.png', 'Matches'),
                ),
                Expanded(
                  child: _buildNavItem(2, 'assets/icons/user.png', 'Profile'),
                ),
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
