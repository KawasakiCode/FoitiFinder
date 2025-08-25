import 'package:flutter/material.dart';
import '../widgets/bottom_navigation_bar.dart' as custom_bottom_nav;

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
        automaticallyImplyLeading: false,
        title: Text("FoitiFinder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      bottomNavigationBar: SafeArea(
        child: custom_bottom_nav.BottomNavigationBar(),
      )
    );
  }
}