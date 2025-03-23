import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:resq/features/notification/notification_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle trigger notifications and emergency alerts
class TriggerNotificationService {
  static final TriggerNotificationService _instance =
      TriggerNotificationService._internal();

  factory TriggerNotificationService() => _instance;

  TriggerNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    _isInitialized = true;
    debugPrint('TriggerNotificationService initialized successfully');
  }

  // Show a notification when a trigger phrase is detected
  Future<void> showTriggerActivatedNotification({
    required String contactName,
    String? additionalInfo,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'trigger_channel',
      'Emergency Alerts',
      channelDescription: 'Notifications for emergency trigger phrases',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.red,
      enableLights: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String message =
        'Your trigger phrase has been activated in chat with $contactName';
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\n$additionalInfo';
    }

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      'Emergency Alert Triggered',
      message,
      notificationDetails,
      payload: 'trigger_notification',
    );

    // Store in NotificationService for viewing in the app
    await NotificationService().addNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Emergency Alert Triggered',
        message: message,
        timestamp: DateTime.now(),
        type: 'trigger',
        isRead: false,
        direction: 'system', // System notification
      ),
    );

    debugPrint('Emergency alert notification sent and stored');
  }

  // Show notification when a trigger phrase is set or changed
  Future<void> showTriggerPhraseSetNotification(String phrase) async {
    if (!_isInitialized) {
      await initialize();
    }

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'settings_channel',
      'Settings Notifications',
      channelDescription: 'Notifications about settings changes',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      'Alert Trigger Phrase Set',
      'Your emergency trigger phrase has been set to: "$phrase"',
      notificationDetails,
      payload: 'settings_notification',
    );

    // Store notification in NotificationService
    await NotificationService().addNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Alert Trigger Phrase Set',
        message: 'Your emergency trigger phrase has been set to: "$phrase"',
        timestamp: DateTime.now(),
        type: 'general',
        isRead: false,
        direction: 'system', // System notification
      ),
    );
  }

  // Store emergency alert notification with direction
  Future<void> storeEmergencyAlert({
    required String title,
    required String message,
    String type = 'emergency',
    required String direction, // 'incoming', 'outgoing', or 'system'
  }) async {
    // Debug direction
    debugPrint('Creating emergency alert with direction: $direction');

    // Normalize direction to lowercase for consistency
    final normalizedDirection = direction.toLowerCase();

    // Store in NotificationService for viewing in the app
    await NotificationService().addNotification(
      NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        direction: normalizedDirection,
      ),
    );

    debugPrint(
        'Emergency alert stored in notifications: $title (direction: $normalizedDirection)');
  }

  // Store outgoing emergency alert
  Future<void> storeOutgoingEmergencyAlert({
    required String contactName,
    String? additionalInfo,
  }) async {
    String message = 'You sent an emergency alert to $contactName';
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\n$additionalInfo';
    }

    debugPrint('Creating outgoing emergency alert for $contactName');
    await storeEmergencyAlert(
      title: 'Emergency Alert Sent',
      message: message,
      direction: 'outgoing',
    );

    // Verify notification was saved
    await NotificationService().debugPrintNotificationStats();
  }

  // Store incoming emergency alert
  Future<void> storeIncomingEmergencyAlert({
    required String contactName,
    String? additionalInfo,
  }) async {
    String message = 'You received an emergency alert from $contactName';
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\n$additionalInfo';
    }

    debugPrint('Creating incoming emergency alert from $contactName');
    await storeEmergencyAlert(
      title: 'Emergency Alert Received',
      message: message,
      direction: 'incoming',
    );

    // Verify notification was saved
    await NotificationService().debugPrintNotificationStats();
  }

  // Get the current trigger phrase
  Future<String?> getTriggerPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alert_trigger_phrase');
  }

  // Display a system notification for emergency alerts
  Future<void> showEmergencyNotification({
    required String title,
    required String message,
    required String direction,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription: 'Critical notifications for emergency situations',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.red,
      enableLights: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'emergency.aiff',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      message,
      notificationDetails,
      payload: 'emergency_notification',
    );

    // Ensure direction is lowercase for consistency
    final normalizedDirection = direction.toLowerCase();
    debugPrint(
        'Showing emergency notification with direction: $normalizedDirection');

    // Also store in the app's notification system
    await storeEmergencyAlert(
      title: title,
      message: message,
      direction: normalizedDirection,
    );
  }

  // Show incoming emergency alert (combined notification and storage)
  Future<void> handleIncomingEmergencyAlert({
    required String contactName,
    String? additionalInfo,
    String? location,
  }) async {
    String message = 'You received an emergency alert from $contactName';
    if (location != null && location.isNotEmpty) {
      message += '\nLocation: $location';
    }
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\n$additionalInfo';
    }

    debugPrint('Handling incoming emergency alert from $contactName');

    // Show system notification
    await showEmergencyNotification(
      title: 'EMERGENCY: Alert from $contactName',
      message: message,
      direction: 'incoming',
    );
  }

  // Show outgoing emergency alert (combined notification and storage)
  Future<void> handleOutgoingEmergencyAlert({
    required String contactName,
    String? additionalInfo,
    String? location,
  }) async {
    String message = 'You sent an emergency alert to $contactName';
    if (location != null && location.isNotEmpty) {
      message += '\nLocation shared: $location';
    }
    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      message += '\n$additionalInfo';
    }

    debugPrint('Handling outgoing emergency alert to $contactName');

    // Show system notification
    await showEmergencyNotification(
      title: 'Emergency Alert Sent',
      message: message,
      direction: 'outgoing',
    );
  }
}
