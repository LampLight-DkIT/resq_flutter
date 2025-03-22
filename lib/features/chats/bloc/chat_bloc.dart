// lib/features/chats/bloc/chat_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Map<String, List<Message>> _messagesCache = {};
  bool get hasCachedChatRooms => _allChatRooms.isNotEmpty;
  List<ChatRoom> get cachedChatRooms => List<ChatRoom>.from(_allChatRooms);

  // Subscriptions
  StreamSubscription? _chatRoomsSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _connectivitySubscription;

  // Flags for operation tracking
  bool _hasActiveChatRoomSubscription = false;
  bool _isFetchingChatRooms = false;
  bool _isFetchingMessages = false;

  // Debounce timers
  Timer? _loadDebounce;

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

    // New Event
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
    _messagesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _loadDebounce?.cancel();
    _hasActiveChatRoomSubscription = false;
    return super.close();
  }

  // Chat Room Event Handlers
  Future<void> _onLoadChatRooms(
      LoadChatRooms event, Emitter<ChatState> emit) async {
    // Cancel any pending load operations if we're rapidly navigating
    _loadDebounce?.cancel();

    // Prevent parallel fetches
    if (_isFetchingChatRooms) return;

    // If we already have chat rooms, emit them immediately for better UX
    if (_allChatRooms.isNotEmpty) {
      emit(ChatRoomsLoaded(List<ChatRoom>.from(_allChatRooms)));
    } else {
      emit(ChatLoading());
    }

    // Debounce the actual Firestore fetch
    _loadDebounce = Timer(const Duration(milliseconds: 300), () async {
      _isFetchingChatRooms = true;

      try {
        // Get current user
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          emit(ChatError('User not logged in'));
          _isFetchingChatRooms = false;
          return;
        }

        // Only create a new subscription if we don't already have one
        if (!_hasActiveChatRoomSubscription) {
          await _chatRoomsSubscription?.cancel();

          // Subscribe to chat rooms stream
          _chatRoomsSubscription =
              _repository.getChatRooms(currentUser.uid).listen(
            (chatRooms) {
              _allChatRooms = chatRooms;
              add(SortChatRooms(SortType.recent)); // Default sort by recent
            },
            onError: (error) {
              emit(ChatError(error.toString()));
            },
          );

          _hasActiveChatRoomSubscription = true;
        } else if (_allChatRooms.isNotEmpty) {
          // If we already have data and a subscription, just re-sort
          add(SortChatRooms(SortType.recent));
        }
      } catch (e) {
        emit(ChatError(e.toString()));
      } finally {
        _isFetchingChatRooms = false;
      }
    });
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
    try {
      // Store the chat room to be deleted for potential undo
      final chatRoomToDelete = _allChatRooms.firstWhere(
        (room) => room.id == event.chatRoomId,
        orElse: () => throw Exception('Chat room not found'),
      );

      // Remove from local list immediately for UI update
      _allChatRooms.removeWhere((room) => room.id == event.chatRoomId);

      // Emit updated list
      final sortedRooms =
          await _repository.sortChatRooms(_allChatRooms, SortType.recent);
      emit(ChatRoomsLoaded(sortedRooms));

      // Attempt to delete from repository
      // Note: This would need to be implemented in your repository
      // await _repository.deleteChatRoom(event.chatRoomId);

      // For now, just show error since it's not implemented
      emit(ChatError('Delete chat room functionality not implemented'));

      // Add the room back to the list since delete failed
      _allChatRooms.add(chatRoomToDelete);
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onUndoDeleteChatRoom(
      UndoDeleteChatRoom event, Emitter<ChatState> emit) async {
    // Note: Your repository doesn't have undoDeleteChatRoom functionality
    // This would need to be implemented in the repository
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

  // Message Event Handlers
  Future<void> _onLoadMessages(
      LoadMessages event, Emitter<ChatState> emit) async {
    // Prevent parallel fetches
    if (_isFetchingMessages) return;
    _isFetchingMessages = true;

    emit(ChatLoading());

    try {
      // Find the chat room
      final chatRoom = _allChatRooms.firstWhere(
        (room) => room.id == event.chatRoomId,
        orElse: () => throw Exception('Chat room not found'),
      );

      // Immediately serve from cache if available
      if (_messagesCache.containsKey(event.chatRoomId)) {
        emit(MessagesLoaded(
            messages: _messagesCache[event.chatRoomId]!, chatRoom: chatRoom));
      }

      // Cancel previous subscription if any
      await _messagesSubscription?.cancel();

      // Create a completer to properly handle the first emission
      final completer = Completer<void>();

      // Subscribe to messages stream
      _messagesSubscription = _repository.getMessages(event.chatRoomId).listen(
        (messages) {
          // Update our memory cache
          _messagesCache[event.chatRoomId] = messages;

          if (!completer.isCompleted) {
            emit(MessagesLoaded(messages: messages, chatRoom: chatRoom));
            completer.complete();
          } else if (!emit.isDone) {
            // Only emit if the handler hasn't completed
            emit(MessagesLoaded(messages: messages, chatRoom: chatRoom));
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            emit(ChatError(error.toString()));
            completer.complete();
          }
        },
      );

      // Wait for first emission
      await completer.future;

      // Mark messages as read after we have loaded them
      if (chatRoom.unreadCount > 0) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          add(MarkMessagesAsRead(event.chatRoomId, currentUser.uid));
        }
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    } finally {
      _isFetchingMessages = false;
    }
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    try {
      // Check connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOffline = connectivityResult == ConnectivityResult.none;

      final message = await _repository.sendMessage(
        message: event.message,
        isOffline: isOffline,
      );

      // Update local cache for instant UI feedback
      final chatRoomId = message.chatRoomId;
      if (_messagesCache.containsKey(chatRoomId)) {
        _messagesCache[chatRoomId] = [..._messagesCache[chatRoomId]!, message];
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
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendEmergencyMessage(
      SendEmergencyMessage event, Emitter<ChatState> emit) async {
    try {
      // For emergency messages, always try to send regardless of connectivity
      // (if offline, it will be queued)
      final message = await _repository.sendMessage(
        message: event.message,
        location: event.location,
      );

      // Update local cache for instant UI feedback
      final chatRoomId = message.chatRoomId;
      if (_messagesCache.containsKey(chatRoomId)) {
        _messagesCache[chatRoomId] = [..._messagesCache[chatRoomId]!, message];
      }

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
      // Update messages in cache to mark them as read
      // Update messages in cache to mark them as read
      if (_messagesCache.containsKey(event.chatRoomId)) {
        _messagesCache[event.chatRoomId] = _messagesCache[event.chatRoomId]!
            .map((msg) => msg.receiverId == event.userId && !msg.isRead
                ? msg.copyWith(isRead: true)
                : msg)
            .toList() as List<Message>;
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  // New Event Handler
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
