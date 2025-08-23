import 'package:flutter/material.dart';
import '../pages/dm_page.dart';
import '../pages/search_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

class BottomNavigationBar extends StatelessWidget {
  const BottomNavigationBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color.fromARGB(255, 209, 209, 209),
            width: 1.7,
          ),
        ),
        color: const Color.fromARGB(255, 255, 255, 255),
      ),
      width: MediaQuery.of(context).size.width,
      height: 60,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Image.asset(
                'assets/icons/home_page.png',
                width: 35,
                height: 35,
                key: UniqueKey(),
              ),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => MyHomePage()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
            IconButton(
              icon: Image.asset(
                'assets/icons/search.png',
                width: 30,
                height: 30,
                key: UniqueKey(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchPage()),
                );
              },
            ),
            IconButton(
              icon: Image.asset(
                'assets/icons/like.png',
                width: 35,
                height: 35,
                key: UniqueKey(),
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset(
                'assets/icons/comment.png',
                width: 32,
                height: 32,
                key: UniqueKey(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DMPage()),
                );
              },
            ),
            IconButton(
              icon: Image.asset(
                'assets/icons/user.png',
                width: 30,
                height: 30,
                key: UniqueKey(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
