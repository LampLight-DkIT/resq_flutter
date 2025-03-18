// chat_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create or get existing chat room
  Future<ChatRoom> createChatRoom({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String? otherUserPhotoUrl,
  }) async {
    // Check if chat room already exists
    final querySnapshot = await _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUserId)
        .get();

    // Find rooms where the other user is a participant
    final existingRooms = querySnapshot.docs.where((doc) {
      final participants = List<String>.from(doc['participants']);
      return participants.contains(otherUserId);
    });

    if (existingRooms.isNotEmpty) {
      // Existing chat room found
      final doc = existingRooms.first;
      final data = doc.data();
      return ChatRoom(
        id: doc.id,
        currentUserId: currentUserId,
        otherUserId: otherUserId,
        otherUserName: data['otherUserName_$currentUserId'] ?? otherUserName,
        otherUserPhotoUrl:
            data['otherUserPhotoUrl_$currentUserId'] ?? otherUserPhotoUrl,
        lastMessage: data['lastMessage'],
        lastMessageTime: data['lastMessageTime'] != null
            ? (data['lastMessageTime'] is Timestamp
                ? (data['lastMessageTime'] as Timestamp).toDate()
                : DateTime.parse(data['lastMessageTime']))
            : null,
        unreadCount: data['unreadCount_$currentUserId'] ?? 0,
      );
    }

    // Create new chat room
    final chatRoomRef = _firestore.collection('chat_rooms').doc();
    final chatRoom = ChatRoom(
      id: chatRoomRef.id,
      currentUserId: currentUserId,
      otherUserId: otherUserId,
      otherUserName: otherUserName,
      otherUserPhotoUrl: otherUserPhotoUrl,
    );

    // Get current user's details
    final currentUserDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    final currentUserName = currentUserDoc.exists
        ? (currentUserDoc.data() as Map<String, dynamic>)['name'] ?? 'User'
        : 'User';
    final currentUserPhotoUrl = currentUserDoc.exists
        ? (currentUserDoc.data() as Map<String, dynamic>)['photoURL']
        : null;

    await chatRoomRef.set({
      'participants': [currentUserId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),

      // Store user names and photos for both users to see correctly
      'otherUserName_$currentUserId':
          otherUserName, // Name other user shows to current user
      'otherUserName_$otherUserId':
          currentUserName, // Name current user shows to other user
      'otherUserPhotoUrl_$currentUserId':
          otherUserPhotoUrl, // Photo other user shows to current user
      'otherUserPhotoUrl_$otherUserId':
          currentUserPhotoUrl, // Photo current user shows to other user

      // Initialize unread counters
      'unreadCount_$currentUserId': 0,
      'unreadCount_$otherUserId': 0,
    });

    return chatRoom;
  }

  // Send message
  Future<Message> sendMessage({
    required Message message,
    String? location,
  }) async {
    final messageRef = _firestore
        .collection('chat_rooms')
        .doc(message.chatRoomId)
        .collection('messages')
        .doc();

    final messageWithId = message.copyWith(id: messageRef.id);

    await messageRef.set(messageWithId.toMap());

    // Update last message in chat room
    await _firestore.collection('chat_rooms').doc(message.chatRoomId).update({
      'lastMessage': message.content,
      'lastMessageTime': message.timestamp.toIso8601String(),
      'unreadCount_${message.receiverId}': FieldValue.increment(1),
    });

    // Send emergency notification if it's an emergency message
    if (message.type == MessageType.emergency) {
      await _sendEmergencyNotification(messageWithId, location: location);
    }

    return messageWithId;
  }

  // Send emergency notification
  Future<void> _sendEmergencyNotification(Message message,
      {String? location}) async {
    // Get user information for the dashboard
    DocumentSnapshot senderDoc;
    DocumentSnapshot receiverDoc;

    try {
      senderDoc =
          await _firestore.collection('users').doc(message.senderId).get();
      receiverDoc =
          await _firestore.collection('users').doc(message.receiverId).get();
    } catch (e) {
      print('Error getting user data: $e');
      return;
    }

    // Create the emergency notification for the receiver
    await _firestore.collection('emergency_notifications').add({
      'senderId': message.senderId,
      'receiverId': message.receiverId,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'type': 'emergency_message',
      'chatRoomId': message.chatRoomId,
    });

    // Create a dashboard alert for the Next.js dashboard
    final dashboardAlert = {
      'senderId': message.senderId,
      'senderName': senderDoc.exists
          ? (senderDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
          : 'Unknown',
      'receiverId': message.receiverId,
      'receiverName': receiverDoc.exists
          ? (receiverDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
          : 'Unknown',
      'content': message.content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'chat_emergency',
      'chatRoomId': message.chatRoomId,
      'status': 'pending',
      'location': location ?? '',
      'isHandled': false,
      'handledBy': '',
      'handledAt': null,
    };

    await _firestore.collection('dashboard_alerts').add(dashboardAlert);
  }

  // Load chat rooms for a user
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        final otherUserId =
            participants.firstWhere((id) => id != userId, orElse: () => '');

        // Get the other user's details from the chat room data using the dynamic field format
        return ChatRoom(
          id: doc.id,
          currentUserId: userId,
          otherUserId: otherUserId,
          otherUserName: data['otherUserName_$userId'] ?? 'Unknown',
          otherUserPhotoUrl: data['otherUserPhotoUrl_$userId'],
          lastMessage: data['lastMessage'],
          lastMessageTime: data['lastMessageTime'] != null
              ? (data['lastMessageTime'] is Timestamp
                  ? (data['lastMessageTime'] as Timestamp).toDate()
                  : DateTime.parse(data['lastMessageTime']))
              : null,
          unreadCount: data['unreadCount_$userId'] ?? 0,
          isOnline: data['isOnline_$otherUserId'] ?? false,
        );
      }).toList();
    });
  }

  // Load messages for a specific chat room
  Stream<List<Message>> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    final batch = _firestore.batch();

    // Get unread messages sent to this user
    final unreadMessages = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    // Mark each message as read
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    // Reset unread count for this user
    batch.update(
      _firestore.collection('chat_rooms').doc(chatRoomId),
      {'unreadCount_$userId': 0},
    );

    await batch.commit();
  }

  // Sort chat rooms
  Future<List<ChatRoom>> sortChatRooms(
    List<ChatRoom> chatRooms,
    SortType sortType,
  ) async {
    switch (sortType) {
      case SortType.name:
        return chatRooms
          ..sort((a, b) => a.otherUserName.compareTo(b.otherUserName));
      case SortType.recent:
        return chatRooms
          ..sort((a, b) {
            if (a.lastMessageTime == null) return 1;
            if (b.lastMessageTime == null) return -1;
            return b.lastMessageTime!.compareTo(a.lastMessageTime!);
          });
    }
  }

  // Filter chat rooms
  List<ChatRoom> filterChatRooms(
    List<ChatRoom> chatRooms,
    String query,
  ) {
    return chatRooms.where((chatRoom) {
      return chatRoom.otherUserName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }
}
