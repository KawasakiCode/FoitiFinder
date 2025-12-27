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
      body: SingleChildScrollView(  
        child: Column(  
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              itemCount: 8,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemBuilder: (_, _) => Material(
                color: Colors.red,
                borderRadius: BorderRadius.circular(15),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  splashColor: Colors.white24,
                  highlightColor: Colors.white10,
                  onTap: () {},
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 5),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            "Username, Age",
                            style: TextStyle(
                              fontSize: 18,
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
          ]
        )
      )
    );
  }
}