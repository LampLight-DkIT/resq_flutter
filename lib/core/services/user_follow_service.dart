import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserFollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Follow a user
  Future<void> followUser(String targetUserId) async {
    if (currentUserId == null) return;

    // Add to current user's following collection
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .set({
      'userId': targetUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Add to target user's followers collection
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .set({
      'userId': currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    if (currentUserId == null) return;

    // Remove from current user's following
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .delete();

    // Remove from target user's followers
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId)
        .delete();
  }

  // Get users the current user is following
  Stream<List<UserProfile>> getFollowing() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserProfile> followingUsers = [];

      for (var doc in snapshot.docs) {
        String userId = doc.data()['userId'];
        var userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          followingUsers.add(UserProfile.fromMap(userDoc.data()!, userId));
        }
      }

      return followingUsers;
    });
  }

  // Get users following the current user
  Stream<List<UserProfile>> getFollowers() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('followers')
        .snapshots()
        .asyncMap((snapshot) async {
      List<UserProfile> followers = [];

      for (var doc in snapshot.docs) {
        String userId = doc.data()['userId'];
        var userDoc = await _firestore.collection('users').doc(userId).get();

        if (userDoc.exists) {
          followers.add(UserProfile.fromMap(userDoc.data()!, userId));
        }
      }

      return followers;
    });
  }
}

class UserProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final String? status;
  final bool isEmergencyContact;
  final bool isOnline;
  final DateTime? lastSeen;

  UserProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.status,
    this.isEmergencyContact = false,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String id) {
    return UserProfile(
      id: id,
      name: map['name'] ?? 'Unknown',
      photoUrl: map['photoUrl'],
      status: map['status'],
      isEmergencyContact: map['isEmergencyContact'] ?? false,
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'status': status,
      'isEmergencyContact': isEmergencyContact,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }
}
