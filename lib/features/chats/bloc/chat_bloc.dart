// lib/features/chats/bloc/chat_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/repository/chat_repository.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ChatRoom> _allChatRooms = [];
  StreamSubscription? _chatRoomsSubscription;
  StreamSubscription? _messagesSubscription;

  ChatBloc({required ChatRepository repository})
      : _repository = repository,
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
  }

  @override
  Future<void> close() {
    _chatRoomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }

  // Chat Room Event Handlers
  Future<void> _onLoadChatRooms(
      LoadChatRooms event, Emitter<ChatState> emit) async {
    emit(ChatLoading());

    try {
      // Get current user
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        emit(ChatError('User not logged in'));
        return;
      }

      // Cancel previous subscription if any
      await _chatRoomsSubscription?.cancel();

      // Subscribe to chat rooms stream
      _chatRoomsSubscription = _repository.getChatRooms(currentUser.uid).listen(
        (chatRooms) {
          _allChatRooms = chatRooms;
          add(SortChatRooms(SortType.recent)); // Default sort by recent
        },
        onError: (error) {
          emit(ChatError(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  void _onFilterChatRooms(FilterChatRooms event, Emitter<ChatState> emit) {
    try {
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
      final sortedRooms =
          await _repository.sortChatRooms(_allChatRooms, event.sortType);
      emit(ChatRoomsLoaded(sortedRooms));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onDeleteChatRoom(
      DeleteChatRoom event, Emitter<ChatState> emit) async {
    // Note: Your repository doesn't have deleteChatRoom functionality
    // This would need to be implemented in the repository
    emit(ChatError('Delete chat room functionality not implemented'));
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
    emit(ChatLoading());

    try {
      // Find the chat room
      final chatRoom = _allChatRooms.firstWhere(
        (room) => room.id == event.chatRoomId,
        orElse: () => throw Exception('Chat room not found'),
      );

      // Cancel previous subscription if any
      await _messagesSubscription?.cancel();

      // Subscribe to messages stream
      _messagesSubscription = _repository.getMessages(event.chatRoomId).listen(
        (messages) {
          emit(MessagesLoaded(messages: messages, chatRoom: chatRoom));
        },
        onError: (error) {
          emit(ChatError(error.toString()));
        },
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendMessage(
      SendMessage event, Emitter<ChatState> emit) async {
    try {
      final message = await _repository.sendMessage(
        message: event.message,
      );

      emit(MessageSent(message));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendEmergencyMessage(
      SendEmergencyMessage event, Emitter<ChatState> emit) async {
    try {
      final message = await _repository.sendMessage(
        message: event.message,
        location: event.location,
      );

      emit(EmergencyMessageSent(message: message, location: event.location));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onMarkMessagesAsRead(
      MarkMessagesAsRead event, Emitter<ChatState> emit) async {
    try {
      await _repository.markMessagesAsRead(event.chatRoomId, event.userId);
      emit(MessagesMarkedAsRead());
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }
}
