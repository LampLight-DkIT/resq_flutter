import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String countryCode;
  final String relation;
  final String secretMessage;
  final bool isFollowing; // True if this is a user from the app who you follow
  final String? userId; // Firebase User ID if it's an app user (optional)
  final String? photoURL; // Profile photo URL if available

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.countryCode,
    required this.relation,
    required this.secretMessage,
    this.isFollowing = false,
    this.userId,
    this.photoURL,
  });

  // Create from a map (e.g., from Firestore)
  factory EmergencyContact.fromMap(Map<String, dynamic> map, String docId) {
    return EmergencyContact(
      id: docId,
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      countryCode: map['countryCode'] ?? '+1',
      relation: map['relation'] ?? 'Other',
      secretMessage: map['secretMessage'] ?? 'Help! Emergency!',
      isFollowing: map['isFollowing'] ?? false,
      userId: map['userId'],
      photoURL: map['photoURL'],
    );
  }

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'relation': relation,
      'secretMessage': secretMessage,
      'isFollowing': isFollowing,
      'userId': userId,
      'photoURL': photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Create a copy with updated fields
  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? countryCode,
    String? relation,
    String? secretMessage,
    bool? isFollowing,
    String? userId,
    String? photoURL,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      relation: relation ?? this.relation,
      secretMessage: secretMessage ?? this.secretMessage,
      isFollowing: isFollowing ?? this.isFollowing,
      userId: userId ?? this.userId,
      photoURL: photoURL ?? this.photoURL,
    );
  }
}
