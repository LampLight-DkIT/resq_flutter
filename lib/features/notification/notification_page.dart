import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  // Sample notifications list. In a real app, these might come from an API or local database.
  List<String> _notifications = [
    "Welcome to the app! Enjoy your stay.",
    "Your profile has been updated successfully.",
    "You have received a new message.",
    "Don't miss our latest features and updates.",
  ];

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
            onPressed: () {
              setState(() {
                _notifications.clear();
              });
              Navigator.of(context).pop();
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
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
      body: _notifications.isEmpty
          ? const Center(
              child: Text(
                "No notifications available.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(8.0),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(notification),
                  // Optionally, you can add a subtitle or a timestamp here.
                );
              },
            ),
    );
  }
}
