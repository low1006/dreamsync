class ChatMessageModel{
  final String text;
  final bool isUser;

  ChatMessageModel({
    required this.text,
    required this.isUser,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      text: map['text']?? '',
      isUser: map['is_user']?? false,
    );
  }

}