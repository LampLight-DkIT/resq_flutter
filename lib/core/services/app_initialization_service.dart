// lib/core/services/app_initialization_service.dart

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:resq/offline/chat_cache/chat_cache_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to handle all app initialization tasks including Hive setup,
/// Firebase initialization, etc.
class AppInitializationService {
  final Connectivity _connectivity = Connectivity();
  late final SharedPreferences _prefs;
  late final ChatCacheRepository _chatCacheRepository;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Singleton pattern
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  /// Initialize all necessary services for the app
  Future<bool> initializeApp() async {
    if (_isInitialized) return true;

    try {
      // Initialize Firebase first
      await Firebase.initializeApp();

      // Initialize SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Initialize Hive
      await _initializeHive();

      // Initialize ChatCacheRepository
      _chatCacheRepository = ChatCacheRepository();
      await _chatCacheRepository.init();

      // Set initialization flag
      _isInitialized = true;

      // Listen for connectivity changes to process pending messages
      _setupConnectivityListener();

      return true;
    } catch (e) {
      debugPrint('Error initializing app: $e');
      return false;
    }
  }

  /// Initialize Hive for local storage
  Future<void> _initializeHive() async {
    final appDocumentDir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDir.path);
  }

  /// Setup connectivity listener to process pending messages when coming back online
  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        // We're back online, trigger process of pending messages
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // This will need to be accessed via a global BLoC provider
          // or you can use a service locator pattern to get the ChatBloc
          _triggerPendingMessagesProcessing();
        }
      }
    } as void Function(List<ConnectivityResult> event)?);
  }

  /// Trigger processing of pending messages in all relevant ChatBlocs
  void _triggerPendingMessagesProcessing() {
    // This is just a template - the actual implementation will depend on how
    // you access your ChatBloc instances
    // Example:
    // GlobalBlocProvider.of<ChatBloc>(navigatorKey.currentContext!).add(ProcessPendingMessages());

    // Alternatively, you could use a service locator:
    // GetIt.instance<ChatBloc>().add(ProcessPendingMessages());
  }

  /// Get the chat cache repository instance
  ChatCacheRepository get chatCacheRepository {
    if (!_isInitialized) {
      throw Exception(
          'AppInitializationService must be initialized before accessing chatCacheRepository');
    }
    return _chatCacheRepository;
  }

  /// Check if the user is online
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Clear all app data (for logout)
  Future<void> clearAppData() async {
    if (!_isInitialized) return;

    await _chatCacheRepository.clearAllCaches();
    await _prefs.clear();
  }
}
