import 'package:flutter/material.dart';
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
        title: Text("FoitiFinder"),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15, top: 5),
              child: Text(
                "Welcome to Explore",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 5),
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 5, left: 15),
              child: Text(
                "Get photo verified",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Text(
                "Photo verification helps your visibility",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
              ),
            ),
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 5),
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: 5, left: 15),
              child: Text(
                "Similar plans and lifestyles",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, bottom: 5),
              child: Text(
                "Find people with similar life goals and hobbies",
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
                    switch (i) {
                      case 0: break;
                      case 1: break;
                      case 2: break;
                      case 3: break;
                      case 4: break;
                      case 5: break;
                      case 6: break;
                      case 7: break;
                      case 8: break;
                      case 9: break;
                      case 10: break;
                      case 11: break;
                      case 12: break;
                      case 13: break;
                      case 14: break;
                      case 15: break;
                      default: break;
                    }
                  },
                  child: Column(  
                    children: 
                    [

                    ]
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
