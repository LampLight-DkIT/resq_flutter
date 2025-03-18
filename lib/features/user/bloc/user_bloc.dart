// lib/features/users/bloc/user_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:resq/features/user/bloc/user_event.dart';
import 'package:resq/features/user/bloc/user_state.dart';
import 'package:resq/features/user/repository/user_repository.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _repository;

  UserBloc({required UserRepository repository})
      : _repository = repository,
        super(UserInitial()) {
    on<SearchUsers>(_onSearchUsers);
    on<FollowUser>(_onFollowUser);
    on<UnfollowUser>(_onUnfollowUser);
    on<CheckFollowStatus>(_onCheckFollowStatus);
  }

  Future<void> _onSearchUsers(
      SearchUsers event, Emitter<UserState> emit) async {
    emit(UserSearchLoading());
    try {
      final users =
          await _repository.searchUsers(event.query, event.currentUserId);
      emit(UserSearchLoaded(users));
    } catch (e) {
      emit(UserSearchError(e.toString()));
    }
  }

  Future<void> _onFollowUser(FollowUser event, Emitter<UserState> emit) async {
    try {
      await _repository.followUser(event.currentUserId, event.targetUserId);

      // After following, reload the search results if applicable
      if (state is UserSearchLoaded) {
        final searchState = state as UserSearchLoaded;
        final updatedUsers = searchState.users.map((user) {
          if (user['id'] == event.targetUserId) {
            return {...user, 'isFollowing': true};
          }
          return user;
        }).toList();

        emit(UserSearchLoaded(updatedUsers));
      } else {
        emit(UserFollowSuccess(event.targetUserId));
      }
    } catch (e) {
      emit(UserFollowError(e.toString()));
    }
  }

  Future<void> _onUnfollowUser(
      UnfollowUser event, Emitter<UserState> emit) async {
    try {
      await _repository.unfollowUser(event.currentUserId, event.targetUserId);

      // After unfollowing, reload the search results if applicable
      if (state is UserSearchLoaded) {
        final searchState = state as UserSearchLoaded;
        final updatedUsers = searchState.users.map((user) {
          if (user['id'] == event.targetUserId) {
            return {...user, 'isFollowing': false};
          }
          return user;
        }).toList();

        emit(UserSearchLoaded(updatedUsers));
      } else {
        emit(UserUnfollowSuccess(event.targetUserId));
      }
    } catch (e) {
      emit(UserFollowError(e.toString()));
    }
  }

  Future<void> _onCheckFollowStatus(
      CheckFollowStatus event, Emitter<UserState> emit) async {
    try {
      final isFollowing = await _repository.isFollowingUser(
          event.currentUserId, event.targetUserId);
      emit(UserFollowStatusLoaded(isFollowing, event.targetUserId));
    } catch (e) {
      emit(UserFollowError(e.toString()));
    }
  }
}
