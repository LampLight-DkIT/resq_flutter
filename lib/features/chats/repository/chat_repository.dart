// chat_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resq/core/services/app_initialization_service.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/offline/chat_cache/chat_cache_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatCacheRepository? _cacheRepository;

  ChatRepository({ChatCacheRepository? cacheRepository})
      : _cacheRepository =
            cacheRepository ?? AppInitializationService().chatCacheRepository;

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

  // Send message with caching support
  Future<Message> sendMessage({
    required Message message,
    String? location,
    bool isOffline = false,
  }) async {
    // Check if this message matches the trigger phrase
    bool isTrigger = await _checkTriggerPhrase(message);
    Message messageToSend = message;

    // If it's a trigger, convert to emergency message
    if (isTrigger) {
      messageToSend = message.copyWith(type: MessageType.emergency);
      // For trigger phrases, get location if needed
      if (location == null) {
        location = await _getEmergencyLocation();
      }
    }

    // Create a copy with a temporary ID if needed
    final String tempId = messageToSend.id.isEmpty
        ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
        : messageToSend.id;
    final localMessage = messageToSend.copyWith(id: tempId);

    // Handle optimistic UI updates with cache if available
    if (_cacheRepository != null) {
      await _cacheRepository!.addMessageToCache(localMessage);

      // If offline, add to pending queue
      if (isOffline) {
        await _cacheRepository!.addToPendingQueue(localMessage);
        return localMessage;
      }
    }

    try {
      // Real Firestore operation
      final messageRef = _firestore
          .collection('chat_rooms')
          .doc(messageToSend.chatRoomId)
          .collection('messages')
          .doc();

      final messageWithId = localMessage.copyWith(id: messageRef.id);

      await messageRef.set(messageWithId.toMap());

      // Update last message in chat room
      await _firestore
          .collection('chat_rooms')
          .doc(messageToSend.chatRoomId)
          .update({
        'lastMessage': messageToSend.content,
        'lastMessageTime': messageToSend.timestamp.toIso8601String(),
        'unreadCount_${messageToSend.receiverId}': FieldValue.increment(1),
      });

      // Send emergency notification if it's an emergency message
      if (messageToSend.type == MessageType.emergency) {
        await _sendEmergencyNotification(messageWithId, location: location);
      }

      // If we used a temporary ID for the cache, update it
      if (_cacheRepository != null && localMessage.id.startsWith('temp_')) {
        await _cacheRepository!.addMessageToCache(messageWithId);
      }

      return messageWithId;
    } catch (e) {
      // Keep optimistic message in cache on error
      return localMessage;
    }
  }

  Future<String?> _getEmergencyLocation() async {
    try {
      // This would typically integrate with your existing location service
      // Using same approach as in your other emergency methods
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        ),
      );
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      print('Could not get location for trigger alert: $e');
      return null;
    }
  }

  // Send emergency notification
  Future<void> _sendEmergencyNotification(Message message,
      {String? location}) async {
    // Existing implementation...
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

  // Load chat rooms for a user - with caching
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    // If caching is enabled, use a custom stream with cache-first approach
    if (_cacheRepository != null) {
      final controller = StreamController<List<ChatRoom>>();

      // Immediately emit cached data
      Future<void> emitCachedData() async {
        final cachedRooms = _cacheRepository!.getCachedChatRooms(userId);
        if (cachedRooms.isNotEmpty) {
          controller.add(cachedRooms);
        }
      }

      // Then listen to Firestore for latest data
      void listenToFirestore() {
        final subscription = _firestore
            .collection('chat_rooms')
            .where('participants', arrayContains: userId)
            .snapshots()
            .listen(
          (snapshot) {
            final chatRooms = snapshot.docs.map((doc) {
              final data = doc.data();
              final participants = List<String>.from(data['participants']);
              final otherUserId = participants.firstWhere((id) => id != userId,
                  orElse: () => '');

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

            // Update cache
            _cacheRepository!.cacheChatRooms(chatRooms, userId);

            // Emit updated data
            controller.add(chatRooms);
          },
          onError: (error) {
            controller.addError(error);
          },
        );

        // Handle controller close
        controller.onCancel = () {
          subscription.cancel();
        };
      }

      // Execute cache-first strategy
      emitCachedData().then((_) => listenToFirestore());

      return controller.stream;
    }

    // If no cache, use original implementation
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

  // Load messages for a specific chat room - with caching
  Stream<List<Message>> getMessages(String chatRoomId) {
    // If caching is enabled, use a custom stream with cache-first approach
    if (_cacheRepository != null) {
      final controller = StreamController<List<Message>>();

      // Immediately emit cached messages
      Future<void> emitCachedMessages() async {
        final cachedMessages = _cacheRepository!.getCachedMessages(chatRoomId);
        if (cachedMessages.isNotEmpty) {
          controller.add(cachedMessages);
        }
      }

      // Then listen to Firestore
      void listenToFirestore() {
        final subscription = _firestore
            .collection('chat_rooms')
            .doc(chatRoomId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots()
            .listen(
          (snapshot) {
            final messages = snapshot.docs
                .map((doc) => Message.fromMap(doc.data()))
                .toList();

            // Update cache
            _cacheRepository!.cacheMessages(chatRoomId, messages);

            // Emit updated messages
            controller.add(messages);
          },
          onError: (error) {
            controller.addError(error);
          },
        );

        controller.onCancel = () {
          subscription.cancel();
        };
      }

      // Execute strategy
      emitCachedMessages().then((_) => listenToFirestore());

      return controller.stream;
    }

    // If no cache, use original implementation
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  // Process pending messages
  Future<void> processPendingMessages() async {
    if (_cacheRepository == null) return;

    final pendingMessages = _cacheRepository!.getPendingMessages();

    for (final message in pendingMessages) {
      try {
        await sendMessage(message: message);

        // If successful, remove from pending queue
        await _cacheRepository!.removeFromPendingQueue(message.id);
      } catch (e) {
        print('Failed to send pending message: ${e.toString()}');
      }
    }
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

    // Update cache if available
    if (_cacheRepository != null) {
      final messages = _cacheRepository!.getCachedMessages(chatRoomId);
      final updatedMessages = messages.map((msg) {
        if (msg.receiverId == userId && !msg.isRead) {
          return msg.copyWith(isRead: true);
        }
        return msg;
      }).toList();

      await _cacheRepository!.cacheMessages(chatRoomId, updatedMessages);
    }
  }

  // Sort chat rooms - now entirely in memory
  Future<List<ChatRoom>> sortChatRooms(
    List<ChatRoom> chatRooms,
    SortType sortType,
  ) async {
    final sortedRooms = List<ChatRoom>.from(chatRooms);

    switch (sortType) {
      case SortType.name:
        sortedRooms.sort((a, b) => a.otherUserName.compareTo(b.otherUserName));
        break;
      case SortType.recent:
        sortedRooms.sort((a, b) {
          if (a.lastMessageTime == null) return 1;
          if (b.lastMessageTime == null) return -1;
          return b.lastMessageTime!.compareTo(a.lastMessageTime!);
        });
        break;
    }

    return sortedRooms;
  }

  // Filter chat rooms - now entirely in memory
  List<ChatRoom> filterChatRooms(
    List<ChatRoom> chatRooms,
    String query,
  ) {
    if (query.isEmpty) return chatRooms;

    return chatRooms.where((chatRoom) {
      return chatRoom.otherUserName.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  Future<ChatRoom?> getChatRoom(String chatRoomId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(chatRoomId)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        return ChatRoom.fromMap(snapshot.data()!, snapshot.id);
      }

      return null;
    } catch (e) {
      print('Error getting chat room: $e');
      return null;
    }
  }

  // Add this method to your existing ChatRepository class
  Future<bool> _checkTriggerPhrase(Message message) async {
    try {
      // Don't check if it's already an emergency message
      if (message.type == MessageType.emergency) {
        return false;
      }

      // Don't check triggers for messages not sent by the current user
      final currentUser = _auth.currentUser;
      if (currentUser == null || message.senderId != currentUser.uid) {
        return false;
      }

      // Get the trigger phrase from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final triggerPhrase = prefs.getString('alert_trigger_phrase');

      // If no trigger phrase is set, or it doesn't match, return false
      if (triggerPhrase == null || triggerPhrase.isEmpty) {
        return false;
      }

      // Check if the message content matches the trigger phrase exactly
      return message.content.trim() == triggerPhrase.trim();
    } catch (e) {
      print('Error checking trigger phrase: $e');
      return false;
    }
  }
}
