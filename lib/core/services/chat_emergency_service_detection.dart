import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Emergency keywords that will trigger alerts
  final List<String> _emergencyKeywords = [
    'emergency',
    'help',
    'sos',
    'urgent',
    'danger',
    'accident',
    'injured',
    'trapped',
    'hurt',
    '911'
  ];

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a chat room between two users
  Future<String> createChatRoom(String otherUserId) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    // Sort IDs to ensure consistent chat room ID
    List<String> ids = [currentUserId!, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    // Check if chat room already exists
    DocumentSnapshot chatRoom =
        await _firestore.collection('chatRooms').doc(chatRoomId).get();

    if (!chatRoom.exists) {
      // Create new chat room
      await _firestore.collection('chatRooms').doc(chatRoomId).set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': null,
        'lastMessageTime': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return chatRoomId;
  }

  // Send a message
  Future<void> sendMessage({
    required String chatRoomId,
    required String text,
    required String recipientId,
    MessageType type = MessageType.text,
    File? attachment,
  }) async {
    if (currentUserId == null) throw Exception('User not authenticated');

    // Check if message contains emergency keywords
    bool isEmergency = _checkForEmergency(text);

    String? attachmentUrl;
    if (attachment != null && type != MessageType.text) {
      attachmentUrl = await _uploadAttachment(attachment, chatRoomId);
    }

    // Create message document
    DocumentReference messageRef = _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc();

    // Message data
    Map<String, dynamic> messageData = {
      'messageId': messageRef.id,
      'text': text,
      'senderId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type.toString().split('.').last,
      'isEmergency': isEmergency,
      'read': false,
    };

    if (attachmentUrl != null) {
      messageData['attachmentUrl'] = attachmentUrl;
    }

    // Save message
    await messageRef.set(messageData);

    // Update chat room with last message info
    await _firestore.collection('chatRooms').doc(chatRoomId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
    });

    // If emergency message, trigger alerts
    if (isEmergency) {
      await _triggerEmergencyAlert(recipientId, text, chatRoomId);
    }
  }

  // Check if message contains emergency keywords
  bool _checkForEmergency(String message) {
    String lowerMessage = message.toLowerCase();
    return _emergencyKeywords.any((keyword) => lowerMessage.contains(keyword));
  }

  // Trigger emergency alerts
  Future<void> _triggerEmergencyAlert(
      String recipientId, String message, String chatRoomId) async {
    if (currentUserId == null) return;

    // Get sender details
    DocumentSnapshot senderDoc =
        await _firestore.collection('users').doc(currentUserId).get();

    // Create emergency alert
    await _firestore.collection('emergencyAlerts').add({
      'senderId': currentUserId,
      'senderName': senderDoc.get('name') ?? 'Unknown',
      'recipientId': recipientId,
      'message': message,
      'chatRoomId': chatRoomId,
      'timestamp': FieldValue.serverTimestamp(),
      'location': senderDoc.get('lastLocation'),
      'status': 'active',
    });

    // Also notify emergency contacts of the sender
    QuerySnapshot emergencyContacts = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('emergencyContacts')
        .get();

    for (var contact in emergencyContacts.docs) {
      String contactId = contact.get('userId');

      // Create notification for emergency contact
      await _firestore.collection('emergencyNotifications').add({
        'userId': contactId,
        'senderId': currentUserId,
        'senderName': senderDoc.get('name') ?? 'Unknown',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'location': senderDoc.get('lastLocation'),
        'status': 'unread',
      });
    }
  }

  // Upload attachment to Firebase Storage
  Future<String> _uploadAttachment(File file, String chatRoomId) async {
    String fileName = const Uuid().v4();
    Reference storageRef = _storage.ref().child('chats/$chatRoomId/$fileName');

    await storageRef.putFile(file);
    return await storageRef.getDownloadURL();
  }

  // Get all messages for a chat room
  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromMap(doc.data());
      }).toList();
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId) async {
    if (currentUserId == null) return;

    QuerySnapshot unreadMessages = await _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    WriteBatch batch = _firestore.batch();

    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }

  // Get all chat rooms for current user
  Stream<List<ChatRoom>> getChatRooms() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<ChatRoom> chatRooms = [];

      for (var doc in snapshot.docs) {
        ChatRoom chatRoom = await _processChatRoom(doc);
        chatRooms.add(chatRoom);
      }

      // Sort by last message time
      chatRooms.sort((a, b) {
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      return chatRooms;
    });
  }

  // Process chat room data
  Future<ChatRoom> _processChatRoom(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<dynamic> participants = data['participants'];

    // Get the other participant
    String otherUserId = participants.firstWhere((id) => id != currentUserId);

    // Get user details
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(otherUserId).get();
    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

    // Count unread messages
    QuerySnapshot unreadSnapshot = await _firestore
        .collection('chatRooms')
        .doc(doc.id)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('read', isEqualTo: false)
        .get();

    int unreadCount = unreadSnapshot.docs.length;

    return ChatRoom(
      id: doc.id,
      otherUserId: otherUserId,
      otherUserName: userData['name'] ?? 'Unknown',
      otherUserPhotoUrl: userData['photoUrl'],
      lastMessage: data['lastMessage'],
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      unreadCount: unreadCount,
      isOnline: userData['isOnline'] ?? false,
    );
  }
}

class ChatRoom {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  ChatRoom({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String? attachmentUrl;
  final bool isEmergency;
  final bool read;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.type,
    this.attachmentUrl,
    this.isEmergency = false,
    this.read = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['messageId'],
      senderId: map['senderId'],
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: _getMessageTypeFromString(map['type'] ?? 'text'),
      attachmentUrl: map['attachmentUrl'],
      isEmergency: map['isEmergency'] ?? false,
      read: map['read'] ?? false,
    );
  }
}

MessageType _getMessageTypeFromString(String type) {
  switch (type) {
    case 'image':
      return MessageType.image;
    case 'audio':
      return MessageType.audio;
    case 'location':
      return MessageType.location;
    case 'document':
      return MessageType.document;
    default:
      return MessageType.text;
  }
}

enum MessageType { text, image, audio, location, document }
