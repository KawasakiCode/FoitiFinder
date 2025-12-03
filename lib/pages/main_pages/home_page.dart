import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/bottom_navigation_bar.dart'
    as custom_bottom_nav;
import 'package:foitifinder/pages/settings/settings.dart';
import 'dart:math';
import 'package:foitifinder/l10n/app_localizations.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    this.showSettings = true,
    this.showBottomNav = true,
    this.title = 'FoitiFinder',
    this.automaticallyImplyLeading = false,
  });

  final bool showSettings;
  final bool showBottomNav;
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
  late AnimationController _animationController;
  //Offset _dragOffset = Offset.zero;
  final ValueNotifier<Offset> _swipeNotifier = ValueNotifier(Offset.zero);

  // Track swiped cards for rewind functionality
  List<CardData> swipedCards = [];

  //card creation
  @override
  void initState() {
    super.initState();

    // Initialize sample data
    cards = _generateMockCards(1, 15);
    currentIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cards.isNotEmpty) {
        precacheImage(NetworkImage(cards[0].imageUrl), context);
        if (cards.length > 1) {
          precacheImage(NetworkImage(cards[1].imageUrl), context);
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

  //generate infinte random cards to test swipe logic
  List<CardData> _generateMockCards(int startId, int count) {
    final Random random = Random();
    final List<String> names = [
      "Alex",
      "Sarah",
      "Mike",
      "Emma",
      "John",
      "Lisa",
      "Tom",
      "Anna",
    ];

    return List.generate(count, (index) {
      int id = startId + index;
      return CardData(
        id: id,
        name: names[random.nextInt(names.length)], // e.g. "Sarah #15"
        age: 18 + random.nextInt(10), // Random age 18-28
        bio: "This is a bio for user $id generated locally.",
        // Use random seed to get different images
        imageUrl: "https://picsum.photos/300/400?random=$id",
      );
    });
  }

  //gesture detector functions
  void _onPanUpdate(DragUpdateDetails details) {
    //setState(() {
    _swipeNotifier.value += details.delta;
    //});
  }

  void _onPanEnd(DragEndDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final offset = _swipeNotifier.value;

    //get how fast user dragged
    final velocity = details.velocity.pixelsPerSecond.dx;

    //Distance and speed thresholds for activating swipe left or right
    final distanceThreshold = screenWidth * 0.2;
    final velocityThreshold = 1000.0;

    //when to swipe left and right or reset
    bool isSwipeRight = offset.dx > distanceThreshold;
    bool isFlickRight = velocity > velocityThreshold && offset.dx > 0;
    bool isSwipeLeft = offset.dx < -distanceThreshold;
    bool isFlickLeft = velocity < -velocityThreshold && offset.dx < 0;

    if (isSwipeRight || isFlickRight) {
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

  //cache image
  void _precacheNextImage() {
    if (currentIndex + 1 < cards.length) {
      precacheImage(NetworkImage(cards[currentIndex + 1].imageUrl), context);
      if (currentIndex + 2 < cards.length) {
        precacheImage(NetworkImage(cards[currentIndex + 1].imageUrl), context);
      }
    }
  }

  //swiping functions
  void _swipeRight() {
    final cardName = cards[currentIndex].name; // Store name before animation
    _animateCardOut(1.0, cardName, true);
  }

  void _swipeLeft() {
    final cardName = cards[currentIndex].name; // Store name before animation
    _animateCardOut(-1.0, cardName, false);
  }

  //swiping animation
  void _animateCardOut(
    double direction,
    String cardName,
    bool isLike, {
    bool isSuperLike = false,
  }) {
    final startOffset = _swipeNotifier.value;
    final endOffset = Offset(
      MediaQuery.of(context).size.width * 1.5 * direction,
      0,
    );

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
    });
  }

  //reset card
  void _resetCard() {
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
    if (_isFetching) return;
    _isFetching = true;

    //simulate network delay for test purposes
    await Future.delayed(const Duration(seconds: 1));

    int lastId = cards.last.id;
    List<CardData> newBatch = _generateMockCards(lastId + 1, batchSize);

    if (mounted) {
      setState(() {
        cards.addAll(newBatch);
      });
    }

    _isFetching = false;
  }

  //main build function (appbar here)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Column(children: [
            Expanded(  
              flex: 1,
              child: Container(color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface),
              ),
              Expanded(
                flex: 1,  
                child: Container(  
                color: Colors.grey[900]!,
                )
              )
          ]
          ),
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
      bottomNavigationBar: widget.showBottomNav
          ? SafeArea(child: custom_bottom_nav.BottomNavigationBar())
          : null,
    );
  }

  //build cards function
  Widget _buildSwipeCards() {
    return ValueListenableBuilder<Offset>(
      valueListenable: _swipeNotifier,
      builder: (context, offset, child) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dragDistance = offset.dx.abs();
        final double ratio = (dragDistance / screenWidth).clamp(0.0, 1.0);
        final double bgRatio = (ratio * 5.0).clamp(0.0, 1.0);
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
                  scale: (1.0 - (((i - currentIndex)) * 0.05)) + (bgRatio * 0.05),
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
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _swipeNotifier,
                  builder: (context, offset, child) {
                    return Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle:
                            offset.dx *
                            0.0025, // Reduced rotation for smoother feel
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Image.network(
                card.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.person,
                      size: 100,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Card info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${card.name}, ${card.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    card.bio,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Swipe indicators (only on top card)
            if (isTop) ...[
              // Like indicator (right swipe) - positioned on LEFT for better visibility
              if (_swipeNotifier.value.dx > 50)
                Positioned(
                  top: 50,
                  left: 50,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Pass indicator (left swipe) - positioned on RIGHT for better visibility
              if (_swipeNotifier.value.dx < -50)
                Positioned(
                  top: 50,
                  right: 50,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PASS',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
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

  //when cards run out show this function
  Widget _buildNoMoreCards() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 100, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No more profiles to show!',
            style: TextStyle(fontSize: 24, color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text(
            'Check back later for new matches',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  //build the buttons under the cards
  Widget _buildActionButtons() {
    final text = AppLocalizations.of(context)!;
    // Show rewind button even when no more cards if we have swiped cards
    if (currentIndex >= cards.length && swipedCards.isEmpty) {
      //aka render nothing so there are no buttons
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rewind button
          SizedBox(
            width: 45,
            height: 45,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: (currentIndex > 0)
                  ? _rewindCard
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(text.cannotRewind),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.replay,
                color: (currentIndex > 0)
                    ? Colors.orange
                    : Color.fromARGB(255, 49, 49, 49),
                size: 25,
              ),
            ),
          ),

          // Only show other buttons if there are cards to swipe
          if (currentIndex < cards.length) ...[
            // Pass button
            FloatingActionButton(
              heroTag: null,
              onPressed: () => _swipeLeft(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.close, color: Colors.red, size: 30),
            ),

            // Super like button
            SizedBox(
              width: 45,
              height: 45,
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  // Super like acts as a like but with special feedback
                  final cardName = cards[currentIndex].name;
                  _animateCardOut(1.0, cardName, true, isSuperLike: true);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.star,
                  color: Color.fromARGB(255, 67, 91, 223),
                  size: 30,
                ),
              ),
            ),

            // Like button
            FloatingActionButton(
              heroTag: null,
              onPressed: () => _swipeRight(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.favorite, color: Colors.green, size: 30),
            ),

            // DM button
            SizedBox(
              width: 45,
              height: 45,
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () {},
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.message,
                  color: Color.fromARGB(255, 0, 0, 0),
                  size: 27,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

//declaration of card class
class CardData {
  final int id;
  final String name;
  final int age;
  final String bio;
  final String imageUrl;

  CardData({
    required this.id,
    required this.name,
    required this.age,
    required this.bio,
    required this.imageUrl,
  });
}
