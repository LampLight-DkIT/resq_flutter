// lib/features/users/bloc/user_event.dart
import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class SearchUsers extends UserEvent {
  final String query;
  final String currentUserId;

  const SearchUsers(this.query, this.currentUserId);

  @override
  List<Object?> get props => [query, currentUserId];
}

class FollowUser extends UserEvent {
  final String currentUserId;
  final String targetUserId;

  const FollowUser(this.currentUserId, this.targetUserId);

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class UnfollowUser extends UserEvent {
  final String currentUserId;
  final String targetUserId;

  const UnfollowUser(this.currentUserId, this.targetUserId);

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class CheckFollowStatus extends UserEvent {
  final String currentUserId;
  final String targetUserId;

  const CheckFollowStatus(this.currentUserId, this.targetUserId);

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}
