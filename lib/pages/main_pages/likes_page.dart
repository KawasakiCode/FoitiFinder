import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/models/card_data_model.dart';
import 'package:foitifinder/models/liker_model.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:foitifinder/widgets/animated_swipe_button.dart';
import 'package:foitifinder/widgets/photo_card.dart';

class LikesPage extends StatefulWidget{
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPage();
}

class _LikesPage extends State<LikesPage>{
  List<LikerModel> _likes = [];

  @override
  initState() {
    super.initState();
    _loadLikes();
  }

  void _loadLikes() async {
    final likes = await ApiService.getLikes(FirebaseAuth.instance.currentUser!.uid);
    if(mounted) {
      setState(() {
        _likes = likes;
      });
    }
  }

  Future<void> _showUserDialog(int userId, int index) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(  
          child: Material(
            type: MaterialType.transparency,
            child: Container(  
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(  
                borderRadius: BorderRadius.circular(20),
              ),
              child: FutureBuilder<CardData>(  
                future: ApiService.getSingleUser(userId),
                builder: (context, snapshot) {
                  if(snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if(snapshot.hasError) {
                    return Center(child: Text("${snapshot.error}"));
                  }
                  final user = snapshot.data!;
            
                  return Stack(  
                    children: [
                      Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 90, // Leave room for buttons!
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                          // Optional: round bottom corners or keep flat
                          bottomLeft: Radius.circular(20), 
                          bottomRight: Radius.circular(20),
                        ),
                        child: PhotoCard(card: user),
                      ),
                    ),
            
                      Positioned(
                      bottom: 15,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // REJECT
                          AnimatedSwipeButton(
                            icon: Icons.close,
                            activeColor: Colors.red,
                            size: 65, // Main buttons are bigger
                            onPressed: () {
                              if (context.mounted) Navigator.pop(ctx, true);
                            },
                          ),
                          // LIKE
                          AnimatedSwipeButton(
                            icon: Icons.favorite,
                            activeColor: Colors.green,
                            size: 65,
                            onPressed: () {
                              if (context.mounted) Navigator.pop(ctx, true);
                            },
                          ),
                        ],
                      ),
                    ),
                    ]
                  );
                }
              )
            ),
          )
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text("FoitiFinder"),
      ),
      body: SingleChildScrollView(  
        child: Column(  
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              itemCount: _likes.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (_, index) => Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(15),
                clipBehavior: Clip.antiAlias,
                child: Ink.image(
                  image: NetworkImage(_likes[index].imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  child: InkWell(
                    onTap: () {
                      _showUserDialog(_likes[index].id, index);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 5, bottom: 5),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              "${_likes[index].username}, ${_likes[index].age}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]
        )
      )
    );
  }
}