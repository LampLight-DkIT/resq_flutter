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

  // Helper method to get a user-friendly message preview
  String _getMessagePreview(Message message) {
    switch (message.type) {
      case MessageType.text:
      case MessageType.emergency:
        return message.content;
      case MessageType.image:
        return '📷 Image';
      case MessageType.audio:
        return '🔊 Audio message';
      case MessageType.document:
        if (message.content.contains('|')) {
          final parts = message.content.split('|');
          if (parts.length > 1) {
            return '📄 ${parts[1]}';
          }
        }
        return '📄 Document';
      case MessageType.location:
        return '📍 Location shared';
      default:
        return 'New message';
    }
  }

  Future<String?> _getEmergencyLocation() async {
    try {
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

  // SEND MESSGAE FROM CHAT PAGE
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
      location ??= await _getEmergencyLocation();
    }

    // Create a copy with a temporary ID if needed
    final String tempId = messageToSend.id.isEmpty
        ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
        : messageToSend.id;
    final localMessage = messageToSend.copyWith(id: tempId);

    // Add detailed logging
    print("DEBUG: Starting message send process");
    print("DEBUG: Message type: ${messageToSend.type}");
    print("DEBUG: Message content: ${messageToSend.content}");
    print("DEBUG: isOffline: $isOffline");

    // Handle optimistic UI updates with cache if available
    if (_cacheRepository != null) {
      await _cacheRepository.addMessageToCache(localMessage);

      // If offline, add to pending queue
      if (isOffline) {
        await _cacheRepository.addToPendingQueue(localMessage);
        return localMessage;
      }
    }

    try {
      // Prepare the message data for Firestore
      final messageRef = _firestore
          .collection('chat_rooms')
          .doc(messageToSend.chatRoomId)
          .collection('messages')
          .doc();

      final messageWithId = localMessage.copyWith(id: messageRef.id);

      // Create message data map for Firestore
      Map<String, dynamic> messageData = {
        'messageId': messageRef.id,
        'senderId': messageWithId.senderId,
        'receiverId': messageWithId.receiverId,
        'chatRoomId': messageWithId.chatRoomId,
        'content': messageWithId.content,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': messageWithId.isRead,
      };

      // Handle special case for location messages - this fixes the index error
      if (messageWithId.type == MessageType.location) {
        // Store as a special text message (type 0) with a flag
        messageData['type'] = 0; // Use text type instead of 5
        messageData['isLocation'] = true; // Add flag to identify as location

        // Add location data explicitly if available
        if (messageWithId.content.contains(',')) {
          final parts = messageWithId.content.split(',');
          if (parts.length == 2) {
            try {
              final lat = double.parse(parts[0].trim());
              final lng = double.parse(parts[1].trim());

              // Store validated coordinates
              messageData['location'] = {'latitude': lat, 'longitude': lng};
              messageData['locationData'] = messageWithId.content;
            } catch (e) {
              print("Invalid location coordinates: $e");
            }
          }
        }
      } else {
        // For all other message types, store the type normally
        messageData['type'] = messageWithId.type.index;

        // For non-text message types, handle attachments properly
        if (messageWithId.type != MessageType.text &&
            messageWithId.type != MessageType.emergency) {
          // Extract URL and metadata from content
          String attachmentUrl = messageWithId.content;
          Map<String, dynamic> attachmentMetadata = {};

          if (messageWithId.content.contains('|')) {
            final parts = messageWithId.content.split('|');
            attachmentUrl = parts[0]; // First part is always the URL

            print("DEBUG: Extracted attachment URL: $attachmentUrl");
            print("DEBUG: Content parts: ${parts.length}");

            // Add metadata based on message type
            switch (messageWithId.type) {
              case MessageType.audio:
                if (parts.length > 1) {
                  attachmentMetadata['duration'] = parts[1];
                  print("DEBUG: Added audio duration: ${parts[1]}");
                }
                break;
              case MessageType.document:
                if (parts.length > 3) {
                  attachmentMetadata['fileName'] = parts[1];
                  attachmentMetadata['fileSize'] = parts[2];
                  attachmentMetadata['fileExt'] = parts[3];
                  print(
                      "DEBUG: Added document metadata: filename=${parts[1]}, size=${parts[2]}, ext=${parts[3]}");
                }
                break;
              default:
                break;
            }
          }

          // Add attachmentUrl field consistently
          messageData['attachmentUrl'] = attachmentUrl;

          // Only add non-empty metadata
          if (attachmentMetadata.isNotEmpty) {
            messageData['attachmentMetadata'] = attachmentMetadata;
          }
        }
      }

      // Log the final message data before writing
      print("DEBUG: Final messageData to write to Firestore: $messageData");

      // Save the message to Firestore
      await messageRef.set(messageData);
      print(
          "DEBUG: Successfully wrote message to Firestore with ID: ${messageRef.id}");

      // Update the chat room with last message info
      final previewText = _getMessagePreview(messageWithId);
      await _firestore
          .collection('chat_rooms')
          .doc(messageToSend.chatRoomId)
          .update({
        'lastMessage': previewText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageType': messageWithId.type == MessageType.location
            ? '0' // Store as text type but with special handling
            : messageWithId.type.index.toString(),
        'lastMessageSenderId': messageWithId.senderId,
        'unreadCount_${messageWithId.receiverId}': FieldValue.increment(1),
      });
      print("DEBUG: Successfully updated chat room");

      // Handle emergency notifications if needed
      if (messageToSend.type == MessageType.emergency) {
        await _sendEmergencyNotification(messageWithId, location: location);
      }

      // Update the cache with the confirmed message
      if (_cacheRepository != null && tempId.startsWith('temp_')) {
        await _cacheRepository.addMessageToCache(messageWithId);
        await _cacheRepository.removeFromPendingQueue(tempId);
      }

      return messageWithId;
    } catch (e) {
      print("ERROR in sendMessage: $e");
      print("ERROR stack trace: ${StackTrace.current}");
      // Return the local message on error for optimistic UI
      return localMessage;
    }
  }

  // Send emergency notification
  Future<void> _sendEmergencyNotification(Message message,
      {String? location}) async {
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
        final cachedRooms = _cacheRepository.getCachedChatRooms(userId);
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
            _cacheRepository.cacheChatRooms(chatRooms, userId);

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
    // Helper function to process messages from snapshot
    List<Message> processMessages(QuerySnapshot snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if this is a location message (has isLocation flag)
        if (data['isLocation'] == true) {
          // Force the type to be MessageType.location regardless of stored type
          data['type'] = MessageType.location.index;
        }

        // Create message from the processed data
        return Message.fromMap(data);
      }).toList();
    }

    // If caching is enabled, use a custom stream with cache-first approach
    if (_cacheRepository != null) {
      final controller = StreamController<List<Message>>();

      // Immediately emit cached messages
      Future<void> emitCachedMessages() async {
        final cachedMessages = _cacheRepository.getCachedMessages(chatRoomId);
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
            // Process messages with the helper function
            final messages = processMessages(snapshot);

            // Update cache
            _cacheRepository.cacheMessages(chatRoomId, messages);

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

    // If no cache, use original implementation with the same processing
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => processMessages(snapshot));
  }

  // Process pending messages
  Future<void> processPendingMessages() async {
    if (_cacheRepository == null) return;

    final pendingMessages = _cacheRepository.getPendingMessages();

    for (final message in pendingMessages) {
      try {
        await sendMessage(message: message);

        // If successful, remove from pending queue
        await _cacheRepository.removeFromPendingQueue(message.id);
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
      final messages = _cacheRepository.getCachedMessages(chatRoomId);
      final updatedMessages = messages.map((msg) {
        if (msg.receiverId == userId && !msg.isRead) {
          return msg.copyWith(isRead: true);
        }
        return msg;
      }).toList();

      await _cacheRepository.cacheMessages(chatRoomId, updatedMessages);
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
          .collection('chat_rooms')
          .doc(chatRoomId)
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final currentUser = _auth.currentUser;
        if (currentUser == null) return null;

        final participants = List<String>.from(data['participants']);
        final otherUserId = participants
            .firstWhere((id) => id != currentUser.uid, orElse: () => '');

        return ChatRoom(
          id: snapshot.id,
          currentUserId: currentUser.uid,
          otherUserId: otherUserId,
          otherUserName: data['otherUserName_${currentUser.uid}'] ?? 'Unknown',
          otherUserPhotoUrl: data['otherUserPhotoUrl_${currentUser.uid}'],
          lastMessage: data['lastMessage'],
          lastMessageTime: data['lastMessageTime'] != null
              ? (data['lastMessageTime'] is Timestamp
                  ? (data['lastMessageTime'] as Timestamp).toDate()
                  : DateTime.parse(data['lastMessageTime']))
              : null,
          unreadCount: data['unreadCount_${currentUser.uid}'] ?? 0,
          isOnline: data['isOnline_$otherUserId'] ?? false,
        );
      }

      return null;
    } catch (e) {
      print('Error getting chat room: $e');
      return null;
    }
  }

  // Check if a message contains trigger phrase
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
      return message.content.trim().toLowerCase() ==
          triggerPhrase.toLowerCase();
    } catch (e) {
      print('Error checking trigger phrase: $e');
      return false;
    }
  }
}
