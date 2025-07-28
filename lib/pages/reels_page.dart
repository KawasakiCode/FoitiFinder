import 'package:flutter/material.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;
import 'dart:math' as math;

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 209, 209, 209),
      body: PageView.builder(  
        scrollDirection: Axis.vertical,
        itemCount: 10, 
        itemBuilder: (context, index) {
          return SizedBox(
            height: MediaQuery.of(context).size.height,
            child: buildReel(),
          );
        }
      ),
      //bottom bar (home, search, create post, reel, profile)
      bottomNavigationBar: custom_bottom_nav.BottomNavigationBar(),
    );
  }
}

Stack buildReel() {
  return Stack(
        children: [
          //bottom row above bottom nav bar (contains username, description, follow, pfp)
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(  
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Container(
                            width: 43,
                            height: 43,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text('description',
                            style: TextStyle(
                              fontSize: 12,
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text('username',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          )
                        ),
                      ),
                      Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text('',
                            style: TextStyle(
                              fontSize: 12,
                            )
                          ),
                        ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(  
                        padding: const EdgeInsets.only(left: 10),
                        child: Container( 
                          decoration: BoxDecoration(  
                            border: Border.all(  
                              color: const Color.fromARGB(255, 7, 7, 7),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            child: Text('Follow',  
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              )
                              ),
                          ),
                        )
                      ),
                      Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text('',
                            style: TextStyle(
                              fontSize: 12,
                            )
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
          ),
          //right column (contains camera, like, comment, dm, more)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 65, 5, 415),
                    child: Image.asset(
                      'assets/icons/camera.png',
                      width: 30,
                      height: 30,
                      key: UniqueKey(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 5),
                    child: Image.asset(
                      'assets/icons/like.png',
                      width: 25,
                      height: 25,
                      key: UniqueKey(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 15),
                    child: Text('x likes'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 5),
                    child: Image.asset(
                      'assets/icons/comment.png',
                      width: 25,
                      height: 25,
                      key: UniqueKey(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 15),
                    child: Text('131'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 5),
                    child: Image.asset(
                      'assets/icons/dm.png',
                      width: 25,
                      height: 25,
                      key: UniqueKey(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 15),
                    child: Text('x dm'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 5, 10),
                    child: Transform.rotate(
                      angle: math.pi / 2,
                      child: Image.asset(
                        'assets/icons/more.png',
                        width: 20,
                        height: 20,
                        key: UniqueKey(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}