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
import 'package:foitifinder/providers/settings_providers.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/services/swipe_queue.dart';
import 'package:foitifinder/theme/app_colors.dart';
import 'package:foitifinder/widgets/main_app_bar.dart';
import 'package:foitifinder/widgets/photo_card.dart';
import 'package:provider/provider.dart';

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
  //How many fetches in a row came back with nobody the deck did not already
  //hold. See _fetchMoreCards: one such answer proves nothing, a run of them
  //means the pool really is exhausted. Reset as soon as anyone new arrives.
  int _fetchesWithNothingNew = 0;
  static const int _kGiveUpAfterEmptyFetches = 3;
  //WHICH DECK A REPLY BELONGS TO. Changing a filter throws the deck away and
  //asks again, but a request already in flight answers with people chosen
  //under the OLD criteria - and appending those to the cleared deck would put
  //19-year-olds back in front of somebody who just asked for 25-30. A reply
  //whose generation no longer matches is dropped on arrival.
  int _deckGeneration = 0;
  //The filters as they were when this deck was built. The feed applies
  //preferred_gender and the age range as HARD filters, so changing either one
  //means the cards on screen are answers to a question nobody is asking any
  //more. Height and the rest are stored but not yet used by the query, so
  //they are deliberately not in here - rebuilding the deck for them would
  //throw away cards for nothing.
  String? _filterSignature;
  //SUPER LIKES ARE SCARCE, AND THE DECK HAS TO KNOW BEFORE THE GESTURE. A
  //card animates away first and registers after, so a refusal from the server
  //lands when the card is already gone. Starts at zero rather than at two:
  //until the server has answered, the honest state is "not sure", and
  //refusing is recoverable while spending one the user does not have is not.
  int _superLikesLeft = 0;
  late AnimationController _animationController;
  double _tapPositionY = 0;
  final ValueNotifier<Offset> _swipeNotifier = ValueNotifier(Offset.zero);
  bool _isAnimating = false;
  //guards against a second tap pushing the profile page twice
  bool _openingProfile = false;

  //SUBSCRIBED TO DIRECTLY rather than watched in build, because a filter
  //change is an EVENT here, not a different way to draw the same deck - it
  //has to discard cards and re-ask the server, which is not something build
  //is allowed to do. read() in initState is the supported way to reach a
  //provider without creating a dependency.
  late final SettingsProvider _settings = context.read<SettingsProvider>();

  //card creation
  @override
  void initState() {
    super.initState();

    // Initialize sample data
    _filterSignature = _signatureOf(_settings);
    _settings.addListener(_onSettingsChanged);
    _fetchMoreCards();
    _loadSuperLikesLeft();
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
    _settings.removeListener(_onSettingsChanged);
    _animationController.dispose();
    super.dispose();
  }

  //The two filters the feed query actually applies, as one comparable string.
  //Sorted, because a Set has no order and 'Men,Women' must not read as a
  //change from 'Women,Men'.
  String _signatureOf(SettingsProvider settings) {
    final genders = settings.preferredGender.toList()..sort();
    return '${genders.join(",")}'
        '|${settings.ageRange.start.round()}'
        '|${settings.ageRange.end.round()}';
  }

  //SettingsProvider notifies for everything it holds - theme, locale, push
  //toggles - so this fires far more often than the deck cares about. The
  //signature is what makes it cheap: anything that is not a feed filter
  //compares equal and stops here.
  void _onSettingsChanged() {
    final signature = _signatureOf(_settings);
    if (signature == _filterSignature) return;
    _filterSignature = signature;
    _resetDeck();
  }

  //START THE DECK OVER, because the people in it no longer answer the
  //question that was asked.
  //
  //_hasNoMoreProfiles IS THE WHOLE REASON THIS EXISTS. It was a one-way
  //latch: a feed that came back empty set it for the lifetime of this State,
  //and nothing ever cleared it. Open the app with an 18-19 range, get an
  //empty deck, widen it to 20-28, and the latch was already closed - so the
  //only way back was to kill the app. Worse, with an empty deck there is no
  //card left to swipe, and a swipe is what used to trigger the only refetch.
  void _resetDeck() {
    //a reply from the old deck is now meaningless, and _fetchMoreCards below
    //cannot start while the flag it sets is still raised
    _deckGeneration++;
    _isFetching = false;

    setState(() {
      cards = [];
      currentIndex = 0;
      _hasNoMoreProfiles = false;
      _fetchesWithNothingNew = 0;
      _swipeNotifier.value = Offset.zero;
    });
    _fetchMoreCards();
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
    //THROUGH THE QUEUE, NEVER ApiService DIRECTLY. The card has already left
    //the screen, so a failure here has nothing to put back - the swipe is
    //retried and then parked on disk instead of being dropped on the floor.
    final result = await SwipeQueue.instance.send(
      uid: FirebaseAuth.instance.currentUser!.uid,
      targetId: card.id,
      action: "like",
    );

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
    //MATCH ID, NOT isMatch. `isMatch` is only true the first time the server
    //sees the swipe; a retry re-finds the same match and reports false with
    //the id still set. Keying off the id covers both, and a queued swipe that
    //never got a reply leaves the bell as the way in.
    final matchId = result.matchId;
    if (matchId == null || !mounted) return;
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
    //a lost pass only costs the card coming back round, but it goes through
    //the same path so the deck and the server cannot disagree about what has
    //been seen
    await SwipeQueue.instance.send(
      uid: FirebaseAuth.instance.currentUser!.uid,
      targetId: card.id,
      action: "pass",
    );
  }

  Future<void> _loadSuperLikesLeft() async {
    try {
      final left = await ApiService.getSuperLikesLeft();
      if (mounted) setState(() => _superLikesLeft = left);
    } catch (_) {
      //leaves it at zero, so the star is refused rather than spent blind
    }
  }

  void _swipeUp({bool fromButton = false}) async {
    //REFUSED HERE, BEFORE THE CARD MOVES. Letting the animation run and then
    //failing would show a super like leaving and silently not happen.
    if (_superLikesLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.superLikesNoneLeft)),
      );
      return;
    }

    final card = cards[currentIndex];
    _animateCardOut(
      0.0,
      card.name,
      true,
      fromButton: fromButton,
      isSuperLike: true,
    );
    final result = await SwipeQueue.instance.send(
      uid: FirebaseAuth.instance.currentUser!.uid,
      targetId: card.id,
      action: "super_like",
    );
    //spent, whatever the match turned out to be
    if (mounted) setState(() => _superLikesLeft -= 1);

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

    //which deck this reply will belong to; see _deckGeneration
    final generation = _deckGeneration;

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      List<CardData> users = await ApiService.getMultipleUsers(uid);

      //THE FILTERS CHANGED WHILE THIS WAS IN THE AIR. These people were
      //chosen under the old ones, and _resetDeck has already started a fetch
      //of its own - so this reply is dropped, and _isFetching is left alone
      //because it now belongs to that newer fetch.
      if (generation != _deckGeneration) return;

      //ANYONE WITH AN UNDELIVERED SWIPE IS DROPPED HERE. The server has not
      //heard about those yet, so it keeps offering them - and a profile you
      //passed coming back round looks exactly like a bug, while one you liked
      //coming back invites a pass on somebody you wanted. The queue is the
      //only record until it lands, so the deck has to ask it.
      final undelivered = SwipeQueue.instance.pendingTargetIds;
      if (undelivered.isNotEmpty) {
        users = users
            .where((card) => !undelivered.contains(card.id))
            .toList();
      }

      //NOBODY WHO IS ALREADY IN THE DECK. /users/feed has no pagination: it
      //answers with a random sample of everyone you have not swiped, so a
      //second request returns the SAME people, and appending them shows one
      //profile twice.
      //
      //It bites hardest on a small deck, which is the opposite of what you
      //would guess. A refetch is triggered whenever fewer than fetchThreshold
      //cards remain, so with four candidates the deck is permanently below
      //that line and every single swipe refetches the three people still in
      //front of you. With fifty candidates the random sample differs each
      //time and the collisions look like coincidence.
      final inDeck = cards.map((card) => card.id).toSet();
      final fresh =
          users.where((card) => !inDeck.contains(card.id)).toList();

      if (fresh.isEmpty) {
        //AN EMPTY SAMPLE AND A DUPLICATE SAMPLE ARE NOT THE SAME THING. The
        //server returning nothing means there is nobody left. A sample that
        //happens to land entirely inside the deck does not prove that - the
        //cap is applied server side and the order is random - so treating it
        //as the end would show "no more profiles" with people still to see.
        //Several in a row is a different matter.
        _fetchesWithNothingNew++;
        if (users.isEmpty ||
            _fetchesWithNothingNew >= _kGiveUpAfterEmptyFetches) {
          _hasNoMoreProfiles = true;
        }
        _isFetching = false;
        return;
      }

      _fetchesWithNothingNew = 0;
      if (mounted) {
        setState(() {
          cards.addAll(fresh);
        });
      }
    } catch (e) {
      //NO setState HERE. _isFetching is not read by build, so rebuilding for
      //it achieves nothing - and this used to call setState with no mounted
      //check, which throws if the request fails after the page is disposed.
      //The generation check is the same one as above: a failed fetch from a
      //discarded deck must not lower the flag a live one has raised.
      if (generation != _deckGeneration) return;
    }
    _isFetching = false;
  }

  //Main build (UI here)
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: MainAppBar(
          title: widget.title,
          showBack: widget.automaticallyImplyLeading,
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
              superLikeAvailable: _superLikesLeft > 0,
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
  //
  //WITH A WAY OUT OF IT. This screen is shown behind a latch that nothing
  //else clears, so without a button the only recovery is killing the app -
  //and the two reasons to be here are "you have seen everyone" and "somebody
  //joined a minute after you ran out", which look identical from the sofa.
  Widget _buildNoMoreCards() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          Text(
            text.noMoreProfiles,
            style: const TextStyle(fontSize: 24, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            text.checkLater,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          //_resetDeck, not _fetchMoreCards: the latch has to come down first,
          //or this button would call a function that returns immediately.
          TextButton.icon(
            onPressed: _resetDeck,
            icon: const Icon(Icons.refresh),
            label: Text(text.retry),
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
        //the buttons fly down from the card, so the star must already be the
        //same colour there - otherwise it changes shade mid-flight
        superLikeAvailable: _superLikesLeft > 0,
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
