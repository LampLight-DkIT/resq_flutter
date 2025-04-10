// lib/features/chats/bloc/chat_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/core/services/app_initialization_service.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/features/chats/repository/chat_repository.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity;

  // Memory caches
  List<ChatRoom> _allChatRooms = [];
  final Map<String, List<Message>> _messagesCache = {};
  bool get hasCachedChatRooms => _allChatRooms.isNotEmpty;
  List<ChatRoom> get cachedChatRooms => List<ChatRoom>.from(_allChatRooms);

  // Subscriptions
  StreamSubscription? _chatRoomsSubscription;
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  StreamSubscription? _connectivitySubscription;

  // Flags for operation tracking
  bool _isFetchingChatRooms = false;
  final Map<String, bool> _isFetchingMessages = {};

  // Debounce timers
  Timer? _loadDebounce;

  // Initialization service
  final AppInitializationService _initService = AppInitializationService();

  ChatBloc({
    required ChatRepository repository,
    Connectivity? connectivity,
  })  : _repository = repository,
        _connectivity = connectivity ?? Connectivity(),
        super(ChatInitial()) {
    // Chat Room Events
    on<LoadChatRooms>(_onLoadChatRooms);
    on<FilterChatRooms>(_onFilterChatRooms);
    on<SortChatRooms>(_onSortChatRooms);
    on<DeleteChatRoom>(_onDeleteChatRoom);
    on<UndoDeleteChatRoom>(_onUndoDeleteChatRoom);
    on<CreateChatRoom>(_onCreateChatRoom);

    // Message Events
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<SendEmergencyMessage>(_onSendEmergencyMessage);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<NewMessageReceived>(_onNewMessageReceived);
    on<NewMessagesLoaded>(_onNewMessagesLoaded);
    on<MessageStreamError>(_onMessageStreamError);
    on<ProcessPendingMessages>(_onProcessPendingMessages);

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        // We're back online, process pending messages
        add(ProcessPendingMessages());
      }
    });
  }

  @override
  Future<void> close() {
    _chatRoomsSubscription?.cancel();
    // Cancel all message subscriptions
    for (var subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    _connectivitySubscription?.cancel();
    _loadDebounce?.cancel();
    return super.close();
  }

  // Improved LoadChatRooms event handler
  Future<void> _onLoadChatRooms(
      LoadChatRooms event, Emitter<ChatState> emit) async {
    if (_isFetchingChatRooms) return;
    _isFetchingChatRooms = true;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(ChatError('User not authenticated'));
        return;
      }

      emit(ChatLoading());

      // Cancel existing subscription
      await _chatRoomsSubscription?.cancel();

      // Subscribe to chat rooms stream
      _chatRoomsSubscription = _repository.getChatRooms(currentUser.uid).listen(
        (chatRooms) {
          // Update our cache
          _allChatRooms = chatRooms;
          add(SortChatRooms(SortType.recent));
        },
        onError: (error) {
          add(MessageStreamError(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    } finally {
      _isFetchingChatRooms = false;
    }
  }

  void _onFilterChatRooms(FilterChatRooms event, Emitter<ChatState> emit) {
    try {
      // Perform filtering in memory
      final filteredRooms =
          _repository.filterChatRooms(_allChatRooms, event.query);
      emit(ChatRoomsFiltered(filteredRooms));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSortChatRooms(
      SortChatRooms event, Emitter<ChatState> emit) async {
    try {
      // Sort in memory
      final sortedRooms =
          await _repository.sortChatRooms(_allChatRooms, event.sortType);
      emit(ChatRoomsLoaded(sortedRooms));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onDeleteChatRoom(
      DeleteChatRoom event, Emitter<ChatState> emit) async {
    // Implementation for delete functionality would go here
    emit(ChatError('Delete chat room functionality not implemented'));
  }

  Future<void> _onUndoDeleteChatRoom(
      UndoDeleteChatRoom event, Emitter<ChatState> emit) async {
    // Implementation for undo delete functionality would go here
    emit(ChatError('Undo delete chat room functionality not implemented'));
  }

  Future<void> _onCreateChatRoom(
      CreateChatRoom event, Emitter<ChatState> emit) async {
    emit(ChatLoading());
    try {
      final chatRoom = await _repository.createChatRoom(
        currentUserId: event.currentUserId,
        otherUserId: event.otherUserId,
        otherUserName: event.otherUserName,
        otherUserPhotoUrl: event.otherUserPhotoUrl,
      );

      emit(ChatRoomCreated(chatRoom));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  // Improved LoadMessages event handler
  Future<void> _onLoadMessages(
      LoadMessages event, Emitter<ChatState> emit) async {
    final chatRoomId = event.chatRoomId;

    // Prevent parallel fetches for the same chat room
    if (_isFetchingMessages[chatRoomId] == true) return;
    _isFetchingMessages[chatRoomId] = true;

    try {
      // Check if chat room exists in our list
      ChatRoom? chatRoom;
      try {
        chatRoom = _allChatRooms.firstWhere(
          (room) => room.id == chatRoomId,
        );
      } catch (_) {
        // If not found in local cache, try to fetch it
        chatRoom = await _repository.getChatRoom(chatRoomId);
        if (chatRoom == null) {
          throw Exception('Chat room not found');
        }
      }

      // Immediately serve from cache if available
      if (_messagesCache.containsKey(chatRoomId)) {
        emit(MessagesLoaded(
            messages: _messagesCache[chatRoomId]!, chatRoom: chatRoom));
      } else {
        // If no cached messages, show loading state
        emit(ChatLoading());
      }

      // Cancel previous subscription for this chat room if exists
      await _messageSubscriptions[chatRoomId]?.cancel();

      // Subscribe to messages stream
      _messageSubscriptions[chatRoomId] =
          _repository.getMessages(chatRoomId).listen(
        (messages) {
          // Update our memory cache
          _messagesCache[chatRoomId] = messages;

          // Emit the loaded state with the new messages
          add(NewMessagesLoaded(messages, chatRoom!));

          // Check for new messages that weren't in our previous cache
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            // Find messages received by current user that are unread
            final unreadMessages = messages
                .where(
                    (msg) => msg.receiverId == currentUser.uid && !msg.isRead)
                .toList();

            if (unreadMessages.isNotEmpty) {
              // Mark messages as read
              add(MarkMessagesAsRead(chatRoomId, currentUser.uid));

              // Emit individual MessageReceived events for new messages
              for (final newMsg in unreadMessages) {
                add(NewMessageReceived(newMsg));
              }
            }
          }
        },
        onError: (error) {
          add(MessageStreamError(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    } finally {
      _isFetchingMessages[chatRoomId] = false;
    }
  }

  // Handlers for message events
  void _onNewMessagesLoaded(NewMessagesLoaded event, Emitter<ChatState> emit) {
    emit(MessagesLoaded(messages: event.messages, chatRoom: event.chatRoom));
  }

  void _onMessageStreamError(
      MessageStreamError event, Emitter<ChatState> emit) {
    emit(ChatError(event.error));
  }

  void _onNewMessageReceived(
      NewMessageReceived event, Emitter<ChatState> emit) {
    emit(MessageReceived(event.message));
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    try {
      // Add specific debugging for location messages
      if (event.message.type == MessageType.location) {
        print("LOCATION DEBUG: Sending location message in ChatBloc");
        print(
            "LOCATION DEBUG: Message type index: ${event.message.type.index}");
        print("LOCATION DEBUG: Message content: ${event.message.content}");
        print(
            "LOCATION DEBUG: Message locationData: ${event.message.locationData}");

        if (event.message.content.isEmpty ||
            !event.message.content.contains(',')) {
          print(
              "LOCATION ERROR: Invalid location content format: ${event.message.content}");
        }

        // Log the full message map for Firebase debugging
        print("LOCATION DEBUG: Message map: ${event.message.toMap()}");
      }

      // Check connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      print("DEBUG: isOffline: $isOffline");

      // Send message
      final message = await _repository.sendMessage(
        message: event.message,
        isOffline: isOffline,
      );

      // Add location-specific logging for success
      if (event.message.type == MessageType.location) {
        print("LOCATION DEBUG: Location message sent successfully");
        print("LOCATION DEBUG: Returned message ID: ${message.id}");
      }

      // Update local cache for instant UI feedback
      final chatRoomId = message.chatRoomId;
      if (_messagesCache.containsKey(chatRoomId)) {
        final updatedMessages = [..._messagesCache[chatRoomId]!];

        // Remove any temporary version of this message (for optimistic UI)
        updatedMessages.removeWhere((m) =>
            m.id.contains('temp_') &&
            m.content == message.content &&
            m.timestamp.difference(message.timestamp).inSeconds.abs() < 5);

        // Add the confirmed message
        updatedMessages.add(message);
        _messagesCache[chatRoomId] = updatedMessages;
      }

      // Check if we need to update the chat room's last message
      final chatRoomIndex =
          _allChatRooms.indexWhere((room) => room.id == chatRoomId);
      if (chatRoomIndex >= 0) {
        _allChatRooms[chatRoomIndex] = _allChatRooms[chatRoomIndex].copyWith(
          lastMessage: message.content,
          lastMessageTime: message.timestamp,
        );
      }

      // Emit success state
      emit(MessageSent(message));

      // If offline, show notification
      if (isOffline) {
        emit(ChatNotification(
          'Message will be sent when you are back online',
          NotificationType.info,
        ));
      }
    } catch (e) {
      print("ERROR sending message: $e");
      if (event.message.type == MessageType.location) {
        print("LOCATION ERROR: Failed to send location message: $e");
      }
      emit(ChatError(e.toString()));
    }
  }

  // In chat_bloc.dart, update _onSendEmergencyMessage
  Future<void> _onSendEmergencyMessage(
      SendEmergencyMessage event, Emitter<ChatState> emit) async {
    try {
      // For emergency messages, always try to send regardless of connectivity
      final message = await _repository.sendMessage(
        message: event.message,
        location: event.location,
      );

      // Update local cache for instant UI feedback
      final chatRoomId = message.chatRoomId;
      if (_messagesCache.containsKey(chatRoomId)) {
        _messagesCache[chatRoomId] = [..._messagesCache[chatRoomId]!, message];
      }

      // Emit message sent state first to ensure UI updates
      emit(MessageSent(message));

      // Then emit emergency-specific state
      emit(EmergencyMessageSent(message: message, location: event.location));

      // Check if we're offline
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        emit(ChatNotification(
          'Emergency message will be sent as soon as you\'re back online',
          NotificationType.warning,
        ));
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onMarkMessagesAsRead(
      MarkMessagesAsRead event, Emitter<ChatState> emit) async {
    try {
      await _repository.markMessagesAsRead(event.chatRoomId, event.userId);
      emit(MessagesMarkedAsRead());

      // Update the unread count in our local list to avoid UI flicker
      final index =
          _allChatRooms.indexWhere((room) => room.id == event.chatRoomId);
      if (index >= 0) {
        _allChatRooms[index] = _allChatRooms[index].copyWith(unreadCount: 0);
      }

      // Update messages in cache to mark them as read
      if (_messagesCache.containsKey(event.chatRoomId)) {
        _messagesCache[event.chatRoomId] = _messagesCache[event.chatRoomId]!
            .map((msg) => msg.receiverId == event.userId && !msg.isRead
                ? msg.copyWith(isRead: true)
                : msg)
            .toList();
      }
    } catch (e) {
      // Don't emit error for marking as read - just log it
      print('Error marking messages as read: ${e.toString()}');
    }
  }

  // Process pending messages with better error handling
  Future<void> _onProcessPendingMessages(
      ProcessPendingMessages event, Emitter<ChatState> emit) async {
    try {
      await _repository.processPendingMessages();
      // No need to emit a state since updates will come through streams
    } catch (e) {
      // We intentionally don't emit an error state for this background operation
      print('Error processing pending messages: ${e.toString()}');
    }
  }
}
