import 'package:equatable/equatable.dart';

enum MessageType {
  text,
  emergency,
  location,
  image,
}

class Message extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String chatRoomId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.chatRoomId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
  });

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? chatRoomId,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatRoomId': chatRoomId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'isRead': isRead,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      chatRoomId: map['chatRoomId'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      type: MessageType.values[map['type']],
      isRead: map['isRead'] ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [id, senderId, receiverId, chatRoomId, content, timestamp, type, isRead];
}
