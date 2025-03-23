import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_event.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/router/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _alertMessageController = TextEditingController();
  final TextEditingController _triggerPhraseController =
      TextEditingController();
  bool _isSendingAlert = false;
  String? _savedTriggerPhrase;

  @override
  void initState() {
    super.initState();
    _loadSavedTriggerPhrase();
  }

  Future<void> _loadSavedTriggerPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedTriggerPhrase = prefs.getString('alert_trigger_phrase');
      if (_savedTriggerPhrase != null) {
        _triggerPhraseController.text = _savedTriggerPhrase!;
      }
    });
  }

  @override
  void dispose() {
    _alertMessageController.dispose();
    _triggerPhraseController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (context.canPop()) {
      context.pop();
      return false;
    } else {
      // Navigate to home instead of exiting
      context.goToHome();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Safely navigate back without exiting the app
              if (context.canPop()) {
                context.pop();
              } else {
                context.goToHome();
              }
            },
          ),
        ),
        body: ListView(
          children: [
            // Trigger Phrase Setting
            ListTile(
              leading: const Icon(Icons.text_fields, color: Colors.blue),
              title: const Text("Set Alert Trigger Phrase"),
              subtitle: Text(_savedTriggerPhrase != null
                  ? "Current: \"$_savedTriggerPhrase\""
                  : "Set a phrase that will trigger an alert when sent"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showTriggerPhraseDialog();
              },
            ),
            const Divider(),

            // Custom Alert Option
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined,
                  color: Colors.orange),
              title: const Text("Send Custom Alert"),
              subtitle: const Text(
                  "Trigger an alert message to all your emergency contacts"),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                _showCustomAlertDialog();
              },
            ),
            const Divider(),

            // Logout option
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Show logout confirmation dialog
                _showLogoutConfirmationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Trigger Phrase Dialog
  void _showTriggerPhraseDialog() {
    // If we have a saved phrase, pre-fill the field
    if (_savedTriggerPhrase != null) {
      _triggerPhraseController.text = _savedTriggerPhrase!;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Alert Trigger Phrase"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "When you send this exact phrase in any chat, it will automatically trigger an emergency alert to that contact.",
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _triggerPhraseController,
              decoration: const InputDecoration(
                hintText: "e.g., Help me now",
                border: OutlineInputBorder(),
              ),
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // Save the trigger phrase
              final phrase = _triggerPhraseController.text.trim();

              if (phrase.isEmpty) {
                // Show error if empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter a trigger phrase"),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('alert_trigger_phrase', phrase);

              setState(() {
                _savedTriggerPhrase = phrase;
              });

              if (context.mounted) {
                Navigator.pop(context);

                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Alert trigger phrase set to: \"$phrase\""),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  // Custom Alert Dialog
  void _showCustomAlertDialog() {
    _alertMessageController.text = ""; // Clear previous text

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Custom Alert"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "This will send an emergency alert to all your emergency contacts.",
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _alertMessageController,
              decoration: const InputDecoration(
                hintText: "Alert message (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          StatefulBuilder(builder: (context, setState) {
            return ElevatedButton(
              onPressed: _isSendingAlert
                  ? null
                  : () async {
                      setState(() {
                        _isSendingAlert = true;
                      });

                      await _sendCustomAlert();

                      setState(() {
                        _isSendingAlert = false;
                      });

                      if (context.mounted) {
                        Navigator.pop(context);

                        // Show confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Alert sent to all emergency contacts"),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: _isSendingAlert
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text("Send Alert"),
            );
          }),
        ],
      ),
    );
  }

  // Send custom alert to all emergency contacts
  Future<void> _sendCustomAlert() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return;
      }

      final chatBloc = context.read<ChatBloc>();
      final alertMessage = _alertMessageController.text.trim().isEmpty
          ? "EMERGENCY ALERT! Please check on me."
          : _alertMessageController.text.trim();

      // Get all active chat rooms
      final chatRooms = chatBloc.cachedChatRooms;

      // For each chat room, send an emergency message
      for (final chatRoom in chatRooms) {
        // Generate a unique message ID
        final messageId =
            "${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid.substring(0, 4)}";

        // Create the emergency message
        final message = Message(
          id: messageId,
          senderId: currentUser.uid,
          receiverId: chatRoom.otherUserId,
          chatRoomId: chatRoom.id,
          content: alertMessage,
          timestamp: DateTime.now(),
          type: MessageType.emergency,
          isRead: false,
        );

        // Get location for the emergency alert
        String? location;
        try {
          // Attempt to get location with a timeout
          location = await _getEmergencyLocation();
        } catch (e) {
          print("Error getting location: $e");
          // Continue without location if there's an error
        }

        // Send emergency message to this contact
        chatBloc.add(SendEmergencyMessage(message, location: location));

        // Add a small delay between messages to prevent flooding
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Log for debugging
      print("Custom alert sent to ${chatRooms.length} contacts");
    } catch (e) {
      print("Error sending custom alert: $e");
      rethrow; // Allow the caller to handle the error
    }
  }

  // Get location for emergency alerts
  Future<String?> _getEmergencyLocation() async {
    try {
      // Use the existing location service implementation
      // This would typically be a call to your location service
      // For example:
      // final locationService = context.read<LocationService>();
      // return await locationService.getCurrentLocation();

      // Placeholder for demonstration - in a real implementation,
      // you would integrate with your existing location service
      await Future.delayed(const Duration(seconds: 1));
      return "37.7749,-122.4194"; // Example coordinates
    } catch (e) {
      print("Could not get location: $e");
      return null;
    }
  }

  // Logout dialog method
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog

              // Dispatch the correct logout event to AuthBloc
              try {
                context.read<AuthBloc>().add(AuthLogout());

                // Navigate to login page after logout
                Future.delayed(const Duration(milliseconds: 300), () {
                  context.goToLogin();
                });
              } catch (e) {
                print("Error during logout: $e");
                // Fallback if there's an error
                context.goToLogin();
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
