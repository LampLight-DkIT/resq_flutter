// profile_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:resq/features/auth/repository/auth_repository.dart';
import 'package:resq/features/profile/bloc/profile_event.dart';
import 'package:resq/features/profile/bloc/profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthRepository _authRepository;

  ProfileBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(ProfileInitial()) {
    on<LoadProfile>((event, emit) async {
      emit(ProfileLoading());
      try {
        final profileData = await _authRepository.getUserProfile(event.userId);
        emit(ProfileLoaded(profileData: profileData));
      } catch (e) {
        emit(ProfileError(message: e.toString()));
      }
    });

    on<UpdateProfile>((event, emit) async {
      emit(ProfileUpdating());
      try {
        await _authRepository.updateUserProfile(
          uid: event.userId,
          name: event.name,
          email: event.email,
          phoneNumber: event.phoneNumber,
          countryCode: event.countryCode,
          bio: event.bio,
          photoURL: event.photoURL,
        );

        // After successful update, reload the profile
        final profileData = await _authRepository.getUserProfile(event.userId);
        emit(ProfileLoaded(profileData: profileData));
      } catch (e) {
        emit(ProfileError(message: e.toString()));
      }
    });
  }
}
