import 'package:flutter/material.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<CardData> cards = [];
  int currentIndex = 0;
  late AnimationController _animationController;
  Offset _dragOffset = Offset.zero;

  // Track swiped cards for rewind functionality
  List<CardData> swipedCards = [];

//card creation
  @override
  void initState() {
    super.initState();

    // Initialize sample data
    cards = [
      CardData(
        id: 1,
        name: "Sarah",
        age: 25,
        bio: "Love hiking and coffee ☕",
        imageUrl: "https://picsum.photos/300/400?random=1",
      ),
      CardData(
        id: 2,
        name: "Mike",
        age: 28,
        bio: "Photography enthusiast 📸",
        imageUrl: "https://picsum.photos/300/400?random=2",
      ),
      CardData(
        id: 3,
        name: "Emma",
        age: 23,
        bio: "Foodie and traveler ✈️",
        imageUrl: "https://picsum.photos/300/400?random=3",
      ),
      CardData(
        id: 4,
        name: "Alex",
        age: 26,
        bio: "Music lover 🎵",
        imageUrl: "https://picsum.photos/300/400?random=4",
      ),
    ];
    currentIndex = 0;

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
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double threshold = screenWidth * 0.3; // 30% of screen width

    if (_dragOffset.dx.abs() > threshold) {
      // Swipe threshold met
      if (_dragOffset.dx > 0) {
        // Swipe right (like)
        _swipeRight();
      } else {
        // Swipe left (pass)
        _swipeLeft();
      }
    } else {
      // Return to center
      _resetCard();
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
    // Store the current card in swiped cards list for rewind functionality
    swipedCards.add(cards[currentIndex]);

    _animationController.forward().then((_) {
      setState(() {
        currentIndex++;
        _dragOffset = Offset.zero;
      });
      _animationController.reset();
      _showSwipeFeedback(
        isLike,
        cardName,
        isSuperLike: isSuperLike,
      ); // Pass the correct name and super like status
    });
  }

//reset card
  void _resetCard() {
    setState(() {
      _dragOffset = Offset.zero;
    });
  }

//rewind function
  void _rewindCard() {
    if (swipedCards.isNotEmpty && currentIndex > 0) {
      setState(() {
        // Get the last swiped card
        final lastSwipedCard = swipedCards.removeLast();

        // Insert it back at the current position
        cards.insert(currentIndex, lastSwipedCard);

        // Reset drag offset
        _dragOffset = Offset.zero;
      });
    }
  }

//show feedback (to be deleted)
  void _showSwipeFeedback(
    bool isLike,
    String cardName, {
    bool isSuperLike = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSuperLike
              ? "💙 You super liked $cardName!"
              : (isLike
                    ? "❤️ You liked $cardName!"
                    : "👎 You passed on $cardName"),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: isSuperLike
            ? Colors.blue
            : (isLike ? Colors.green : Colors.red),
      ),
    );
  }

//main build function (appbar here)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                key: UniqueKey(),
              ),
              onPressed: () {},
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 238, 238, 238),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1.5),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color.fromARGB(255, 209, 209, 209),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: cards.isNotEmpty && currentIndex < cards.length
                ? _buildSwipeCards()
                : _buildNoMoreCards(),
          ),
          _buildActionButtons(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: custom_bottom_nav.BottomNavigationBar(),
      ),
    );
  }

//build cards function (to be changed to reduce loading time)
  Widget _buildSwipeCards() {
    return Stack(
      children: [
        // Background cards (stacked behind)
        for (
          int i = currentIndex + 1;
          i < cards.length && i < currentIndex + 2;
          i++
        )
          Positioned(
            top: 20 + (i - currentIndex) * 10.0,
            left: 20 + (i - currentIndex) * 5.0,
            right: 20 - (i - currentIndex) * 5.0,
            child: Transform.scale(
              scale: 1.0 - (i - currentIndex) * 0.05,
              child: _buildCard(cards[i], false),
            ),
          ),

        // Current card (top)
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: GestureDetector(
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Transform.translate(
              offset: _dragOffset,
              child: Transform.rotate(
                angle:
                    _dragOffset.dx *
                    0.0025, // Reduced rotation for smoother feel
                child: _buildCard(cards[currentIndex], true),
              ),
            ),
          ),
        ),
      ],
    );
  }

//build top card
  Widget _buildCard(CardData card, bool isTop) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
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
              if (_dragOffset.dx > 50)
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
              if (_dragOffset.dx < -50)
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
              onPressed: swipedCards.isNotEmpty ? _rewindCard : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              backgroundColor: Colors.white,
              child: Icon(
                Icons.replay,
                color: swipedCards.isNotEmpty
                    ? Colors.orange
                    : Color.fromARGB(255, 78, 78, 78),
                size: 25,
              ),
            ),
          ),

          // Only show other buttons if there are cards to swipe
          if (currentIndex < cards.length) ...[
            // Pass button
            FloatingActionButton(
              onPressed: () => _swipeLeft(),
              backgroundColor: Colors.white,
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
                onPressed: () {
                  // Super like acts as a like but with special feedback
                  final cardName = cards[currentIndex].name;
                  _animateCardOut(1.0, cardName, true, isSuperLike: true);
                },
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
              onPressed: () => _swipeRight(),
              backgroundColor: Colors.white,
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
                onPressed: () {},
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
