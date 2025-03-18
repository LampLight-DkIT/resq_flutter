import 'package:equatable/equatable.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';

abstract class EmergencyContactsEvent extends Equatable {
  const EmergencyContactsEvent();

  @override
  List<Object?> get props => [];
}

class LoadEmergencyContacts extends EmergencyContactsEvent {
  final String userId;

  const LoadEmergencyContacts(this.userId);

  @override
  List<Object?> get props => [userId];
}

class LoadEmergencyContactsSuccess extends EmergencyContactsEvent {
  final List<EmergencyContact> contacts;

  const LoadEmergencyContactsSuccess(this.contacts);

  @override
  List<Object?> get props => [contacts];
}

class LoadEmergencyContactsFailure extends EmergencyContactsEvent {
  final String message;

  const LoadEmergencyContactsFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class AddEmergencyContact extends EmergencyContactsEvent {
  final String userId;
  final EmergencyContact contact;

  const AddEmergencyContact(this.userId, this.contact);

  @override
  List<Object?> get props => [userId, contact];
}

class UpdateEmergencyContact extends EmergencyContactsEvent {
  final String userId;
  final EmergencyContact contact;

  const UpdateEmergencyContact(this.userId, this.contact);

  @override
  List<Object?> get props => [userId, contact];
}

class DeleteEmergencyContact extends EmergencyContactsEvent {
  final String userId;
  final String contactId;

  const DeleteEmergencyContact(this.userId, this.contactId);

  @override
  List<Object?> get props => [userId, contactId];
}

class SendEmergencyAlert extends EmergencyContactsEvent {
  final String userId;
  final String contactId;
  final String? customMessage;

  const SendEmergencyAlert(this.userId, this.contactId, {this.customMessage});

  @override
  List<Object?> get props => [userId, contactId, customMessage];
}

class FollowUser extends EmergencyContactsEvent {
  final String currentUserId;
  final String targetUserId;

  const FollowUser(this.currentUserId, this.targetUserId);

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class UnfollowUser extends EmergencyContactsEvent {
  final String currentUserId;
  final String targetUserId;

  const UnfollowUser(this.currentUserId, this.targetUserId);

  @override
  List<Object?> get props => [currentUserId, targetUserId];
}

class SearchUsers extends EmergencyContactsEvent {
  final String query;
  final String currentUserId;

  const SearchUsers(this.query, this.currentUserId);

  @override
  List<Object?> get props => [query, currentUserId];
}

class SendDirectEmergencyAlert extends EmergencyContactsEvent {
  final String senderId;
  final String receiverUserId;
  final String message;

  const SendDirectEmergencyAlert(
      this.senderId, this.receiverUserId, this.message);

  @override
  List<Object?> get props => [senderId, receiverUserId, message];
}
