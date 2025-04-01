import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String type; // 'emergency', 'trigger', 'general', etc.
  final bool isRead;
  final String direction; // 'incoming', 'outgoing', or 'system'

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.direction = 'system', // Default to system for backward compatibility
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
      'isRead': isRead,
      'direction': direction.toLowerCase(), // Ensure lowercase for consistency
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    final direction = (map['direction'] ?? 'system').toString().toLowerCase();

    // Debug for troubleshooting
    if (direction == 'incoming') {
      print('DEBUG: Found an incoming notification: ${map['title']}');
    } else if (direction == 'outgoing') {
      print('DEBUG: Found an outgoing notification: ${map['title']}');
    }

    return NotificationItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      type: map['type'] ?? 'general',
      isRead: map['isRead'] ?? false,
      direction: direction, // Already lowercased
    );
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    String? type,
    bool? isRead,
    String? direction,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      direction: direction ?? this.direction,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  static const String _storageKey = 'app_notifications';

  // Add a notification to storage
  Future<void> addNotification(NotificationItem notification) async {
    // Debug logging
    print('Adding new notification:');
    print('  Title: ${notification.title}');
    print('  Direction: ${notification.direction}');
    print('  Type: ${notification.type}');

    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    // Add the new notification
    notifications.add(notification);

    // Sort notifications by timestamp, newest first
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Store back to shared preferences
    final jsonData = jsonEncode(notifications.map((n) => n.toMap()).toList());
    await prefs.setString(_storageKey, jsonData);

    // Verify storage
    print('Stored ${notifications.length} notifications');
  }

  // Get all notifications
  Future<List<NotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsString = prefs.getString(_storageKey);

    if (notificationsString == null || notificationsString.isEmpty) {
      print('No notifications found in storage');
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(notificationsString);
      final notificationList =
          decoded.map((item) => NotificationItem.fromMap(item)).toList();

      // Debug count by direction
      final incoming =
          notificationList.where((n) => n.direction == 'incoming').length;
      final outgoing =
          notificationList.where((n) => n.direction == 'outgoing').length;
      final system =
          notificationList.where((n) => n.direction == 'system').length;

      print('Retrieved ${notificationList.length} notifications:');
      print('  Incoming: $incoming');
      print('  Outgoing: $outgoing');
      print('  System: $system');

      return notificationList;
    } catch (e) {
      print('Error parsing notifications: $e');
      return [];
    }
  }

  // Mark a notification as read
  Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final updatedNotifications = notifications.map((notification) {
      if (notification.id == id) {
        return notification.copyWith(isRead: true);
      }
      return notification;
    }).toList();

    await prefs.setString(_storageKey,
        jsonEncode(updatedNotifications.map((n) => n.toMap()).toList()));
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = await getNotifications();

    final updatedNotifications = notifications.map((notification) {
      return notification.copyWith(isRead: true);
    }).toList();

    await prefs.setString(_storageKey,
        jsonEncode(updatedNotifications.map((n) => n.toMap()).toList()));
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode([]));
    print('All notifications cleared');
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((notification) => !notification.isRead).length;
  }

  // Get notifications filtered by direction
  Future<List<NotificationItem>> getFilteredNotifications(
      String direction) async {
    final notifications = await getNotifications();
    if (direction == 'all') {
      print('Returning all ${notifications.length} notifications');
      return notifications;
    }

    final directionLower =
        direction.toLowerCase(); // Case insensitive comparison
    final filteredList = notifications
        .where((notification) =>
            notification.direction.toLowerCase() == directionLower)
        .toList();

    print('Filtered $direction notifications: found ${filteredList.length}');

    // If we didn't find any, log a warning
    if (filteredList.isEmpty) {
      print('WARNING: No notifications found with direction "$direction"');
      print(
          'Available directions: ${notifications.map((n) => n.direction).toSet().join(', ')}');
    }

    return filteredList;
  }

  // Debug method to print notification stats
  Future<void> debugPrintNotificationStats() async {
    final notifications = await getNotifications();
    final incoming =
        notifications.where((n) => n.direction == 'incoming').length;
    final outgoing =
        notifications.where((n) => n.direction == 'outgoing').length;
    final system = notifications.where((n) => n.direction == 'system').length;
    final otherDirections = notifications
        .where((n) => !['incoming', 'outgoing', 'system'].contains(n.direction))
        .map((n) => n.direction)
        .toSet();

    print('--- Notification Stats ---');
    print('Total notifications: ${notifications.length}');
    print('Incoming notifications: $incoming');
    print('Outgoing notifications: $outgoing');
    print('System notifications: $system');
    if (otherDirections.isNotEmpty) {
      print('Other directions found: ${otherDirections.join(', ')}');
    }
    print('--------------------------');
  }

  // For debugging - create test notifications
  Future<void> createTestNotifications() async {
    // Clear existing notifications first
    await clearAllNotifications();

    // Create an incoming notification
    await addNotification(
      NotificationItem(
        id: 'test_incoming_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Incoming Alert',
        message: 'This is a test incoming notification',
        timestamp: DateTime.now(),
        type: 'emergency',
        direction: 'incoming',
      ),
    );

    // Create an outgoing notification
    await addNotification(
      NotificationItem(
        id: 'test_outgoing_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Outgoing Alert',
        message: 'This is a test outgoing notification',
        timestamp: DateTime.now(),
        type: 'emergency',
        direction: 'outgoing',
      ),
    );

    // Create a system notification
    await addNotification(
      NotificationItem(
        id: 'test_system_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test System Message',
        message: 'This is a test system notification',
        timestamp: DateTime.now(),
        type: 'general',
        direction: 'system',
      ),
    );

    print('Created 3 test notifications (incoming, outgoing, system)');
  }
}

// Helper method to format timestamps consistently across the app
String formatTimestamp(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inDays > 0) {
    return DateFormat('MMM d, h:mm a').format(timestamp);
  } else if (difference.inHours > 0) {
    return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  } else {
    return 'Just now';
  }
}

class NotificationListItem extends StatelessWidget {
  final NotificationItem notification;
  final Function onTap;

  const NotificationListItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;
    Color backgroundColor;

    // Determine icon and color based on notification type and direction
    if (notification.type == 'emergency') {
      // Emergency alerts
      if (notification.direction == 'incoming') {
        iconData = Icons.emergency;
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.2);
      } else if (notification.direction == 'outgoing') {
        iconData = Icons.emergency_share;
        iconColor = Colors.orange;
        backgroundColor = Colors.orange.withOpacity(0.2);
      } else {
        // System emergency notifications
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.red;
        backgroundColor = Colors.red.withOpacity(0.2);
      }
    } else if (notification.type == 'trigger') {
      // Trigger alerts
      iconData = Icons.notifications_active;
      iconColor = Colors.orange;
      backgroundColor = Colors.orange.withOpacity(0.2);
    } else {
      // Default for other notifications
      iconData = Icons.notifications;
      iconColor = Colors.blue;
      backgroundColor = Colors.blue.withOpacity(0.2);
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: TextStyle(
                  fontWeight:
                      notification.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            ),
            // Add a small badge to indicate direction
            if (notification.direction == 'incoming' ||
                notification.direction == 'outgoing')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: notification.direction == 'incoming'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notification.direction == 'incoming' ? 'Received' : 'Sent',
                  style: TextStyle(
                    fontSize: 10,
                    color: notification.direction == 'incoming'
                        ? Colors.green
                        : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              formatTimestamp(notification.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => onTap(),
      ),
    );
  }
}
