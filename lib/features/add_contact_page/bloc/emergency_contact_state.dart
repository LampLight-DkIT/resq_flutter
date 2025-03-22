// emergency_contacts_state.dart
import 'package:equatable/equatable.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';

abstract class EmergencyContactsState extends Equatable {
  const EmergencyContactsState();

  @override
  List<Object?> get props => [];
}

class EmergencyContactsInitial extends EmergencyContactsState {}

class EmergencyContactsLoading extends EmergencyContactsState {}

class EmergencyContactsLoaded extends EmergencyContactsState {
  final List<EmergencyContact> contacts;

  const EmergencyContactsLoaded(this.contacts);

  @override
  List<Object?> get props => [contacts];
}

class EmergencyContactsError extends EmergencyContactsState {
  final String message;

  const EmergencyContactsError(this.message);

  @override
  List<Object?> get props => [message];
}

class EmergencyAlertSent extends EmergencyContactsState {}

class EmergencyAlertWithMediaSent extends EmergencyContactsState {
  final List<String> mediaUrls;

  const EmergencyAlertWithMediaSent({this.mediaUrls = const []});

  @override
  List<Object?> get props => [mediaUrls];
}

class EmergencyAlertError extends EmergencyContactsState {
  final String message;

  const EmergencyAlertError(this.message);

  @override
  List<Object?> get props => [message];
}

class MediaUploadInProgress extends EmergencyContactsState {
  final double progress;

  const MediaUploadInProgress(this.progress);

  @override
  List<Object?> get props => [progress];
}

class MediaUploadError extends EmergencyContactsState {
  final String message;

  const MediaUploadError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserSearchLoading extends EmergencyContactsState {}

class UserSearchLoaded extends EmergencyContactsState {
  final List<Map<String, dynamic>> users;

  const UserSearchLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

class UserSearchError extends EmergencyContactsState {
  final String message;

  const UserSearchError(this.message);

  @override
  List<Object?> get props => [message];
}

class UserFollowSuccess extends EmergencyContactsState {}

class UserUnfollowSuccess extends EmergencyContactsState {}
