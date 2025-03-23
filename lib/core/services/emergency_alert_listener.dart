import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/core/services/trigger_notification_service.dart';
import 'package:resq/features/notification/notification_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmergencyAlertListener {
  static final EmergencyAlertListener _instance =
      EmergencyAlertListener._internal();
  factory EmergencyAlertListener() => _instance;

  EmergencyAlertListener._internal();

  bool _isInitialized = false;

  // Initialize the emergency alert listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('EmergencyAlertListener: Cannot initialize - user not logged in');
      return;
    }

    print('Initializing EmergencyAlertListener for user: ${currentUser.uid}');

    try {
      // Check existing alerts first
      await _checkExistingAlerts(currentUser.uid);

      // Set up listener for incoming emergency alerts
      _setupEmergencyAlertListener(currentUser.uid);

      _isInitialized = true;
      print('EmergencyAlertListener successfully initialized');
    } catch (e) {
      print('Error initializing EmergencyAlertListener: $e');
    }
  }

  // Check for existing unprocessed alerts
  Future<void> _checkExistingAlerts(String userId) async {
    try {
      print('Checking for existing emergency alerts for user: $userId');

      // Get alerts from the last 24 hours
      final timestamp = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );

      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('recipientId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: timestamp)
          .orderBy('timestamp', descending: true)
          .get();

      print('Found ${alertsSnapshot.docs.length} existing emergency alerts');

      // Process each alert
      for (var doc in alertsSnapshot.docs) {
        final alertData = doc.data();
        await _processIncomingAlert(alertData, doc.id, isExisting: true);
      }
    } catch (e) {
      print('Error checking existing alerts: $e');
    }
  }

  // Set up listener for incoming emergency alerts in Firestore
  void _setupEmergencyAlertListener(String userId) {
    print('Setting up real-time listener for emergency alerts...');

    // Listen to the emergency alerts collection where this user is the recipient
    FirebaseFirestore.instance
        .collection('emergency_alerts')
        .where('recipientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      print(
          'Received snapshot with ${snapshot.docs.length} alerts and ${snapshot.docChanges.length} changes');
      _handleIncomingAlerts(snapshot);
    }, onError: (error) {
      print('Error in emergency alert listener: $error');
    });

    print('Emergency alert listener set up for user: $userId');
  }

  // Handle incoming emergency alerts from Firestore snapshot
  void _handleIncomingAlerts(QuerySnapshot snapshot) {
    // Process only new documents since the last check
    for (var change in snapshot.docChanges) {
      print(
          'Alert change type: ${change.type.name}, document ID: ${change.doc.id}');

      if (change.type == DocumentChangeType.added) {
        final alertData = change.doc.data() as Map<String, dynamic>?;
        if (alertData == null) {
          print('Alert data is null for document ID: ${change.doc.id}');
          continue;
        }

        // Process the incoming alert
        _processIncomingAlert(alertData, change.doc.id);
      }
    }
  }

  // Process an incoming emergency alert and create notification
  Future<void> _processIncomingAlert(
      Map<String, dynamic> alertData, String alertId,
      {bool isExisting = false}) async {
    try {
      print('Processing alert: $alertId (${isExisting ? 'existing' : 'new'})');
      print('Alert data: $alertData');

      // Check if we've already processed this alert (to prevent duplicates)
      final prefs = await SharedPreferences.getInstance();
      final processedAlerts = prefs.getStringList('processed_alerts') ?? [];

      if (processedAlerts.contains(alertId)) {
        print('Alert already processed: $alertId');
        return;
      }

      final senderId = alertData['senderId'] as String?;
      final timestamp = alertData['timestamp'] as Timestamp?;

      print(
          'Alert from sender: $senderId with timestamp: ${timestamp?.toDate()}');

      // Skip old alerts (older than 24 hours)
      if (timestamp != null) {
        final alertTime = timestamp.toDate();
        final now = DateTime.now();
        if (now.difference(alertTime).inHours > 24) {
          print('Skipping old alert: $alertId');
          return;
        }
      }

      // Get sender information
      String senderName = 'Unknown';
      if (senderId != null) {
        try {
          final senderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();
          if (senderDoc.exists) {
            final senderData = senderDoc.data();
            senderName = senderData?['displayName'] ??
                senderData?['fullName'] ??
                senderData?['name'] ??
                'Unknown';
            print('Found sender name: $senderName');
          } else {
            print('Sender document does not exist: $senderId');
          }
        } catch (e) {
          print('Error fetching sender information: $e');
        }
      }

      // Extract alert details
      final message = alertData['message'] as String? ?? 'Emergency alert!';
      final location = alertData['location'] as String?;

      print(
          'Creating incoming notification for alert: $alertId from $senderName');

      // Create the incoming notification using TriggerNotificationService
      await TriggerNotificationService().handleIncomingEmergencyAlert(
        contactName: senderName,
        additionalInfo: message,
        location: location,
      );

      // Mark as processed
      processedAlerts.add(alertId);
      await prefs.setStringList('processed_alerts', processedAlerts);

      print(
          'Successfully processed incoming emergency alert from $senderName (ID: $alertId)');

      // Verify notification was created
      await NotificationService().debugPrintNotificationStats();
    } catch (e) {
      print('Error processing incoming alert: $e');
    }
  }

  // For manual testing - create a test incoming alert
  Future<void> createTestIncomingAlert() async {
    print('Creating test incoming emergency alert');
    await TriggerNotificationService().handleIncomingEmergencyAlert(
      contactName: "Test Emergency Contact",
      additionalInfo: "This is a test incoming emergency alert",
      location: "19.9820935, 73.8496078",
    );

    // Verify the notification was created
    await NotificationService().debugPrintNotificationStats();
  }
}
