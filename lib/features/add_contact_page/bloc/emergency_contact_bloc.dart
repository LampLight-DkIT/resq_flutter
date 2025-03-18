import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
import 'package:rxdart/rxdart.dart';

class EmergencyContactsBloc
    extends Bloc<EmergencyContactsEvent, EmergencyContactsState> {
  final EmergencyContactsRepository _repository;
  StreamSubscription? _contactsSubscription;

  EmergencyContactsBloc({required EmergencyContactsRepository repository})
      : _repository = repository,
        super(EmergencyContactsInitial()) {
    on<LoadEmergencyContacts>(_onLoadEmergencyContacts);
    on<LoadEmergencyContactsSuccess>(_onLoadEmergencyContactsSuccess);
    on<LoadEmergencyContactsFailure>(_onLoadEmergencyContactsFailure);
    on<AddEmergencyContact>(_onAddEmergencyContact);
    on<UpdateEmergencyContact>(_onUpdateEmergencyContact);
    on<DeleteEmergencyContact>(_onDeleteEmergencyContact);
    on<SendEmergencyAlert>(_onSendEmergencyAlert);

    // Note: These handlers are being kept, but we should consider removing them
    // in the future to ensure a clean separation between UserBloc and EmergencyContactsBloc
    on<FollowUser>(_onFollowUser);
    on<UnfollowUser>(_onUnfollowUser);
    on<SearchUsers>(_onSearchUsers, transformer: _debounce());
  }

  @override
  Future<void> close() {
    _contactsSubscription?.cancel(); // Cancel stream subscription on bloc close
    return super.close();
  }

  void _onLoadEmergencyContacts(
      LoadEmergencyContacts event, Emitter<EmergencyContactsState> emit) async {
    emit(EmergencyContactsLoading());
    await _contactsSubscription
        ?.cancel(); // Cancel previous subscription if any
    _contactsSubscription =
        _repository.getEmergencyContacts(event.userId).listen(
      (contacts) {
        add(LoadEmergencyContactsSuccess(contacts));
      },
      onError: (error) {
        add(LoadEmergencyContactsFailure(error.toString()));
      },
    );
  }

  void _onLoadEmergencyContactsSuccess(LoadEmergencyContactsSuccess event,
      Emitter<EmergencyContactsState> emit) {
    emit(EmergencyContactsLoaded(event.contacts));
  }

  void _onLoadEmergencyContactsFailure(LoadEmergencyContactsFailure event,
      Emitter<EmergencyContactsState> emit) {
    emit(EmergencyContactsError(event.message));
  }

  Future<void> _onAddEmergencyContact(
      AddEmergencyContact event, Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.addEmergencyContact(event.userId, event.contact);
      add(LoadEmergencyContacts(event.userId)); // Refresh contacts
    } catch (e) {
      emit(EmergencyContactsError(e.toString()));
    }
  }

  Future<void> _onUpdateEmergencyContact(UpdateEmergencyContact event,
      Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.updateEmergencyContact(event.userId, event.contact);
      add(LoadEmergencyContacts(event.userId)); // Refresh contacts
    } catch (e) {
      emit(EmergencyContactsError(e.toString()));
    }
  }

  Future<void> _onDeleteEmergencyContact(DeleteEmergencyContact event,
      Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.deleteEmergencyContact(event.userId, event.contactId);
      add(LoadEmergencyContacts(event.userId)); // Refresh contacts
    } catch (e) {
      emit(EmergencyContactsError(e.toString()));
    }
  }

  Future<void> _onSendEmergencyAlert(
      SendEmergencyAlert event, Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.sendEmergencyAlert(
        event.userId,
        event.contactId,
        customMessage: event.customMessage,
      );
      emit(EmergencyAlertSent());
    } catch (e) {
      emit(EmergencyAlertError(e.toString()));
    }
  }

  Future<void> _onFollowUser(
      FollowUser event, Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.followUser(event.currentUserId, event.targetUserId);
      emit(UserFollowSuccess());
    } catch (e) {
      emit(EmergencyContactsError(e.toString()));
    }
  }

  Future<void> _onUnfollowUser(
      UnfollowUser event, Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.unfollowUser(event.currentUserId, event.targetUserId);
      emit(UserUnfollowSuccess());
    } catch (e) {
      emit(EmergencyContactsError(e.toString()));
    }
  }

  Future<void> _onSearchUsers(
      SearchUsers event, Emitter<EmergencyContactsState> emit) async {
    emit(UserSearchLoading());
    try {
      final users =
          await _repository.searchUsers(event.query, event.currentUserId);
      emit(UserSearchLoaded(users));
    } catch (e) {
      emit(UserSearchError(e.toString()));
    }
  }

  /// Debounce transformer for search input
  static EventTransformer<SearchUsers> _debounce<SearchUsers>() {
    return (events, mapper) {
      return events.debounceTime(Duration(milliseconds: 300)).flatMap(mapper);
    };
  }

  Future<void> _onSendDirectEmergencyAlert(SendDirectEmergencyAlert event,
      Emitter<EmergencyContactsState> emit) async {
    try {
      await _repository.sendDirectEmergencyAlert(
        event.senderId,
        event.receiverUserId,
        event.message,
      );
      emit(EmergencyAlertSent());
    } catch (e) {
      emit(EmergencyAlertError(e.toString()));
    }
  }
}
