import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';

class EmergencyContactsRepository {
  final FirebaseFirestore _firestore;

  EmergencyContactsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Get emergency contacts for a user
  Stream<List<EmergencyContact>> getEmergencyContacts(String userId) {
    return _usersCollection
        .doc(userId)
        .collection('emergencyContacts') // Ensure the correct name
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return EmergencyContact.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Add a new emergency contact
  Future<String> addEmergencyContact(
      String userId, EmergencyContact contact) async {
    try {
      final docRef = await _usersCollection
          .doc(userId)
          .collection('emergencyContacts') // Ensure consistency
          .add({
        ...contact.toMap(),
        'createdAt': FieldValue.serverTimestamp(), // ✅ Always add createdAt
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add emergency contact: ${e.toString()}');
    }
  }

  // Update an existing emergency contact
  Future<void> updateEmergencyContact(
      String userId, EmergencyContact contact) async {
    try {
      await _usersCollection
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contact.id)
          .update(contact.toMap());
    } catch (e) {
      throw Exception('Failed to update emergency contact: ${e.toString()}');
    }
  }

  // Delete an emergency contact
  Future<void> deleteEmergencyContact(String userId, String contactId) async {
    try {
      await _usersCollection
          .doc(userId)
          .collection('emergencyContacts')
          .doc(contactId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete emergency contact: ${e.toString()}');
    }
  }

  // Send emergency alert
  Future<void> sendEmergencyAlert(String userId, String contactId,
      {String? customMessage}) async {
    try {
      // Log detailed information
      print('Sending Emergency Alert:');
      print('- Sender User ID: $userId');
      print('- Contact/Recipient ID: $contactId');
      print('- Custom Message: $customMessage');

      // Verify contact exists
      final contactDoc =
          await _firestore.collection('users').doc(contactId).get();

      if (!contactDoc.exists) {
        throw Exception('Recipient user not found');
      }

      // Additional validation and send logic
      await _firestore.collection('emergency_alerts').add({
        'senderId': userId,
        'recipientId': contactId,
        'message': customMessage ?? 'Emergency alert!',
        'timestamp': FieldValue.serverTimestamp(),
        'mediaUrls': [], // Add empty mediaUrls array for consistency
        'hasMedia': false,
        // Add any additional metadata
      });
    } catch (e) {
      print('Emergency Alert Error: $e');
      rethrow;
    }
  }

  // Send emergency alert with media attachments
  Future<void> sendEmergencyAlertWithMedia(
    String userId,
    String contactId, {
    String? customMessage,
    List<String> mediaUrls = const [],
  }) async {
    try {
      // Log detailed information
      print('Sending Emergency Alert with Media:');
      print('- Sender User ID: $userId');
      print('- Contact/Recipient ID: $contactId');
      print('- Custom Message: $customMessage');
      print('- Media URLs count: ${mediaUrls.length}');

      // Verify contact exists
      final contactDoc =
          await _firestore.collection('users').doc(contactId).get();

      if (!contactDoc.exists) {
        throw Exception('Recipient user not found');
      }

      // Get the sender's information
      final senderDoc = await _firestore.collection('users').doc(userId).get();
      final senderData = senderDoc.data() as Map<String, dynamic>?;
      final senderName = senderData?['name'] ?? 'Unknown User';

      // Additional validation and send logic
      await _firestore.collection('emergency_alerts').add({
        'senderId': userId,
        'senderName': senderName,
        'recipientId': contactId,
        'message': customMessage ?? 'Emergency alert!',
        'timestamp': FieldValue.serverTimestamp(),
        'mediaUrls': mediaUrls,
        'hasMedia': mediaUrls.isNotEmpty,
        'mediaCount': mediaUrls.length,
        'status': 'sent',
      });

      // Also add to dashboard_alerts for admin dashboard (if you have this feature)
      await _firestore.collection('dashboard_alerts').add({
        'senderId': userId,
        'senderName': senderName,
        'receiverId': contactId,
        'receiverName': contactDoc.exists
            ? (contactDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
            : 'Unknown',
        'content': customMessage ?? 'Emergency alert!',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'emergency_with_media',
        'status': 'pending',
        'isHandled': false,
        'handledBy': '',
        'handledAt': null,
        'mediaUrls': mediaUrls,
        'hasMedia': mediaUrls.isNotEmpty,
        'mediaCount': mediaUrls.length,
      });
    } catch (e) {
      print('Emergency Alert with Media Error: $e');
      rethrow;
    }
  }

  // Follow another user
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

      // Add to emergency contacts
      await addEmergencyContact(currentUserId, emergencyContact);

      // Add to following collection
      await _usersCollection
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .set({
        'userId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add to followers collection of target user
      await _usersCollection
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to follow user: ${e.toString()}');
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Remove from following collection
      await _usersCollection
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .delete();

      // Remove from followers collection of target user
      await _usersCollection
          .doc(targetUserId)
          .collection('followers')
          .doc(currentUserId)
          .delete();

      // Find and remove the associated emergency contact
      final querySnapshot = await _usersCollection
          .doc(currentUserId)
          .collection('emergencyContacts')
          .where('userId', isEqualTo: targetUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
      }
    } catch (e) {
      throw Exception('Failed to unfollow user: ${e.toString()}');
    }
  }

  // Search for users to follow
  Future<List<Map<String, dynamic>>> searchUsers(
      String query, String currentUserId) async {
    try {
      // Convert query to lowercase for case-insensitive search
      final lowercaseQuery = query.toLowerCase();

      // Perform more flexible search across name and email
      final querySnapshot = await _firestore
          .collection('users')
          .where('searchTokens', arrayContains: lowercaseQuery)
          .limit(20)
          .get();

      // Get list of users I'm already following
      final followingSnapshot = await _usersCollection
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
      print('Search error: $e'); // Add detailed logging
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }

  Future<void> sendDirectEmergencyAlert(
      String senderId, String receiverUserId, String message) async {
    try {
      // Create the emergency notification for the receiver
      await _firestore.collection('emergency_notifications').add({
        'senderId': senderId,
        'receiverId': receiverUserId,
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'emergency_message',
        'mediaUrls': [], // Add empty mediaUrls array for consistency
        'hasMedia': false,
      });

      // Also add to dashboard_alerts for admin dashboard
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final receiverDoc =
          await _firestore.collection('users').doc(receiverUserId).get();

      await _firestore.collection('dashboard_alerts').add({
        'senderId': senderId,
        'senderName': senderDoc.exists
            ? (senderDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
            : 'Unknown',
        'receiverId': receiverUserId,
        'receiverName': receiverDoc.exists
            ? (receiverDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
            : 'Unknown',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'direct_emergency',
        'status': 'pending',
        'isHandled': false,
        'handledBy': '',
        'handledAt': null,
        'mediaUrls': [],
        'hasMedia': false,
      });
    } catch (e) {
      throw Exception('Failed to send direct emergency alert: ${e.toString()}');
    }
  }

  // New method for sending direct emergency alerts with media
  Future<void> sendDirectEmergencyAlertWithMedia(
    String senderId,
    String receiverUserId,
    String message, {
    List<String> mediaUrls = const [],
  }) async {
    try {
      // Create the emergency notification for the receiver
      await _firestore.collection('emergency_notifications').add({
        'senderId': senderId,
        'receiverId': receiverUserId,
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'emergency_message_with_media',
        'mediaUrls': mediaUrls,
        'hasMedia': mediaUrls.isNotEmpty,
        'mediaCount': mediaUrls.length,
      });

      // Also add to dashboard_alerts for admin dashboard
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final receiverDoc =
          await _firestore.collection('users').doc(receiverUserId).get();

      await _firestore.collection('dashboard_alerts').add({
        'senderId': senderId,
        'senderName': senderDoc.exists
            ? (senderDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
            : 'Unknown',
        'receiverId': receiverUserId,
        'receiverName': receiverDoc.exists
            ? (receiverDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown'
            : 'Unknown',
        'content': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'direct_emergency_with_media',
        'status': 'pending',
        'isHandled': false,
        'handledBy': '',
        'handledAt': null,
        'mediaUrls': mediaUrls,
        'hasMedia': mediaUrls.isNotEmpty,
        'mediaCount': mediaUrls.length,
      });
    } catch (e) {
      throw Exception(
          'Failed to send direct emergency alert with media: ${e.toString()}');
    }
  }
}
