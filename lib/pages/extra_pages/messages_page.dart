//the chat page

import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPages();
}

class _MessagesPages extends State<MessagesPage> {
  final TextEditingController _controller = TextEditingController();
  //list that contains messages
  List<Message> messages = [];
  bool _debugIsMe = true;

  void _handleSend() {
    String text = _controller.text.trim();
    if(text.isEmpty)return;

    setState(() {
      messages.insert(0, Message(text: text, isMe: _debugIsMe));
      _debugIsMe = !_debugIsMe;
    });
    _controller.clear();
  }

  @override 
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold( 
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [  
            Expanded(  
              child: ListView.builder(  
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];

                  //the whole row of the screen that the message gets
                  return Row(
                    mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      //the bubble itself
                      Container(  
                        padding: const EdgeInsets.only(right: 5, bottom: 2, left: 5),
                        constraints: BoxConstraints(  
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        //the text container (only has the text inside)
                        child: Container(  
                          decoration: BoxDecoration(
                            color: Color(0xFF8A2BE2), 
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Text(  
                            message.text,
                            style: const TextStyle(color: Colors.white, fontSize: 17),
                          )
                        )
                      ),
                    ]
                  );
                },
              )
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 5, right: 5),
                child: TextField(  
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(  
                    hintText: "Message...",
                    filled: true,
                    fillColor: const Color.fromARGB(82, 158, 158, 158),
                    contentPadding: const EdgeInsets.symmetric(  
                      horizontal: 16,
                      vertical: 10,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF8A2BE2)),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _handleSend();
                      }, // Calls your send function
                    ),
                    border: OutlineInputBorder(  
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(  
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(  
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  )
                ),
              ),
            ),
          ]
        )
      ),
    );
  }
}

//message object gets stores on the message list
class Message {
  final String text;
  final bool isMe; //to know which user send the message

  Message({required this.text, required this.isMe});
}