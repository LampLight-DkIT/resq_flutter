import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType {
  chatEmergency,
  manualAlert,
}

class DashboardAlert {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String content;
  final DateTime timestamp;
  final AlertType type;
  final String chatRoomId;
  final String status;
  final String location;
  final bool isHandled;
  final String handledBy;
  final DateTime? handledAt;

  DashboardAlert({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.content,
    required this.timestamp,
    required this.type,
    required this.chatRoomId,
    required this.status,
    required this.location,
    this.isHandled = false,
    this.handledBy = '',
    this.handledAt,
  });

  // Create from a map (e.g., from Firestore)
  factory DashboardAlert.fromMap(Map<String, dynamic> map, String docId) {
    return DashboardAlert(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Unknown',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? 'Unknown',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(map['timestamp']))
          : DateTime.now(),
      type: map['type'] == 'chat_emergency'
          ? AlertType.chatEmergency
          : AlertType.manualAlert,
      chatRoomId: map['chatRoomId'] ?? '',
      status: map['status'] ?? 'pending',
      location: map['location'] ?? '',
      isHandled: map['isHandled'] ?? false,
      handledBy: map['handledBy'] ?? '',
      handledAt: map['handledAt'] != null
          ? (map['handledAt'] is Timestamp
              ? (map['handledAt'] as Timestamp).toDate()
              : DateTime.parse(map['handledAt']))
          : null,
    );
  }

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'type':
          type == AlertType.chatEmergency ? 'chat_emergency' : 'manual_alert',
      'chatRoomId': chatRoomId,
      'status': status,
      'location': location,
      'isHandled': isHandled,
      'handledBy': handledBy,
      'handledAt': handledAt?.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  DashboardAlert copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    String? content,
    DateTime? timestamp,
    AlertType? type,
    String? chatRoomId,
    String? status,
    String? location,
    bool? isHandled,
    String? handledBy,
    DateTime? handledAt,
  }) {
    return DashboardAlert(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      status: status ?? this.status,
      location: location ?? this.location,
      isHandled: isHandled ?? this.isHandled,
      handledBy: handledBy ?? this.handledBy,
      handledAt: handledAt ?? this.handledAt,
    );
  }
}
