import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for method channel
import 'package:resq/core/services/emergency_alert_listener.dart'; // Add this import
import 'package:resq/features/notification/notification_items.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<NotificationItem> _notifications = [];
  List<NotificationItem> _filteredNotifications = [];
  bool _isLoading = true;
  bool _hasDebugMode = false; // Set to true only for debugging
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Filter options
  String _currentFilter = 'all'; // 'all', 'incoming', 'outgoing'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final notificationService = NotificationService();

    // Print debug info about current notifications
    await notificationService.debugPrintNotificationStats();

    // For testing only - uncomment to create test notifications
    // if (_hasDebugMode) {
    //   await notificationService.createTestNotifications();
    // }

    // Load all notifications
    final notifications = await notificationService.getNotifications();

    setState(() {
      _notifications = notifications;
      _applyFilter(); // Apply current filter
      _isLoading = false;
    });
  }

  // Apply the selected filter
  void _applyFilter() {
    if (_currentFilter == 'all') {
      _filteredNotifications = List.from(_notifications);
    } else {
      // Case-insensitive filtering
      _filteredNotifications = _notifications
          .where((notification) =>
              notification.direction.toLowerCase() ==
              _currentFilter.toLowerCase())
          .toList();
    }

    // Debug print
    print('Applied filter: $_currentFilter');
    print('Filtered notifications count: ${_filteredNotifications.length}');

    // Print details if the count is unexpected
    if (_filteredNotifications.isEmpty && _notifications.isNotEmpty) {
      print('WARNING: Filter $_currentFilter returned no results!');
      print(
          'Available directions: ${_notifications.map((n) => n.direction).toSet().join(', ')}');
    }
  }

  // Change the current filter
  void _changeFilter(String filter) {
    print('Changing filter from $_currentFilter to $filter');
    setState(() {
      _currentFilter = filter;
      _applyFilter();
    });
  }

  /// Clears all notifications after a confirmation.
  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Notifications"),
        content:
            const Text("Are you sure you want to clear all notifications?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await NotificationService().clearAllNotifications();
              Navigator.of(context).pop();
              _loadNotifications();
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  // Secret debug method - quickly tap the app title 5 times to create a test incoming notification
  void _handleTitleTap() {
    final now = DateTime.now();

    // Reset counter if it's been more than 3 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 3) {
      _tapCount = 0;
    }

    _lastTapTime = now;
    _tapCount++;

    // After 5 quick taps, create a test notification
    if (_tapCount >= 5) {
      _tapCount = 0;
      _createTestIncomingNotification();
      HapticFeedback.heavyImpact(); // Add haptic feedback to confirm
    }
  }

  // Create a test incoming notification for debugging
  Future<void> _createTestIncomingNotification() async {
    try {
      print("Creating test incoming notification...");

      // Two ways to create a test notification:

      // 1. Using EmergencyAlertListener (preferred)
      await EmergencyAlertListener().createTestIncomingAlert();

      // 2. Directly creating a notification (backup method)
      // await NotificationService().addNotification(
      //   NotificationItem(
      //     id: 'test_incoming_${DateTime.now().millisecondsSinceEpoch}',
      //     title: 'Emergency Alert Received',
      //     message: 'You received an emergency alert from Test Contact',
      //     timestamp: DateTime.now(),
      //     type: 'emergency',
      //     direction: 'incoming',
      //   ),
      // );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification created'),
          duration: Duration(seconds: 1),
        ),
      );

      // Refresh notifications
      _loadNotifications();
    } catch (e) {
      print("Error creating test notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text("Notifications"),
        ),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
        actions: [
          // Only show the clear button if there are notifications.
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: "Clear All Notifications",
              onPressed: _clearAllNotifications,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _filterButton('All', 'all'),
                _filterButton('Incoming', 'incoming'),
                _filterButton('Outgoing', 'outgoing'),
                if (_hasDebugMode) _filterButton('System', 'system'),
              ],
            ),
          ),

          // Notifications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _notifications.isEmpty
                                  ? "No notifications available."
                                  : "No ${_currentFilter.toUpperCase()} notifications available.",
                              style: const TextStyle(fontSize: 16),
                            ),
                            // Debug info - only show in debug mode
                            if (_hasDebugMode && _notifications.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Text(
                                "Available types: ${_notifications.map((n) => n.direction).toSet().join(', ')}",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _filteredNotifications.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final notification = _filteredNotifications[index];
                            return NotificationListItem(
                              notification: notification,
                              onTap: () async {
                                // Mark this notification as read when tapped
                                await NotificationService()
                                    .markAsRead(notification.id);
                                _loadNotifications(); // Refresh the list
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, String filter) {
    bool isSelected = _currentFilter == filter;

    return ElevatedButton(
      onPressed: () => _changeFilter(filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
        foregroundColor: isSelected ? Colors.white : null,
      ),
      child: Text(label),
    );
  }
}
