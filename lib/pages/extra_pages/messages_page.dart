

import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPages();
}

class _MessagesPages extends State<MessagesPage> {
  @override 
  Widget build(BuildContext context) {
    return Scaffold( 
      appBar: AppBar(  
        automaticallyImplyLeading: true,
        title: Text("Username"),
        elevation: 0,
        bottom: PreferredSize(  
          preferredSize: const Size.fromHeight(1.0),
          child: Container(  
            color: Colors.grey,
            height: 1.0,
          )
        )
      ),
      body: Column(  
        children: [  
          Expanded(  
            child: ListView.builder(  
              reverse: true,
              itemCount: 10,
              itemBuilder: (context, _) {
                
              },
            )
          )
        ]
      )
    );
  }
}