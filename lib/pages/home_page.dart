import 'package:flutter/material.dart';
import 'dm_page.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 2,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Image.asset(
                'assets/icons/camera.png',
                width: 30,
                height: 30,
                key: UniqueKey(),
              ),
              onPressed: () {},
            ),
            Text('My App'),
            IconButton(
              icon: Image.asset(
                'assets/icons/messenger.png',
                width: 25,
                height: 25,
                key: UniqueKey(),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DMPage()),
                );
              },
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
          //Stories container
          Container(
            margin: EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              border: Border(
                bottom: BorderSide(
                  color: const Color.fromARGB(255, 209, 209, 209),
                  width: 1.5,
                ),
              ),
            ),
            width: MediaQuery.of(context).size.width,
            height: 85,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 20, // Number of story circles
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
          //Posts container (post, username, more, likes, comments, view all comments)
          Expanded(
            child: ListView(
              children: <Widget>[
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height -
                      85 -
                      60 -
                      AppBar().preferredSize.height -
                      MediaQuery.of(context).padding.top,
                  child: Column(
                    children: [
                      //above post container (pfp, username, more)
                      Container(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        height: 50,
                        width: MediaQuery.of(context).size.width,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 15),
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Text(
                                  'username',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.only(right: 15),
                                  child: Image.asset(
                                    'assets/icons/more.png',
                                    width: 25,
                                    height: 25,
                                    key: UniqueKey(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      //post image or video
                      Expanded(
                        child: Container(
                          color: Colors.purple,
                          height: 500,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      //below post container (likes, username, like, comment, dm, save)
                      Container(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        height: 110,
                        width: MediaQuery.of(context).size.width,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(10, 10, 0, 0),
                                    child: Image.asset(
                                      'assets/icons/like.png',
                                      width: 25,
                                      height: 25,
                                      key: UniqueKey(),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(10, 10, 0, 0),
                                    child: Image.asset(
                                      'assets/icons/comment.png',
                                      width: 25,
                                      height: 25,
                                      key: UniqueKey(),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(10, 10, 0, 0),
                                    child: Image.asset(
                                      'assets/icons/dm.png',
                                      width: 25,
                                      height: 25,
                                      key: UniqueKey(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        0,
                                        10,
                                        10,
                                        0,
                                      ),
                                      child: Image.asset(
                                        'assets/icons/save.png',
                                        width: 25,
                                        height: 25,
                                        key: UniqueKey(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: const Text(
                                  'x likes',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: const Text(
                                  'username',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(left: 10),
                                child: const Text(
                                  'View all x comments',
                                  style: TextStyle(fontWeight: FontWeight.w300),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      //bottom bar (home, search, create post, reel, profile)
      bottomNavigationBar: custom_bottom_nav.BottomNavigationBar(),
    );
  }
}
