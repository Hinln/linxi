import 'user_model.dart';

class Conversation {
  final String id;
  final User otherUser;
  final String? lastMessageContent;
  final DateTime? lastMessageTime;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessageContent,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json, String currentUserId) {
    // Determine other user
    final user1 = User.fromJson(json['user1'] ?? {});
    final user2 = User.fromJson(json['user2'] ?? {});
    final other = user1.id == currentUserId ? user2 : user1;

    return Conversation(
      id: json['id']?.toString() ?? '',
      otherUser: other,
      lastMessageContent: json['lastMessageContent'],
      lastMessageTime: DateTime.tryParse(json['lastMessageTime'] ?? ''),
      unreadCount: user1.id == currentUserId ? (json['unreadCount1'] ?? 0) : (json['unreadCount2'] ?? 0),
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String content;
  final String type; // TEXT, IMAGE, SYSTEM
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = 'TEXT',
    required this.createdAt,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'TEXT',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }
}
