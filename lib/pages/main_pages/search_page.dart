import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/bottom_navigation_bar.dart' as custom_bottom_nav;
import 'package:foitifinder/l10n/app_localizations.dart';
import 'home_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        //search bar
        title: Text("FoitiFinder"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 5),
              child: Text(
                text.exploreText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Center(
              child: Material(
                color: const Color.fromARGB(255, 150, 31, 247),
                borderRadius: BorderRadius.circular(15),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  splashColor: Colors.white24,
                  highlightColor: Colors.white10,
                  onTap: () {},
                  child: Container(
                    margin: EdgeInsets.only(top: 5),
                    width: MediaQuery.of(context).size.width * 0.95,
                    height: MediaQuery.of(context).size.height * 0.25,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 15, top: 7),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Text(
                              "100",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 20),
                          child: Image.asset(
                            "assets/icons/like.png",
                            width: 90,
                            height: 90,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 15, bottom: 10),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              "Place later",
                              style: TextStyle(
                                fontSize: 19,
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
            Padding(
              padding: EdgeInsets.only(top: 5, left: 15),
              child: Text(
                text.similarPlans,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, bottom: 5),
              child: Text(
                text.similarPlansText,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              itemCount: 16,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (_, i) => Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(15),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  splashColor: Colors.white24,
                  highlightColor: Colors.white10,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyHomePage(showBottomNav: false, showSettings: false, title: tiles[i].caption, automaticallyImplyLeading: true)),
                    );
                  },
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 10, top: 7),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Text(
                            "${tiles[i].userCount}",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 20),
                        child: Image.asset(
                          tiles[i].imagePath,
                          width: 140,
                          height: 140,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 5),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            tiles[i].caption,
                            style: TextStyle(
                              fontSize: 19,
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
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: custom_bottom_nav.BottomNavigationBar(),
      ),
    );
  }
}

//Tile class to make each tile independent
class TileData{
  final int userCount;
  final String imagePath;
  final String caption;

  const TileData({required this.userCount, required this.imagePath, required this.caption});
}

final List<TileData> tiles = [
  TileData(userCount: 100, imagePath: "assets/icons/like.png", caption: "Place later"),
  TileData(userCount: 150, imagePath: "assets/icons/dm.png", caption: "Place later 2"),
  TileData(userCount: 130, imagePath: "assets/icons/comment.png", caption: "Place later 3"),
  TileData(userCount: 120, imagePath: "assets/icons/like.png", caption: "Place later 4"),
  TileData(userCount: 200, imagePath: "assets/icons/save.png", caption: "Place later 5"),
  TileData(userCount: 210, imagePath: "assets/icons/like.png", caption: "Place later 6"),
  TileData(userCount: 50, imagePath: "assets/icons/like.png", caption: "Place later 7"),
  TileData(userCount: 78, imagePath: "assets/icons/like.png", caption: "Place later 8"),
  TileData(userCount: 40, imagePath: "assets/icons/like.png", caption: "Place later 9"),
  TileData(userCount: 140, imagePath: "assets/icons/like.png", caption: "Place later 10"),
  TileData(userCount: 180, imagePath: "assets/icons/like.png", caption: "Place later 11"),
  TileData(userCount: 90, imagePath: "assets/icons/save.png", caption: "Place later 12"),
  TileData(userCount: 10, imagePath: "assets/icons/like.png", caption: "Place later 13"),
  TileData(userCount: 20, imagePath: "assets/icons/like.png", caption: "Place later 14"),
  TileData(userCount: 220, imagePath: "assets/icons/like.png", caption: "Place later 15"),
  TileData(userCount: 230, imagePath: "assets/icons/like.png", caption: "Place later 16"),
];