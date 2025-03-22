import 'package:equatable/equatable.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

// Chat Room States
class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatRoomsLoaded extends ChatState {
  final List<ChatRoom> chatRooms;

  const ChatRoomsLoaded(this.chatRooms);

  @override
  List<Object?> get props => [chatRooms];
}

class ChatRoomsFiltered extends ChatState {
  final List<ChatRoom> filteredChatRooms;

  const ChatRoomsFiltered(this.filteredChatRooms);

  @override
  List<Object?> get props => [filteredChatRooms];
}

class ChatRoomCreated extends ChatState {
  final ChatRoom chatRoom;

  const ChatRoomCreated(this.chatRoom);

  @override
  List<Object?> get props => [chatRoom];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

// Message States
class MessagesLoaded extends ChatState {
  final List<Message> messages;
  final ChatRoom chatRoom;

  const MessagesLoaded({required this.messages, required this.chatRoom});

  @override
  List<Object?> get props => [messages, chatRoom];
}

class MessageSent extends ChatState {
  final Message message;

  const MessageSent(this.message);

  @override
  List<Object?> get props => [message];
}

class EmergencyMessageSent extends ChatState {
  final Message message;
  final String? location;

  const EmergencyMessageSent({required this.message, this.location});

  @override
  List<Object?> get props => [message, location];
}

class MessagesMarkedAsRead extends ChatState {}

enum NotificationType {
  info,
  success,
  error,
  warning,
}

class ChatNotification extends ChatState {
  final String message;
  final NotificationType type;

  const ChatNotification(this.message, this.type);

  @override
  List<Object?> get props => [message, type];
}
