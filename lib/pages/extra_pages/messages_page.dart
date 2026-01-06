//the chat page

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/message_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class MessagesPage extends StatefulWidget {
  final MatchModel match;

  const MessagesPage({super.key, required this.match});

  @override
  State<MessagesPage> createState() => _MessagesPages();
}

class _MessagesPages extends State<MessagesPage> {
  final TextEditingController _controller = TextEditingController();
  //list that contains messages
  List<MessageModel> messages = [];
  //timer to periodically check for new messages 
  Timer? _timer;

  @override
  initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages();
    });
  }

  @override 
  dispose() {
    //stop the timer from working if the user leaves chat page (to be changed later)
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final myUserId = Provider.of<ProfileProvider>(context, listen: false).currentUser!.id!;

    final history = await ApiService.getMessages(uid, myUserId, widget.match.matchId);

    if(mounted) {
      setState(() {
        messages = history;
      });
    }
  }

  void _handleSend() async {
    String text = _controller.text.trim();
    if(text.isEmpty)return;

    _controller.clear();
    //keep a temporary instance of the last message sent to delete it if the api fails to upload it to the db
    final tempMessage = MessageModel(  
      matchId: widget.match.matchId,
      senderId: Provider.of<ProfileProvider>(context, listen: false).currentUser!.id!,
      content: text,
      isMine: true,
    );

    setState(() {
      messages.insert(0, tempMessage);
    });

    bool success = await ApiService.postMessage(
      uid: FirebaseAuth.instance.currentUser!.uid, 
      matchId: widget.match.matchId, 
      content: text);
   
   if(!success) {
    setState(() {
      messages.remove(tempMessage);
    });

    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar( 
      const SnackBar(content: Text("Failed to send message"))
    );
   }
  }

  @override 
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold( 
        appBar: AppBar(  
          automaticallyImplyLeading: true,
          title: Text(profileProvider.currentUser!.username),
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
                    mainAxisAlignment: message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                            message.content,
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
                      key: UniqueKey(),
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