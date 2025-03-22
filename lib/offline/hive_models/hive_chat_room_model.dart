import 'package:hive/hive.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';

part 'hive_chat_room_model.g.dart';

@HiveType(typeId: 1)
class HiveChatRoom {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String currentUserId;

  @HiveField(2)
  final String otherUserId;

  @HiveField(3)
  final String otherUserName;

  @HiveField(4)
  final String? otherUserPhotoUrl;

  @HiveField(5)
  final String? lastMessage;

  @HiveField(6)
  final DateTime? lastMessageTime;

  @HiveField(7)
  final bool isOnline;

  @HiveField(8)
  final int unreadCount;

  HiveChatRoom({
    required this.id,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.isOnline = false,
    this.unreadCount = 0,
  });

  // Convert from your app's ChatRoom model
  factory HiveChatRoom.fromChatRoom(ChatRoom chatRoom) {
    return HiveChatRoom(
      id: chatRoom.id,
      currentUserId: chatRoom.currentUserId,
      otherUserId: chatRoom.otherUserId,
      otherUserName: chatRoom.otherUserName,
      otherUserPhotoUrl: chatRoom.otherUserPhotoUrl,
      lastMessage: chatRoom.lastMessage,
      lastMessageTime: chatRoom.lastMessageTime,
      isOnline: chatRoom.isOnline,
      unreadCount: chatRoom.unreadCount,
    );
  }

  // Convert to your app's ChatRoom model
  ChatRoom toChatRoom() {
    return ChatRoom(
      id: id,
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserPhotoUrl: otherUserPhotoUrl,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      isOnline: isOnline,
      unreadCount: unreadCount,
    );
  }

  // Create a copy with updated fields
  HiveChatRoom copyWith({
    String? id,
    String? currentUserId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isOnline,
    int? unreadCount,
  }) {
    return HiveChatRoom(
      id: id ?? this.id,
      currentUserId: currentUserId ?? this.currentUserId,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhotoUrl: otherUserPhotoUrl ?? this.otherUserPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
