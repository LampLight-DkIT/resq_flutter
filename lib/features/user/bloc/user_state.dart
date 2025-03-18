// lib/features/users/bloc/user_state.dart
import 'package:equatable/equatable.dart';

abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserSearchLoading extends UserState {}

class UserSearchLoaded extends UserState {
  final List<Map<String, dynamic>> users;

  const UserSearchLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserSearchError extends UserState {
  final String message;

  const UserSearchError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserFollowSuccess extends UserState {
  final String targetUserId;

  const UserFollowSuccess(this.targetUserId);

  @override
  List<Object?> get props => [targetUserId];
}

class UserUnfollowSuccess extends UserState {
  final String targetUserId;

  const UserUnfollowSuccess(this.targetUserId);

  @override
  List<Object?> get props => [targetUserId];
}

class UserFollowError extends UserState {
  final String message;

  const UserFollowError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserFollowStatusLoaded extends UserState {
  final bool isFollowing;
  final String targetUserId;

  const UserFollowStatusLoaded(this.isFollowing, this.targetUserId);

  @override
  List<Object?> get props => [isFollowing, targetUserId];
}
