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