//The main page of the app where swiping takes place
//Here the deck of cards shows and the user swipes left(pass), right(like), up(super_like) to other users

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/profile_photo.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/models/public_profile.dart';
import 'package:foitifinder/models/match_models.dart';
import 'package:foitifinder/pages/main_pages/match_page.dart';
import 'package:foitifinder/pages/main_pages/profile_detail_page.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/photo_card.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.title = 'FoitiFinder',
    this.automaticallyImplyLeading = false,
    this.cardAreaKey,
  });

  final String title;
  final bool automaticallyImplyLeading;
  //attached to the swipe-card region so the parent (MainScreen) can measure its
  //pixel bounds and disable page-swiping only over the card
  final Key? cardAreaKey;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//How much of the swipe area the card fills. Not the whole screen: the gaps at
//the sides and under it are what make the deck look like a deck.
const double _kCardWidthFactor = 0.86;
const double _kCardHeightFactor = 0.96;

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  AppLocalizations get text => AppLocalizations.of(context)!;

  //The loaded cards are inside this list
  //We use currentIndex to navigate through the list
  //CurrentIndex always shows to the current top card
  List<CardData> cards = [];
  int currentIndex = 0;
  final int maxHistory = 5; //how many rewinds until no more
  final int fetchThreshold =
      10; //when 10 cards remain in the current stack load more
  final int batchSize = 20; // how many cards to load at a time
  bool _isFetching = false;
  bool _hasNoMoreProfiles = false;
  late AnimationController _animationController;
  double _tapPositionY = 0;
  final ValueNotifier<Offset> _swipeNotifier = ValueNotifier(Offset.zero);
  bool _isAnimating = false;
  //guards against a second tap pushing the profile page twice
  bool _openingProfile = false;

  //card creation
  @override
  void initState() {
    super.initState();

    // Initialize sample data
    _fetchMoreCards();
    currentIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // We want to pre-cache photos for the Current User (Index 0) and the Next User (Index 1)
      // Determine how many users to look ahead (max 2)
      int usersToPrecache = cards.length > 2 ? 2 : cards.length;

      for (int i = 0; i < usersToPrecache; i++) {
        final card = cards[i];

        // 1. Pre-cache the main list of photos.
        //
        //profilePhotoProvider, NOT NetworkImage: a bare NetworkImage keys a
        //different cache entry AND bypasses the disk cache, so this used to
        //download every photo a second time and warm an entry no widget here
        //ever asks for.
        if (card.photos.isNotEmpty) {
          for (String url in card.photos) {
            precacheImage(profilePhotoProvider(url), context);
          }
        }
      }
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  //dispose function
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  //gesture detector functions
  void _onPanUpdate(DragUpdateDetails details) {
    _swipeNotifier.value += details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final offset = _swipeNotifier.value;

    //get how fast user dragged
    final velocity = details.velocity.pixelsPerSecond.dx;

    //Distance and speed thresholds for activating swipe left or right
    final distanceThreshold = screenWidth * 0.2;
    final verticalThreshold = screenHeight * 0.15;
    final velocityThreshold = 1000.0;

    //when to swipe left, right, up or reset
    bool isSwipeRight = offset.dx > distanceThreshold;
    bool isFlickRight = velocity > velocityThreshold && offset.dx > 0;
    bool isSwipeLeft = offset.dx < -distanceThreshold;
    bool isFlickLeft = velocity < -velocityThreshold && offset.dx < 0;
    bool isSwipeUp = offset.dy.abs() > offset.dx.abs();

    if (isSwipeUp && offset.dy < -verticalThreshold) {
      _swipeUp();
      return;
    }

    if (!isSwipeUp && (isSwipeRight || isFlickRight)) {
      _swipeRight();
    } else if (isSwipeLeft || isFlickLeft) {
      _swipeLeft();
    } else {
      _resetCard();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _tapPositionY = details.localPosition.dy;
  }

  //cache image
  void _precacheNextImage() {
    if (currentIndex + 1 < cards.length) {
      _precacheUserPhotos(cards[currentIndex + 1]);
    }

    //Precache the card after that (Buffer)
    if (currentIndex + 2 < cards.length) {
      _precacheUserPhotos(cards[currentIndex + 2]);
    }
  }

  void _precacheUserPhotos(CardData card) {
    if (card.photos.isNotEmpty) {
      for (int i = 0; i < card.photos.length; i++) {
        // OPTIMIZATION: Only cache the first 3 photos.
        // If the user taps past photo #3, Flutter will load #4 on demand.
        // This prevents the "Swipe Stutter" caused by downloading too much at once.
        if (i > 2) break;

        precacheImage(profilePhotoProvider(card.photos[i]), context);
      }
    }
  }

  //swiping functions
  //These are shared by the gestures AND the action buttons so a swipe is always
  //registered with the backend no matter how it was triggered.
  void _swipeRight({bool fromButton = false}) async {
    //capture the card before the animation advances currentIndex
    final card = cards[currentIndex];
    //animate first, register after: the card must never wait on the network
    _animateCardOut(1.0, card.name, true, fromButton: fromButton);
    SwipeResult result = SwipeResult.none;
    try {
      result = await ApiService.registerSwipe(
        FirebaseAuth.instance.currentUser!.uid,
        card.id,
        "like",
      );
    } catch (_) {}

    await _openMatch(card, result);
  }
  //A match opens the match page, not a dialog.
  //
  //The old dialog said "it's a match" and left: nothing was exchanged and
  //there was nothing to do. The page is where this side answers for the match
  //it just created - see match_page.dart - so a match that cannot be opened
  //(an older backend sending no match_id) is better left alone than announced
  //with no way to act on it.
  Future<void> _openMatch(CardData card, SwipeResult result) async {
    final matchId = result.matchId;
    if (!result.isMatch || matchId == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchPage(
          matchId: matchId,
          otherUserId: card.id,
          otherName: card.name,
          otherAge: card.age,
          otherPhotoUrl: card.photos.isEmpty ? null : card.photos.first,
        ),
      ),
    );
  }


  void _swipeLeft({bool fromButton = false}) async {
    final card = cards[currentIndex];
    //animate immediately so the X button / left swipe never gets stuck on a
    //slow or failing backend call, then register the pass in the background
    _animateCardOut(-1.0, card.name, false, fromButton: fromButton);
    try {
      await ApiService.registerSwipe(
        FirebaseAuth.instance.currentUser!.uid,
        card.id,
        "pass",
      );
    } catch (_) {}
  }

  void _swipeUp({bool fromButton = false}) async {
    final card = cards[currentIndex];
    _animateCardOut(
      0.0,
      card.name,
      true,
      fromButton: fromButton,
      isSuperLike: true,
    );
    SwipeResult result = SwipeResult.none;
    try {
      result = await ApiService.registerSwipe(
        FirebaseAuth.instance.currentUser!.uid,
        card.id,
        "super_like",
      );
    } catch (_) {}

    await _openMatch(card, result);
  }

  //This function handles the swiping animation
  //We use a flag _isAnimating to prevent an animation to begin whilst one is already running
  //The end offset of the animation is set off screen so the card doesnt show at all
  //This function also updates the currentIndex so if more than 5 cards have been swiped
  //then delete the first of the 5 because rewind goes up to 5 back
  //Also if less than 10 cards remain in the deck call function to make more

  void _animateCardOut(
    double direction,
    String cardName,
    bool isLike, {
    bool fromButton = false,
    bool isSuperLike = false,
  }) {
    if (_isAnimating) return;
    _isAnimating = true;

    if (fromButton) {
      _tapPositionY = 0.0;
    }

    final startOffset = _swipeNotifier.value;
    Offset endOffset;

    if (isSuperLike) {
      endOffset = Offset(0, -MediaQuery.of(context).size.height);
    } else {
      endOffset = Offset(
        MediaQuery.of(context).size.width * 1.5 * direction,
        0,
      );
    }

    final animation = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    void listener() {
      _swipeNotifier.value = animation.value;
    }

    _animationController.addListener(listener);
    _animationController.forward().then((_) {
      _animationController.removeListener(listener);

      setState(() {
        currentIndex++;
        _swipeNotifier.value = Offset.zero;

        if (currentIndex > maxHistory) {
          cards.removeAt(0);
          currentIndex--;
        }

        int remainingCards = cards.length - currentIndex;
        if (remainingCards <= fetchThreshold) {
          _fetchMoreCards();
        }
      });
      _precacheNextImage();
      _animationController.reset();
      _isAnimating = false;
    });
  }

  //Reset card animation
  //This animation takes the card from wherever it is and sends it to the center where it started
  void _resetCard() {
    if (_isAnimating) return;
    _isAnimating = true;

    final startOffset = _swipeNotifier.value;

    final animation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    void listener() {
      _swipeNotifier.value = animation.value;
    }

    _animationController.addListener(listener);
    _animationController.forward().then((_) {
      _animationController.removeListener(listener);
      _animationController.reset();
    });

    setState(() {
      _swipeNotifier.value = Offset.zero;
    });
    _isAnimating = false;
  }

  //REWIND IS GONE FROM THE UI. The card now carries exactly three buttons -
  //pass, super like, like - so there is nowhere to put it. The state it needed
  //is still here (currentIndex only moves forward, and maxHistory keeps the
  //last few cards in the list), so bringing it back is a button, not a rebuild.

  //This function is responsible for grabbing more cards from the database if less
  //than 10 remain in the active deck
  Future<void> _fetchMoreCards() async {
    //if the user swipes fast this prevents multiple function calls
    if (_isFetching || _hasNoMoreProfiles) return;
    _isFetching = true;

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      List<CardData> users = await ApiService.getMultipleUsers(uid);
      if (users.isEmpty) {
        _hasNoMoreProfiles = true;
        _isFetching = false;
        return;
      }
      if (mounted) {
        setState(() {
          cards.addAll(users);
        });
      }
    } catch (e) {
      setState(() => _isFetching = false);
    }
    _isFetching = false;
  }

  //Main build (UI here)
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 2,
          automaticallyImplyLeading: widget.automaticallyImplyLeading,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Text(widget.title),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            //room between the app bar and the card
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: FractionallySizedBox(
                  //the card leaves the sides of the screen visible, so the deck
                  //reads as a stack of objects rather than as the page itself
                  widthFactor: _kCardWidthFactor,
                  heightFactor: _kCardHeightFactor,
                  child: KeyedSubtree(
                    key: widget.cardAreaKey,
                    child: cards.isNotEmpty && currentIndex < cards.length
                        ? _buildSwipeCards()
                        : _buildNoMoreCards(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  //build cards function
  Widget _buildSwipeCards() {
    return ValueListenableBuilder<Offset>(
      valueListenable: _swipeNotifier,
      builder: (context, offset, child) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double screenHeight = MediaQuery.of(context).size.height;
        final double centerPoint = screenHeight / 3;

        //Offset and ratio for animations
        //The bgRatio is used to ensure that card behind the top one grows as the user swipes the top one
        //so when the top one reaches a certain point in the screen the card behind has already taken its place
        final double dragDistance = offset.dx.abs();
        final double ratio = (dragDistance / screenWidth).clamp(0.0, 1.0);
        final double bgRatio = (ratio * 5.0).clamp(0.0, 1.0);

        //rotation direction is used to give direction to the card
        //if the user grabs the card from the top the card swipes clockwise
        //if the user grabs the card from the bottom the card swipes counterclockwise
        final double rotationDirection = _tapPositionY > centerPoint
            ? -1.0
            : 1.0;
        //angle is used to alter how aggresively the card will turn during its animation
        //low angle is recommended for a smooth feel
        final double angle = (offset.dx * 0.001) * rotationDirection;

        return Stack(
          children: [
            // Background cards (stacked behind)
            for (
              int i = currentIndex + 1;
              i < cards.length && i < currentIndex + 2;
              i++
            ) ...[
              Positioned(
                key: ValueKey(cards[i].id),
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Transform.scale(
                  scale:
                      //0.05 makes each subsequent card 5% smaller than the previous so
                      //card 1 100% scale, card 2 95%, card 3 90% etc...
                      //bgRatio makes card 2 grow bigger as card one gets swiped off the screen
                      (1.0 - (((i - currentIndex)) * 0.05)) + (bgRatio * 0.05),
                  child: _buildCard(cards[i], false),
                ),
              ),
            ],
            // Current card (top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (_isAnimating) return;
                  _onPanUpdate(details);
                },
                onPanEnd: (details) {
                  if (_isAnimating) return;
                  _onPanEnd(details);
                },
                onPanStart: _onPanStart,
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _swipeNotifier,
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: angle,
                        child: _buildCard(cards[currentIndex], true),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  //build top card
  Widget _buildCard(CardData card, bool isTop) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Stack(
          children: [
            //only the top card's buttons do anything: the ones behind are a
            //preview, and a tap through to them would swipe the wrong person
            PhotoCard(
              card: card,
              //only the top card flies, so no two Heroes ever share a tag
              photoHeroTag: isTop ? _cardPhotoHeroTag(card) : null,
              actionsHeroTag: isTop ? _cardActionsHeroTag(card) : null,
              onOpen: isTop ? () => _openProfile(card) : null,
              onPass: isTop ? () => _swipeLeft(fromButton: true) : null,
              onSuperLike: isTop ? () => _swipeUp(fromButton: true) : null,
              onLike: isTop ? () => _swipeRight(fromButton: true) : null,
            ),

            // Swipe indicators (only on top card)
            if (isTop) ...[
              // Like indicator (right swipe)
              if (_swipeNotifier.value.dx > 50 &&
                  _swipeNotifier.value.dx.abs() > _swipeNotifier.value.dy.abs())
                Positioned(
                  top: 60,
                  left: 60,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.likeGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 120,
                      ),
                    ),
                  ),
                ),

              // Pass indicator (left swipe)
              if (_swipeNotifier.value.dx < -50 &&
                  _swipeNotifier.value.dx.abs() > _swipeNotifier.value.dy.abs())
                Positioned(
                  top: 60,
                  right: 60,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.passGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 120,
                      ),
                    ),
                  ),
                ),

              // Super like indicator (up swippe)
              if (_swipeNotifier.value.dy < -50 &&
                  _swipeNotifier.value.dy.abs() > _swipeNotifier.value.dx.abs())
                Positioned(
                  top: 200,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: 0,
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.superLikeGradient.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 120,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  //When cards run out show this function
  Widget _buildNoMoreCards() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            text.noMoreProfiles,
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            text.checkLater,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  //Keyed by the PROFILE, not by position: the deck shifts under the page while
  //it is open, and the photo still has to know which card to fly back to.
  Object _cardPhotoHeroTag(CardData card) => 'card-photo-${card.id}';
  //a second flight, for the three buttons travelling down into the page's bar
  Object _cardActionsHeroTag(CardData card) => 'card-actions-${card.id}';

  //Open the whole profile, and act on what comes back.
  //
  //THE PAGE POPS A DECISION, it does not swipe by itself: the deck owns the
  //animation, the index and the backend call, so a like from in there is the
  //same code path as a like from the card.
  Future<void> _openProfile(CardData card) async {
    if (_openingProfile) return;
    //no setState: nothing on the deck changes. The pills now fade as part of
    //the flight itself (deckPhotoHeroFlightShuttle), so there is nothing to
    //wait for and the photo lifts the instant the card is tapped.
    _openingProfile = true;

    final decision = await Navigator.push<ProfileDecision>(
      context,
      profileDetailRoute(
        userId: card.id,
        photoHeroTag: _cardPhotoHeroTag(card),
        actionsHeroTag: _cardActionsHeroTag(card),
        //what the deck already knows, so the page opens with a face and a
        //name instead of a spinner
        preview: PublicProfile(
          id: card.id,
          name: card.name,
          age: card.age,
          bio: card.bio,
          job: card.job,
          photos: [for (final url in card.photos) ProfilePhoto(url: url)],
        ),
      ),
    );
    _openingProfile = false;
    if (!mounted || decision == null) return;

    switch (decision) {
      case ProfileDecision.pass:
        _swipeLeft(fromButton: true);
      case ProfileDecision.superLike:
        _swipeUp(fromButton: true);
      case ProfileDecision.like:
        _swipeRight(fromButton: true);
    }
  }
}
