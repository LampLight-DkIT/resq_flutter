import 'package:equatable/equatable.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

// Chat Room Events
class LoadChatRooms extends ChatEvent {}

class FilterChatRooms extends ChatEvent {
  final String query;

  const FilterChatRooms(this.query);

  @override
  List<Object?> get props => [query];
}

class SortChatRooms extends ChatEvent {
  final SortType sortType;

  const SortChatRooms(this.sortType);

  @override
  List<Object?> get props => [sortType];
}

class DeleteChatRoom extends ChatEvent {
  final String chatRoomId;

  const DeleteChatRoom(this.chatRoomId);

  @override
  List<Object?> get props => [chatRoomId];
}

class UndoDeleteChatRoom extends ChatEvent {}

// Message Events
class LoadMessages extends ChatEvent {
  final String chatRoomId;

  const LoadMessages(this.chatRoomId);

  @override
  List<Object?> get props => [chatRoomId];
}

class SendMessage extends ChatEvent {
  final Message message;

  const SendMessage(this.message);

  @override
  List<Object?> get props => [message];
}

class SendEmergencyMessage extends ChatEvent {
  final Message message;
  final String? location;

  const SendEmergencyMessage(this.message, {this.location});

  @override
  List<Object?> get props => [message, location];
}

// Add new event for real-time messages
class NewMessageReceived extends ChatEvent {
  final Message message;

  const NewMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

// Add new event for loaded messages from stream
class NewMessagesLoaded extends ChatEvent {
  final List<Message> messages;
  final ChatRoom chatRoom;

  const NewMessagesLoaded(this.messages, this.chatRoom);

  @override
  List<Object?> get props => [messages, chatRoom];
}

// Add new event for message stream errors
class MessageStreamError extends ChatEvent {
  final String error;

  const MessageStreamError(this.error);

  @override
  List<Object?> get props => [error];
}

class MarkMessagesAsRead extends ChatEvent {
  final String chatRoomId;
  final String userId;

  const MarkMessagesAsRead(this.chatRoomId, this.userId);

  @override
  List<Object?> get props => [chatRoomId, userId];
}

// User-related Events
class CreateChatRoom extends ChatEvent {
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;

  const CreateChatRoom({
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
  });

  @override
  List<Object?> get props =>
      [currentUserId, otherUserId, otherUserName, otherUserPhotoUrl];
}

// Sorting enum
enum SortType {
  name,
  recent,
}

class ProcessPendingMessages extends ChatEvent {}
