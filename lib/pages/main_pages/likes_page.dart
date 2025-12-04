import 'package:flutter/material.dart';

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
    );
  }
}