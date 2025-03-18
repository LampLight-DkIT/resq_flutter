import 'package:bloc/bloc.dart';
import 'package:resq/features/auth/bloc/auth_event.dart';
import 'package:resq/features/auth/bloc/auth_state.dart';
import 'package:resq/features/auth/repository/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    // Handle Sign Up event
    on<AuthSignUp>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRepository.signUp(
          name: event.name,
          email: event.email,
          password: event.password,
        );
        emit(AuthAuthenticated(user: user!));
      } catch (e) {
        emit(AuthError(message: e.toString()));
      }
    });

    // Handle Login event
    on<AuthLogin>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRepository.login(
          email: event.email,
          password: event.password,
        );
        emit(AuthAuthenticated(user: user!));
      } catch (e) {
        emit(AuthError(message: e.toString()));
      }
    });

    // Handle Google Sign In event
    on<AuthGoogleSignIn>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRepository.signInWithGoogle();
        if (user != null) {
          emit(AuthAuthenticated(user: user));
        } else {
          // User canceled the Google sign-in
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        emit(AuthError(message: e.toString()));
      }
    });

    // Handle Apple Sign In event
    on<AuthAppleSignIn>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _authRepository.signInWithApple();
        if (user != null) {
          emit(AuthAuthenticated(user: user));
        } else {
          // User canceled the Apple sign-in
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        emit(AuthError(message: e.toString()));
      }
    });

    // Handle Logout event
    on<AuthLogout>((event, emit) async {
      emit(AuthLoading());
      try {
        await _authRepository.logout();
        emit(AuthUnauthenticated());
      } catch (e) {
        emit(AuthError(message: e.toString()));
      }
    });

    // Handle Check Auth Status event
    on<AuthCheckStatus>((event, emit) async {
      emit(AuthLoading());
      _authRepository.userChanges.listen((user) {
        if (user != null) {
          add(AuthStatusChanged(user: user));
        } else {
          add(AuthStatusChanged(user: null));
        }
      });
    });

    // Handle Auth Status Changed event
    on<AuthStatusChanged>((event, emit) {
      if (event.user != null) {
        emit(AuthAuthenticated(user: event.user!));
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }
}
