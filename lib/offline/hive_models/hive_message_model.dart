import 'package:hive/hive.dart';
import 'package:resq/features/chats/models/message_model.dart';

part 'hive_message_model.g.dart';

@HiveType(typeId: 0)
enum HiveMessageType {
  @HiveField(0)
  text,
  @HiveField(1)
  emergency,
  @HiveField(2)
  location,
  @HiveField(3)
  image,
}

@HiveType(typeId: 2)
class HiveMessage {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String receiverId;

  @HiveField(3)
  final String chatRoomId;

  @HiveField(4)
  final String content;

  @HiveField(5)
  final DateTime timestamp;

  @HiveField(6)
  final HiveMessageType type;

  @HiveField(7)
  final bool isRead;

  @HiveField(8)
  final bool isPending;

  HiveMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.chatRoomId,
    required this.content,
    required this.timestamp,
    this.type = HiveMessageType.text,
    this.isRead = false,
    this.isPending = false,
  });

  // Convert from your app's Message model
  factory HiveMessage.fromMessage(Message message, {bool isPending = false}) {
    return HiveMessage(
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      chatRoomId: message.chatRoomId,
      content: message.content,
      timestamp: message.timestamp,
      type: HiveMessageType.values[message.type.index],
      isRead: message.isRead,
      isPending: isPending,
    );
  }

  // Convert to your app's Message model
  Message toMessage() {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      chatRoomId: chatRoomId,
      content: content,
      timestamp: timestamp,
      type: MessageType.values[type.index],
      isRead: isRead,
    );
  }

  // Create a copy with updated fields
  HiveMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? chatRoomId,
    String? content,
    DateTime? timestamp,
    HiveMessageType? type,
    bool? isRead,
    bool? isPending,
  }) {
    return HiveMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      isPending: isPending ?? this.isPending,
    );
  }
}
