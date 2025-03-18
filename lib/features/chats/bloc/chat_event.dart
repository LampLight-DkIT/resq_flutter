import 'package:equatable/equatable.dart';
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
