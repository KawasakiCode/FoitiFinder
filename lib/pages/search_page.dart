import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        //search bar
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SearchBar(
                constraints: BoxConstraints(maxHeight: 40, minHeight: 40),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                leading: Image.asset(
                  'assets/icons/search.png',
                  width: 17,
                  height: 17,
                  key: UniqueKey(),
                ),
                hintText: 'Search',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Align(
                alignment: Alignment.centerRight,
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
          //fy page captures all remaining space
          Expanded( 
            child: Container(
              color: const Color.fromARGB(255, 209, 209, 209),
              //custom grid view 
              child: GridView.custom(
                gridDelegate: SliverQuiltedGridDelegate(
                  crossAxisCount: 3,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  repeatPattern: QuiltedGridRepeatPattern.inverted,
                  //the pattern that the grid view follows
                  pattern: [
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(2, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(2, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                    QuiltedGridTile(1, 1),
                  ],
                ),
                //what each tile of the grid view will be
                childrenDelegate: SliverChildBuilderDelegate(
                  (context, index) => Container(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ),
            ),
            ),
        ],
      ),
      //bottom bar (home, search, create post, reel, profile)
      bottomNavigationBar: custom_bottom_nav.BottomNavigationBar(),
    );
  }
}
