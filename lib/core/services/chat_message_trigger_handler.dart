import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessageTriggerHandler {
  final ChatBloc chatBloc;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String? _triggerPhrase;

  ChatMessageTriggerHandler({required this.chatBloc});

  // Load the trigger phrase
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _triggerPhrase = prefs.getString('alert_trigger_phrase');
  }

  // In ChatMessageTriggerHandler class

  /// Checks if a message contains the trigger phrase and processes it as an emergency
  /// Returns true if the message was a trigger, false otherwise
  Future<bool> checkAndProcessTrigger(Message message) async {
    try {
      // Get the trigger phrase from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final triggerPhrase = prefs.getString('alert_trigger_phrase');

      // If no trigger phrase is set or message is empty, return false
      if (triggerPhrase == null ||
          triggerPhrase.isEmpty ||
          message.content.isEmpty) {
        return false;
      }

      // Check if the message content matches the trigger phrase (case insensitive)
      if (message.content.trim().toLowerCase() == triggerPhrase.toLowerCase()) {
        // It's a trigger phrase - convert the message to an emergency message
        final emergencyMessage = message.copyWith(
          type: MessageType.emergency,
          // You might want to add additional data to indicate this was triggered by a phrase
          content: message.content, // Preserve the original content
        );

        // Try to get the user's location
        String? location;
        try {
          // Get current location - you might want to use your app's location service here
          // This is a simplified example - replace with your actual location fetching code
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          location = '${position.latitude},${position.longitude}';
        } catch (e) {
          print("Failed to get location for trigger phrase: $e");
          // Continue without location if there's an error
        }

        // Dispatch the emergency message event
        chatBloc
            .add(SendEmergencyMessage(emergencyMessage, location: location));

        // Debug log
        print("Trigger phrase detected: ${message.content}");

        return true;
      }

      // No trigger detected
      return false;
    } catch (e) {
      // Log the error but don't crash
      print("Error checking trigger phrase: $e");
      return false;
    }
  }
}
