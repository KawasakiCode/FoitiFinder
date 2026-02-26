//The messages page
//Not the chat main page but where the actual messages are sent

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foitifinder/l10n/app_localizations.dart';
import 'package:foitifinder/models/matches_model.dart';
import 'package:foitifinder/models/message_model.dart';
import 'package:foitifinder/providers/profile_provider.dart';
import 'package:foitifinder/services/api_services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

class MessagesPage extends StatefulWidget {
  final MatchModel match;

  const MessagesPage({super.key, required this.match});

  @override
  State<MessagesPage> createState() => _MessagesPages();
}

class _MessagesPages extends State<MessagesPage> {
  late WebSocketChannel _channel;
  final TextEditingController _controller = TextEditingController();
  late final texts = AppLocalizations.of(context)!;
  List<MessageModel> messages = [];

  @override
  initState() {
    super.initState();
    _loadMessages();
    //where the connection happens
    _channel = WebSocketChannel.connect(
      Uri.parse(
        'ws://192.168.1.2:8000/ws/chat/${Provider.of<ProfileProvider>(context, listen: false).currentUser!.id!}',
      ),
    );

    //get the json from the socket and convert it to add to messages
    _channel.stream.listen((incomingData) {
      final data = jsonDecode(incomingData);
      if(!mounted)return;
      final MessageModel decodedMessage = MessageModel.fromJson(data, Provider.of<ProfileProvider>(context, listen: false).currentUser!.id!);
      setState(() {
        messages.insert(0, decodedMessage);
      });
    });
    _loadMessages();
  }

  @override
  dispose() {
    super.dispose();
  }

  //Using the users id and the match id we can find all messages
  //between the 2 users in the dm and we grab them with the api
  Future<void> _loadMessages() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final myUserId = Provider.of<ProfileProvider>(
      context,
      listen: false,
    ).currentUser!.id!;

    final history = await ApiService.getMessages(
      uid,
      myUserId,
      widget.match.matchId,
    );

    if (mounted) {
      setState(() {
        messages = history;
      });
    }
  }

  void _handleSend() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final messagePayload = {"match_id": widget.match.matchId, "to_user": widget.match.userBid, "content": text};

    //send the json message to the socket (for the other user to receive)
    _channel.sink.add(jsonEncode(messagePayload));

    final message = MessageModel(
      matchId: widget.match.matchId,
      senderId: Provider.of<ProfileProvider>(
        context,
        listen: false,
      ).currentUser!.id!,
      content: text,
      isMine: true,
    );

    setState(() {
      messages.insert(0, message);
    });

    bool success = await ApiService.postMessage(
      uid: FirebaseAuth.instance.currentUser!.uid,
      matchId: widget.match.matchId,
      content: text);

    if (!success) {
      setState(() {
        messages.remove(message);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(texts.failedToSendMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,
          title: Text(profileProvider.currentUser!.username),
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: Colors.grey, height: 1.0),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              //reverse: true makes it so the most recent message is at the bottom
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];

                  //the whole row of the screen that the message gets
                  return Row(
                    mainAxisAlignment: message.isMine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      //the bubble itself
                      Container(
                        padding: const EdgeInsets.only(
                          right: 5,
                          bottom: 2,
                          left: 5,
                        ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            //The TextField where messages are written
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 5, right: 5, bottom: 5),
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: text.message,
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
                      },
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
