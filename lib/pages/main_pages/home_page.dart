import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/pages/settings/settings.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/animated_swipe_button.dart';
import 'package:foitifinder/widgets/photo_card.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.showSettings = true,
    this.title = 'FoitiFinder',
    this.automaticallyImplyLeading = false,
  });

  final bool showSettings;
  final String title;
  final bool automaticallyImplyLeading;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<CardData> cards = [];
  int currentIndex = 0;
  final int maxHistory = 5; //how many rewinds until no more
  final int fetchThreshold = 10; //when 10 cards remain load more
  final int batchSize = 20; // how many to load at a time
  bool _isFetching = false;
  bool _hasNoMoreProfiles = false;
  late AnimationController _animationController;
  //location of where the finger tapped the screen
  double _tapPositionY = 0;
  //Offset _dragOffset = Offset.zero;
  final ValueNotifier<Offset> _swipeNotifier = ValueNotifier(Offset.zero);
  //is the card animating (is the controller counting still)
  bool _isAnimating = false;
  // Track swiped cards for rewind functionality
  List<CardData> swipedCards = [];

  //card creation
  @override
  void initState() {
    super.initState();

    // Initialize sample data
    _fetchMoreCards();
    currentIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // We want to pre-cache for the Current User (Index 0) and the Next User (Index 1)
      // Determine how many users to look ahead (max 2)
      int usersToPrecache = cards.length > 2 ? 2 : cards.length;

      for (int i = 0; i < usersToPrecache; i++) {
        final card = cards[i];

        // 1. Pre-cache the main list of photos
        if (card.photos.isNotEmpty) {
          for (String url in card.photos) {
            precacheImage(NetworkImage(url), context);
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
    //setState(() {
    _swipeNotifier.value += details.delta;
    //});
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

    //when to swipe left and right or reset
    bool isSwipeRight = offset.dx > distanceThreshold;
    bool isFlickRight = velocity > velocityThreshold && offset.dx > 0;
    bool isSwipeLeft = offset.dx < -distanceThreshold;
    bool isFlickLeft = velocity < -velocityThreshold && offset.dx < 0;
    bool isSwipeUp = offset.dy.abs() > offset.dx.abs();

    if(isSwipeUp && offset.dy < -verticalThreshold) {
      _swipeUp();
      return;
    }

    if (!isSwipeUp && (isSwipeRight || isFlickRight)) {
      // Swipe threshold or speed threshold met
      _swipeRight();
    } else if (isSwipeLeft || isFlickLeft) {
      // Swipe left
      _swipeLeft();
    } else {
      // Return to center
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

    // 2. Precache the card after that (Buffer)
    if (currentIndex + 2 < cards.length) {
      _precacheUserPhotos(cards[currentIndex + 2]);
    }
  }

  void _precacheUserPhotos(CardData card) {
  if (card.photos.isNotEmpty) {
    // Loop through photos
    for (int i = 0; i < card.photos.length; i++) {
      
      // OPTIMIZATION: Only cache the first 3 photos. 
      // If the user taps past photo #3, Flutter will load #4 on demand.
      // This prevents the "Swipe Stutter" caused by downloading too much at once.
      if (i > 5) break; 
      
      precacheImage(CachedNetworkImageProvider(card.photos[i]), context);
    }
  }
}

  //swiping functions
  void _swipeRight() async {
    final cardName = cards[currentIndex].username; // Store name before animation
    _animateCardOut(1.0, cardName, true);
    bool isMatch = await ApiService.registerSwipe(FirebaseAuth.instance.currentUser!.uid, cards[currentIndex].id, "like");

    if(isMatch) {
      if(!mounted)return;
      showDialog(  
        context: context,
        builder: (context) => AlertDialog(  
          title: Text("It's a match!"),
          content: Text("You and ${cards[currentIndex].username} liked each other!"),
        )
      );
    }
  }

  void _swipeLeft() async {
    final cardName = cards[currentIndex].username; // Store name before animation
    await ApiService.registerSwipe(FirebaseAuth.instance.currentUser!.uid, cards[currentIndex].id, "pass");
    _animateCardOut(-1.0, cardName, false);
  }

  void _swipeUp() async {
    final cardName = cards[currentIndex].username;
    _animateCardOut(0.0, cardName, true, isSuperLike: true);
    bool isMatch = await ApiService.registerSwipe(FirebaseAuth.instance.currentUser!.uid, cards[currentIndex].id, "super_like");

    if(isMatch) {
      if(!mounted)return;
      showDialog(  
        context: context,
        builder: (context) => AlertDialog(  
          title: Text("It's a match!"),
          content: Text("You and ${cards[currentIndex].username} liked each other!"),
        )
      );
    }
  }

  //swiping animation
  void _animateCardOut(
    double direction,
    String cardName,
    bool isLike,
    {bool fromButton = false,
    bool isSuperLike = false}) {
    
    //if card is currently animating dont animate the next
    if(_isAnimating)return;
    //lock the function so that it cant run again while still animating
    _isAnimating = true;

    if (fromButton) {
      _tapPositionY = 0.0;
    }
    
    final startOffset = _swipeNotifier.value;
    //end offset is set off screen 
    Offset endOffset;

    if(isSuperLike) {
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

        //if more than 5 cards are behind delete the first
        if (currentIndex > maxHistory) {
          cards.removeAt(0);
          currentIndex--;
        }

        //if less than 10 cards are remaining ahead make new
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

  //reset card
  void _resetCard() {
    if(_isAnimating)return;
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

  //rewind function
  void _rewindCard() {
    if (currentIndex > 0) {
      setState(() {
        // Get the last swiped card
        currentIndex--;

        // Reset drag offset
        _swipeNotifier.value = Offset.zero;
        _animationController.reset();
      });
    }
  }

  Future<void> _fetchMoreCards() async {
    //if the user swipes fast this prevents multiple function calls
    if (_isFetching || _hasNoMoreProfiles) return;
    _isFetching = true;

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      List<CardData> users = await ApiService.getMultipleUsers(uid);
      if(users.isEmpty) {
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

  //main build function (appbar here)
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
              if (widget.showSettings)
                IconButton(
                  icon: Image.asset(
                    'assets/icons/settings.png',
                    width: 25,
                    height: 25,
                    key: UniqueKey(),
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
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: cards.isNotEmpty && currentIndex < cards.length
                      ? _buildSwipeCards()
                      : _buildNoMoreCards(),
                ),
                _buildActionButtons(),
              ],
            ),
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
        //screen size
        final double screenWidth = MediaQuery.of(context).size.width;
        final double screenHeight = MediaQuery.of(context).size.height;
        final double centerPoint = screenHeight / 3;

        //offset and ratio for animations
        final double dragDistance = offset.dx.abs();
        final double ratio = (dragDistance / screenWidth).clamp(0.0, 1.0);
        final double bgRatio = (ratio * 5.0).clamp(0.0, 1.0);

        //rotation direction
        final double rotationDirection = _tapPositionY > centerPoint
            ? -1.0
            : 1.0;
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
                  if(_isAnimating)return;
                  _onPanUpdate(details);},
                onPanEnd: (details) {
                  if(_isAnimating)return;
                  _onPanEnd(details);},
                onPanStart: _onPanStart,
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _swipeNotifier,
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: angle, // Reduced rotation for smoother feel
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PhotoCard(card: card),

            // Swipe indicators (only on top card)
            if (isTop) ...[
              // Like indicator (right swipe) - positioned on LEFT for better visibility
              if (_swipeNotifier.value.dx > 50 && _swipeNotifier.value.dx.abs() > _swipeNotifier.value.dy.abs())
                Positioned(
                  top: 60,
                  left: 60,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.green,
                      size: 120,
                    ),
                  ),
                ),

              // Pass indicator (left swipe) - positioned on RIGHT for better visibility
              if (_swipeNotifier.value.dx < -50 && _swipeNotifier.value.dx.abs() > _swipeNotifier.value.dy.abs())
                Positioned(
                  top: 60,
                  right: 60,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: const Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 120,
                    ),
                  ),
                ),
              
              // Super like indicator (up swippe)
              if (_swipeNotifier.value.dy < -50 && _swipeNotifier.value.dy.abs() > _swipeNotifier.value.dx.abs())
                Positioned(  
                  top:  200, 
                  left: 0, 
                  right: 0,
                  child: Center(  
                    child: Transform.rotate(  
                      angle: 0,
                      child: const Icon(
                        Icons.star,
                        color: Colors.blueAccent,
                        size: 120,
                      )
                    )
                  )
                ),
            ],
          ],
        ),
      ),
    );
  }

  //when cards run out show this function
  Widget _buildNoMoreCards() {
    final text = AppLocalizations.of(context)!;
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

  //build the buttons under the cards
  Widget _buildActionButtons() {
    // Show rewind button even when no more cards if we have swiped cards
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ValueListenableBuilder(
        valueListenable: _swipeNotifier,
        builder: (context, offset, child) {
          final dx = offset.dx;
          final dy = offset.dy;
          final isHorizontal = dx.abs() > dy.abs();
          final isVertical = dy.abs() > dx.abs();

          final bool isLikeActive = dx > 45 && isHorizontal;
          final bool isPassActive = dx < -45 && isHorizontal;
          final bool isSuperLikeActive = dy < 45 && isVertical;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind button
              AnimatedSwipeButton(
                icon: Icons.replay,
                activeColor: Colors.orange,
                size: 50,
                // If no history, pass null to disable it visually
                onPressed: currentIndex > 0
                    ? _rewindCard
                    : null
              ),
          
              // Only show other buttons if there are cards to swipe
              if (currentIndex < cards.length) ...[
                // Pass button
                AnimatedSwipeButton(
                  icon: Icons.close,
                  activeColor: Colors.red,
                  size: 65, // Main buttons are bigger
                  forcePressed: isPassActive,
                  onPressed: () {
                    final cardName = cards[currentIndex].username;
                    _animateCardOut(-1.0, cardName, false, fromButton: true);
                  },
                ),
          
                // Super like button
                AnimatedSwipeButton(
                  icon: Icons.star,
                  activeColor: Colors.blueAccent,
                  size: 50,
                  forcePressed: isSuperLikeActive,
                  onPressed: () {
                    final cardName = cards[currentIndex].username;
                    _animateCardOut(1.0, cardName, true, fromButton: true, isSuperLike: true);
                  },
                ),
          
                // Like button
                AnimatedSwipeButton(
                  icon: Icons.favorite,
                  activeColor: Colors.green,
                  size: 65,
                  forcePressed: isLikeActive,
                  onPressed: () {
                    final cardName = cards[currentIndex].username;
                    _animateCardOut(1.0, cardName, true, fromButton: true);
                  },
                ),
          
                // DM button
                AnimatedSwipeButton(
                  icon: Icons.message,
                  activeColor: Colors.blueAccent,
                  size: 50,
                  onPressed: () {
                    // Handle DM
                  },
                ),
              ],
            ],
          );
        }
      ),
    );
  }
}
