//
import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadProfile extends ProfileEvent {
  final String userId;

  LoadProfile({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class UpdateProfile extends ProfileEvent {
  final String userId;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? countryCode;
  final String? bio;
  final String? photoURL;

  UpdateProfile({
    required this.userId,
    this.name,
    this.email,
    this.phoneNumber,
    this.countryCode,
    this.bio,
    this.photoURL,
  });

  @override
  List<Object?> get props =>
      [userId, name, email, phoneNumber, countryCode, bio, photoURL];
}
