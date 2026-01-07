import 'package:flutter/material.dart';
import 'package:foitifinder/models/card_data_model.dart';

class PhotoCard extends StatefulWidget{
  final CardData card;
  const PhotoCard({super.key, required this.card});

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  int _currentIndex = 0;

  List<String> get _photos {
    if(widget.card.photos.isNotEmpty) {
      return widget.card.photos;
    }
    return ["https://picsum.photos/400/600"];
  }

  void _nextPhoto() {
    if(_currentIndex < _photos.length - 1) {
      setState(() {
        _currentIndex++;
      },);
    }
  }

  void _previousPhoto() {
    if(_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      },);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(  
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(  
        borderRadius: BorderRadius.circular(20),
        child: Stack(  
          fit: StackFit.expand,
          children: [
            Image.network(  
              _photos[_currentIndex],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if(loadingProgress == null)return child;
                return Container(color: Colors.grey[200]);
              },
              errorBuilder:(context, error, stackTrace) => Container(color: Colors.grey),
            ),
            Container(
              decoration: BoxDecoration(  
                gradient: LinearGradient(  
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ]
                )
              )
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _previousPhoto, // Only catches Taps
                    behavior: HitTestBehavior.translucent,
                    child: Container(),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _nextPhoto, // Only catches Taps
                    behavior: HitTestBehavior.translucent,
                    child: Container(),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(  
                children: List.generate(_photos.length, (index) {
                  return Expanded(  
                    child: Padding(  
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(  
                        height: 4, 
                        decoration: BoxDecoration(  
                          color: index == _currentIndex 
                          ? Colors.white 
                          : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 2)
                        ]
                        )
                      ),
                    ),
                  );
                })
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.card.username}, ${widget.card.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                  widget.card.bio != null ? widget.card.bio! : "",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),                
                ],
              ),
            ),
          ],

        )
      )
    );
  }
}