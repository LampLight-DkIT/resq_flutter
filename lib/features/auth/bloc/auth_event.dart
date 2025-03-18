import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthSignUp extends AuthEvent {
  final String name;
  final String email;
  final String password;

  AuthSignUp({required this.name, required this.email, required this.password});

  @override
  List<Object?> get props => [name, email, password];
}

class AuthLogin extends AuthEvent {
  final String email;
  final String password;

  AuthLogin({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthGoogleSignIn extends AuthEvent {}

class AuthAppleSignIn extends AuthEvent {}

class AuthLogout extends AuthEvent {}

class AuthCheckStatus extends AuthEvent {}

class AuthStatusChanged extends AuthEvent {
  final User? user;

  AuthStatusChanged({this.user});

  @override
  List<Object?> get props => [user];
}
