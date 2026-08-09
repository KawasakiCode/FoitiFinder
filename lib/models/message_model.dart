//Grabs data of messages from a specific conversation
//Used to grab messages from a convo and show them inside the dm

//isMine is a flag used to see what messages are from the user's side 
//to display them in the right side of the screen

class MessageModel {
  final int matchId;
  final int senderId;
  final String content;

  final bool isMine;

  MessageModel({
    required this.matchId,
    required this.senderId,
    required this.content,
    this.isMine = false,
  });
  
  factory MessageModel.fromJson(Map<String, dynamic> json, int myUserId) {
    return MessageModel(  
      matchId: json['match_id'],
      senderId: json['sender'],
      content: json['content'],
      isMine: json['sender'] == myUserId
    );
  }
}