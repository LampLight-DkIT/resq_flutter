import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/offline/hive_models/hive_chat_room_model.dart';
import 'package:resq/offline/hive_models/hive_message_model.dart';

class ChatCacheRepository {
  static const String _chatRoomsBoxName = 'chat_rooms';
  static const String _messagesBoxName = 'messages';
  static const String _pendingMessagesBoxName = 'pending_messages';

  // Initialize Hive boxes
  Future<void> init() async {
    // Register the adapters
    Hive.registerAdapter(HiveChatRoomAdapter());
    Hive.registerAdapter(HiveMessageAdapter());
    Hive.registerAdapter(HiveMessageTypeAdapter());

    // Open boxes
    await Hive.openBox<HiveChatRoom>(_chatRoomsBoxName);
    await Hive.openBox<HiveMessage>(_messagesBoxName);
    await Hive.openBox<HiveMessage>(_pendingMessagesBoxName);
  }

  // Cache chat rooms
  Future<void> cacheChatRooms(List<ChatRoom> chatRooms, String userId) async {
    final box = Hive.box<HiveChatRoom>(_chatRoomsBoxName);

    // Create a map of room IDs to rooms for efficient checking
    final Map<String, HiveChatRoom> roomsToStore = {};
    for (var room in chatRooms) {
      roomsToStore['user_${userId}_room_${room.id}'] =
          HiveChatRoom.fromChatRoom(room);
    }

    // Delete rooms that no longer exist
    final keysToCheck = box.keys
        .where((key) => key.toString().startsWith('user_$userId'))
        .toList();

    for (var key in keysToCheck) {
      if (!roomsToStore.containsKey(key)) {
        await box.delete(key);
      }
    }

    // Store/update rooms
    await box.putAll(roomsToStore);
  }

  // Get cached chat rooms
  List<ChatRoom> getCachedChatRooms(String userId) {
    final box = Hive.box<HiveChatRoom>(_chatRoomsBoxName);

    return box.keys
        .where((key) => key.toString().startsWith('user_$userId'))
        .map((key) => box.get(key)!.toChatRoom())
        .toList();
  }

  // Cache messages for a chat room
  Future<void> cacheMessages(String chatRoomId, List<Message> messages) async {
    final box = Hive.box<HiveMessage>(_messagesBoxName);

    // Create map of message IDs to messages
    final Map<String, HiveMessage> messagesToStore = {};
    for (var message in messages) {
      // Preserve pending status if message exists
      final key = 'room_${chatRoomId}_msg_${message.id}';
      final existingMsg = box.get(key);
      final isPending = existingMsg?.isPending ?? false;

      messagesToStore[key] =
          HiveMessage.fromMessage(message, isPending: isPending);
    }

    // Delete messages that no longer exist (but keep pending ones)
    final keysToCheck = box.keys
        .where((key) => key.toString().startsWith('room_$chatRoomId'))
        .toList();

    for (var key in keysToCheck) {
      final msg = box.get(key);
      if (!messagesToStore.containsKey(key) && !(msg?.isPending ?? false)) {
        await box.delete(key);
      }
    }

    // Store/update messages
    await box.putAll(messagesToStore);
  }

  // Get cached messages for a chat room
  List<Message> getCachedMessages(String chatRoomId) {
    final box = Hive.box<HiveMessage>(_messagesBoxName);

    final messages = box.keys
        .where((key) => key.toString().startsWith('room_$chatRoomId'))
        .map((key) => box.get(key)!.toMessage())
        .toList();

    // Sort by timestamp
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return messages;
  }

  // Add a single message to cache (for optimistic updates)
  Future<void> addMessageToCache(Message message) async {
    final box = Hive.box<HiveMessage>(_messagesBoxName);
    final key = 'room_${message.chatRoomId}_msg_${message.id}';

    await box.put(key, HiveMessage.fromMessage(message));
  }

  // Update chat room's last message
  Future<void> updateChatRoomLastMessage(
      ChatRoom chatRoom, Message message) async {
    final box = Hive.box<HiveChatRoom>(_chatRoomsBoxName);

    final key = 'user_${chatRoom.currentUserId}_room_${chatRoom.id}';
    final existingRoom = box.get(key);

    if (existingRoom != null) {
      final updatedRoom = existingRoom.copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
        unreadCount: message.senderId == chatRoom.currentUserId
            ? existingRoom.unreadCount
            : existingRoom.unreadCount + 1,
      );

      await box.put(key, updatedRoom);
    }
  }

  // --- Offline/Pending Message Support ---

  // Add message to pending queue
  Future<void> addToPendingQueue(Message message) async {
    final box = Hive.box<HiveMessage>(_pendingMessagesBoxName);

    // Mark as pending in both boxes for consistency
    final hiveMessage = HiveMessage.fromMessage(message, isPending: true);

    // Store in pending box
    await box.put(message.id, hiveMessage);

    // Mark as pending in messages box too
    final messagesBox = Hive.box<HiveMessage>(_messagesBoxName);
    final msgKey = 'room_${message.chatRoomId}_msg_${message.id}';
    await messagesBox.put(msgKey, hiveMessage);
  }

  // Get all pending messages
  List<Message> getPendingMessages() {
    final box = Hive.box<HiveMessage>(_pendingMessagesBoxName);
    return box.values.map((msg) => msg.toMessage()).toList();
  }

  // Remove message from pending queue
  Future<void> removeFromPendingQueue(String messageId) async {
    final box = Hive.box<HiveMessage>(_pendingMessagesBoxName);
    await box.delete(messageId);

    // Also update message in messages box to not be pending
    final messagesBox = Hive.box<HiveMessage>(_messagesBoxName);

    // Find the message in messages box by ID (need to find the full key)
    for (final key in messagesBox.keys) {
      final keyStr = key.toString();
      if (keyStr.endsWith('_msg_$messageId')) {
        final msg = messagesBox.get(key);
        if (msg != null) {
          await messagesBox.put(key, msg.copyWith(isPending: false));
        }
        break;
      }
    }
  }

  // Clear all cached data (useful for logout)
  Future<void> clearAllCaches() async {
    await Hive.box<HiveChatRoom>(_chatRoomsBoxName).clear();
    await Hive.box<HiveMessage>(_messagesBoxName).clear();
    await Hive.box<HiveMessage>(_pendingMessagesBoxName).clear();
  }
}
