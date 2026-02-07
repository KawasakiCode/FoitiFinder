//this widget creates the users card 
//but made to handle showing photos and having the left and right tap functionality
//to change photos if user has more than one

import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    _precacheRemainingPhotos();
  }

  //reset currentIndex if user changes card
  @override
  void didUpdateWidget(PhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if(widget.card.id != oldWidget.card.id) {
      setState(() {
        _currentIndex = 0;
      });
    }
  }

  //tap to next photo
  void _nextPhoto() {
    if(_currentIndex < _photos.length - 1) {
      setState(() {
        _currentIndex++;
      },);
    }
  }

  //tap to previous photo
  void _previousPhoto() {
    if(_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      },);
    }
  }

  //function to precache the users other photos
  void _precacheRemainingPhotos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(widget.card.photos.length > 1) {
        for(int i = 1; i < widget.card.photos.length; i++) {
          if(i > 5) break;
          precacheImage(  
            CachedNetworkImageProvider(widget.card.photos[i]),
            context
          );
        }
      }
    });
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
            //first layer is the photo itself
            CachedNetworkImage( 
              imageUrl: _photos[_currentIndex], 
              fit: BoxFit.cover,
              memCacheWidth: 800,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (context, url) => Container(  
                color: Colors.grey[200],
                child: const Center(  
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget:(context, url, error) => Container(color: Colors.grey),
            ),
            //second layer a black gradient so username clearly shows
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
            //third layer the gesture detectors for next and previous photo
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
            //fourth layer the indicators which change depending on the number of photos
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
            //fifth layer the username, age and bio of the user if they exist
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.card.age != null 
                  ?
                  Text(
                    '${widget.card.username}, ${widget.card.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : Text(
                    widget.card.username,
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