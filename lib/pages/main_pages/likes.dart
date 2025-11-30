import 'package:flutter/material.dart';
import 'package:foitifinder/widgets/bottom_navigation_bar.dart' as custom_bottom_nav;

class LikesPage extends StatefulWidget{
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPage();
}

class _LikesPage extends State<LikesPage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(  
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text("FoitiFinder"),
      ),
      bottomNavigationBar: SafeArea(
        child: custom_bottom_nav.BottomNavigationBar(),
      )
    );
  }
}