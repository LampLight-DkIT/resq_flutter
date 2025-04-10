import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Enum representing different types of messages
enum MessageType { text, image, video, audio, document, location, emergency }

/// Enum representing message status
enum MessageStatus { sending, sent, delivered, read, failed }

/// Class representing a chat message with comprehensive details
class Message extends Equatable {
  /// Unique identifier for the message
  final String id;

  /// ID of the user sending the message
  final String senderId;

  /// ID of the user receiving the message
  final String receiverId;

  /// ID of the chat room this message belongs to
  final String chatRoomId;

  /// Main content of the message
  final String content;

  /// Timestamp of when the message was sent
  final DateTime timestamp;

  /// Type of the message (text, image, etc.)
  final MessageType type;

  /// Whether the message has been read
  final bool isRead;

  /// URL of the attachment (if applicable)
  final String? attachmentUrl;

  /// Additional metadata for the attachment
  final Map<String, dynamic>? attachmentMetadata;

  /// Current status of the message
  final MessageStatus status;

  /// Location data for location-based messages
  final String? locationData;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.chatRoomId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentMetadata,
    this.status = MessageStatus.sent,
    this.locationData,
  });

  /// Convert message to a map for Firestore storage
  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'chatRoomId': chatRoomId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'attachmentUrl': attachmentUrl,
      'attachmentMetadata': attachmentMetadata,
      'status': status.index,
    };

    map['typeString'] = type.toString().split('.').last;

    // Special handling for location messages to avoid the range error
    if (type == MessageType.location) {
      // Store location messages as text (type 0) with an isLocation flag
      map['type'] = 0; // Use 0 (text) instead of 5 (location)
      map['isLocation'] = true; // Add flag to identify as location message

      // Store location data in appropriate fields
      if (content.contains(',')) {
        map['location'] = content;
        map['locationData'] = content;
      }
    } else {
      // For all other message types, store the type normally
      map['type'] = type.index;
    }

    // Add locationData if provided separately
    if (locationData != null && type != MessageType.location) {
      map['locationData'] = locationData;
    }

    return map;
  }

  /// Create a message from a Firestore document
  factory Message.fromMap(Map<String, dynamic> map) {
    // Check if this is a location message with isLocation flag
    bool isLocation = map['isLocation'] == true;

    // Safe type parsing with bounds checking
    int typeIndex = 0;
    if (map['type'] != null) {
      if (isLocation) {
        // Force location type for messages with isLocation flag
        typeIndex = MessageType.location.index;
      } else if (map['type'] is int) {
        typeIndex =
            (map['type'] as int).clamp(0, MessageType.values.length - 1);
      } else {
        int? parsed = int.tryParse(map['type'].toString());
        typeIndex =
            parsed != null ? parsed.clamp(0, MessageType.values.length - 1) : 0;
      }
    }

    // Safe status parsing with bounds checking
    int statusIndex = 0;
    if (map['status'] != null) {
      if (map['status'] is int) {
        statusIndex =
            (map['status'] as int).clamp(0, MessageStatus.values.length - 1);
      } else {
        int? parsed = int.tryParse(map['status'].toString());
        statusIndex = parsed != null
            ? parsed.clamp(0, MessageStatus.values.length - 1)
            : 0;
      }
    }

    // Handle various formats of location data
    String? locationData = map['locationData'];
    if (locationData == null) {
      // Try to extract from 'location' field
      if (map['location'] != null) {
        if (map['location'] is Map) {
          // Handle GeoPoint or Map format
          final locationMap = map['location'] as Map;
          if (locationMap.containsKey('latitude') &&
              locationMap.containsKey('longitude')) {
            locationData =
                '${locationMap['latitude']},${locationMap['longitude']}';
          }
        } else if (map['location'] is String) {
          // Handle string format
          locationData = map['location'] as String;
        }
      }
    }

    return Message(
      id: map['id'] ?? map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      chatRoomId: map['chatRoomId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.parse(map['timestamp'].toString()))
          : DateTime.now(),
      type: MessageType.values[typeIndex],
      isRead: map['isRead'] ?? false,
      attachmentUrl: map['attachmentUrl'],
      attachmentMetadata: map['attachmentMetadata'] is Map
          ? Map<String, dynamic>.from(map['attachmentMetadata'] ?? {})
          : null,
      status: MessageStatus.values[statusIndex],
      locationData: locationData,
    );
  }

  /// Create a copy of the message with optional field updates
  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? chatRoomId,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    bool? isRead,
    String? attachmentUrl,
    Map<String, dynamic>? attachmentMetadata,
    MessageStatus? status,
    String? locationData,
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
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentMetadata: attachmentMetadata ?? this.attachmentMetadata,
      status: status ?? this.status,
      locationData: locationData ?? this.locationData,
    );
  }

  /// Helper method to create a message with attachment
  factory Message.withAttachment({
    required String id,
    required String senderId,
    required String receiverId,
    required String chatRoomId,
    required String content,
    required MessageType type,
    required String attachmentUrl,
    Map<String, dynamic>? attachmentMetadata,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      chatRoomId: chatRoomId,
      content: content,
      timestamp: DateTime.now(),
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentMetadata: attachmentMetadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        senderId,
        receiverId,
        chatRoomId,
        content,
        timestamp,
        type,
        isRead,
        attachmentUrl,
        attachmentMetadata,
        status,
        locationData,
      ];

  /// Get a display string for the message type
  String get typeDisplay {
    switch (type) {
      case MessageType.image:
        return 'Image';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Audio';
      case MessageType.document:
        return 'Document';
      case MessageType.location:
        return 'Location';
      case MessageType.emergency:
        return 'Emergency';
      default:
        return 'Text';
    }
  }

  // Helper method to get safe message type
  static MessageType getSafeMessageType(int? index) {
    if (index == null || index < 0 || index >= MessageType.values.length) {
      return MessageType.text; // Default to text
    }
    return MessageType.values[index];
  }

  // Helper method to get safe message status
  static MessageStatus getSafeMessageStatus(int? index) {
    if (index == null || index < 0 || index >= MessageStatus.values.length) {
      return MessageStatus.sending; // Default to sending
    }
    return MessageStatus.values[index];
  }

  @override
  String toString() {
    return 'Message($id, $senderId, $type, $content)';
  }
}
