// lib/features/user/repository/user_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/repository/chat_repository.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final ChatRepository _chatRepository;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _chatRepository = ChatRepository();

  // Get user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user details: ${e.toString()}');
    }
  }

  // Get user by ID
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }

      final userData = doc.data() as Map<String, dynamic>;
      return {
        ...userData,
        'id': doc.id,
      };
    } catch (e) {
      throw Exception('Failed to get user by ID: ${e.toString()}');
    }
  }

  // Follow a user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // Get the target user's profile
      final userDoc =
          await _firestore.collection('users').doc(targetUserId).get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // Create an emergency contact that's linked to the user
      final emergencyContact = EmergencyContact(
        id: '', // Will be assigned by Firestore
        name: userData['name'] ?? 'User',
        phoneNumber: userData['phoneNumber'] ?? '',
        countryCode: userData['countryCode'] ?? '+1',
        relation: 'App User',
        secretMessage: 'Help! Emergency!',
        isFollowing: true,
        userId: targetUserId,
        photoURL: userData['photoURL'],
      );

      // Add to emergency contacts collection
      final contactRef = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('emergencyContacts')
          .add(emergencyContact.toMap());

      // Add to following collection
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .set({
        'userId': targetUserId,
        'contactId': contactRef.id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add to followers collection of target user
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create a chat room for these users
      await _chatRepository.createChatRoom(
        currentUserId: currentUserId,
        otherUserId: targetUserId,
        otherUserName: userData['name'] ?? 'User',
        otherUserPhotoUrl: userData['photoURL'],
      );
    } catch (e) {
      throw Exception('Failed to follow user: ${e.toString()}');
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Get the contact ID from the following collection
      final followingDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      if (followingDoc.exists) {
        final contactId = followingDoc.data()?['contactId'];
        if (contactId != null) {
          // Remove from emergency contacts
          await _firestore
              .collection('users')
              .doc(currentUserId)
              .collection('emergencyContacts')
              .doc(contactId)
              .delete();
        }
      }

      // Remove from following collection
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .delete();

      // Remove from followers collection of target user
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .delete();
    } catch (e) {
      throw Exception('Failed to unfollow user: ${e.toString()}');
    }
  }

  // Check if following a user
  Future<bool> isFollowingUser(
      String currentUserId, String targetUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check follow status: ${e.toString()}');
    }
  }

  // Search for users
  Future<List<Map<String, dynamic>>> searchUsers(
      String query, String currentUserId) async {
    try {
      QuerySnapshot querySnapshot;

      // If query is empty, return all users (limited to prevent excessive data)
      if (query.isEmpty) {
        querySnapshot = await _firestore.collection('users').limit(20).get();
      } else {
        // Otherwise search by name
        final lowerQuery = query.toLowerCase();
        querySnapshot = await _firestore
            .collection('users')
            .orderBy('name')
            .startAt([lowerQuery]).endAt(['$lowerQuery\uf8ff']).get();
      }

      // Get list of users I'm already following
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();

      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toSet();

      return querySnapshot.docs
          .where((doc) => doc.id != currentUserId) // Exclude current user
          .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
          'isFollowing': followingIds.contains(doc.id),
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }
}
