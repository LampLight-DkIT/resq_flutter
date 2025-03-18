import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  // Stream to listen for auth state changes
  Stream<User?> get userChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Email/Password Sign Up
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update the user's display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(userCredential.user!, name, email);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'The email address is already in use.';
          break;
        case 'weak-password':
          message = 'The password is too weak.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        default:
          message = e.message ?? 'An error occurred during sign up.';
      }

      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Email/Password Login
  Future<User?> login({required String email, required String password}) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user document exists, if not create it
      if (userCredential.user != null) {
        await _ensureUserDocument(userCredential.user!);
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'user-disabled':
          message = 'This user has been disabled.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        default:
          message = e.message ?? 'An error occurred during login.';
      }

      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign In process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      // Get Google auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      User? user = userCredential.user;

      // Ensure user document exists
      if (user != null) {
        await _ensureUserDocument(user);
      }

      return user;
    } catch (e) {
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  // Apple Sign In
  Future<User?> signInWithApple() async {
    try {
      // Generate a random nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request Apple sign in credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuthCredential for Firebase
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in to Firebase with Apple credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(oauthCredential);
      User? user = userCredential.user;

      // Get user's name from the Apple credential
      // Note: Apple only provides name on first sign-in
      String name =
          '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
              .trim();
      if (name.isEmpty) {
        name = user?.displayName ?? 'Apple User';
      }

      // Ensure user document exists
      if (user != null) {
        if (userCredential.additionalUserInfo?.isNewUser == true) {
          // Create user document in Firestore for new Apple users
          await _createUserDocument(user, name, user.email ?? 'No Email');
        } else {
          await _ensureUserDocument(user);
        }
      }

      return user;
    } catch (e) {
      throw Exception('Failed to sign in with Apple: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut(); // Sign out from Google
      await _firebaseAuth.signOut(); // Sign out from Firebase
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Helper method to create a user document in Firestore
  Future<void> _createUserDocument(User user, String name, String email) async {
    try {
      // Check if document already exists
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        // Create new document only if it doesn't exist
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'photoURL': user.photoURL,
          'phoneNumber': user.phoneNumber ?? '',
          'countryCode': '',
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'authProvider': user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'email',
        });
      } else {
        // Update lastLoginAt timestamp if document exists
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error creating user document: ${e.toString()}');
      // Don't throw here, just log it - we don't want to block auth flow
    }
  }

  // Ensure user document exists after login
  Future<void> _ensureUserDocument(User user) async {
    try {
      // Check if document exists
      final docSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      if (!docSnapshot.exists) {
        // Create document if it doesn't exist
        await _createUserDocument(
            user, user.displayName ?? 'User', user.email ?? 'No Email');
      } else {
        // Update lastLoginAt
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error ensuring user document: ${e.toString()}');
      // Don't throw here, just log the error
    }
  }

  // Method to update user profile data
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? phoneNumber,
    String? countryCode,
    String? bio,
    String? photoURL,
  }) async {
    try {
      // Check if document exists first
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (!docSnapshot.exists) {
        // Create the document if it doesn't exist
        User? currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          await _createUserDocument(
              currentUser,
              name ?? currentUser.displayName ?? 'User',
              email ?? currentUser.email ?? 'No Email');
        } else {
          throw Exception(
              'User document not found and no current user to create it');
        }
      }

      // Create a map with non-null fields only
      final Map<String, dynamic> updatedData = {};

      if (name != null) updatedData['name'] = name;
      if (email != null) updatedData['email'] = email;
      if (phoneNumber != null) updatedData['phoneNumber'] = phoneNumber;
      if (countryCode != null) updatedData['countryCode'] = countryCode;
      if (bio != null) updatedData['bio'] = bio;
      if (photoURL != null) updatedData['photoURL'] = photoURL;

      // Add last updated timestamp
      updatedData['updatedAt'] = FieldValue.serverTimestamp();

      // Update the user document
      await _firestore.collection('users').doc(uid).update(updatedData);

      // If email was updated, update it in Firebase Auth as well
      if (email != null && _firebaseAuth.currentUser != null) {
        await _firebaseAuth.currentUser!.updateEmail(email);
      }
    } catch (e) {
      print('Error updating profile: ${e.toString()}');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Method to fetch user profile data
  Future<Map<String, dynamic>> getUserProfile(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();

      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>;
      } else {
        // Create document if it doesn't exist
        User? currentUser = _firebaseAuth.currentUser;
        if (currentUser != null) {
          await _createUserDocument(
              currentUser,
              currentUser.displayName ?? 'User',
              currentUser.email ?? 'No Email');

          // Fetch the newly created document
          final newSnapshot =
              await _firestore.collection('users').doc(uid).get();
          if (newSnapshot.exists) {
            return newSnapshot.data() as Map<String, dynamic>;
          }
        }

        // Return empty data if document doesn't exist and couldn't be created
        return {
          'uid': uid,
          'name': 'User',
          'email': '',
          'phoneNumber': '',
          'countryCode': '',
          'bio': '',
          'photoURL': null,
        };
      }
    } catch (e) {
      print('Error fetching profile: ${e.toString()}');
      // Return empty data on error
      return {
        'uid': uid,
        'name': 'User',
        'email': '',
        'phoneNumber': '',
        'countryCode': '',
        'bio': '',
        'photoURL': null,
      };
    }
  }

  // Helper method to generate a random nonce for Apple sign in
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  // Helper method to generate SHA256 hash of string for Apple sign in
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
