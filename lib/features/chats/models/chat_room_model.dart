import 'package:equatable/equatable.dart';

class ChatRoom extends Equatable {
  final String id;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isOnline;
  final int unreadCount;

  const ChatRoom({
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

  ChatRoom copyWith({
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
    return ChatRoom(
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currentUserId': currentUserId,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPhotoUrl': otherUserPhotoUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'isOnline': isOnline,
      'unreadCount': unreadCount,
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    return ChatRoom(
      id: map['id'],
      currentUserId: map['currentUserId'],
      otherUserId: map['otherUserId'],
      otherUserName: map['otherUserName'],
      otherUserPhotoUrl: map['otherUserPhotoUrl'],
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.parse(map['lastMessageTime'])
          : null,
      isOnline: map['isOnline'] ?? false,
      unreadCount: map['unreadCount'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        currentUserId,
        otherUserId,
        otherUserName,
        otherUserPhotoUrl,
        lastMessage,
        lastMessageTime,
        isOnline,
        unreadCount
      ];
}
