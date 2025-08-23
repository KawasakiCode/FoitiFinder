import 'package:flutter/material.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FoitiFinder',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: Image.asset(
                      'assets/icons/settings.png',
                      width: 35,
                      height: 35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 15, 15),
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(  
                children: [
                  Row(  
                    children: [
                      Text("Username, ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Age", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ]
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: SizedBox(
                      width: 145,
                      height: 35,
                      child: FloatingActionButton(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: 
                            Text("Edit Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)
                        ),
                        onPressed: () {
                      
                        },
                      ),
                    ),
                  ),
                ],
              )
              
            ],
          ),
        ],
      ),
      bottomNavigationBar: custom_bottom_nav.BottomNavigationBar(),
    );
  }
}
