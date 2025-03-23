import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  // Check if a message matches the trigger phrase and convert it to an emergency message
  Future<bool> checkAndProcessTrigger(Message message) async {
    // Make sure we have loaded the trigger phrase
    if (_triggerPhrase == null) {
      await initialize();
    }

    // If no trigger phrase is set or this isn't from the current user, do nothing
    if (_triggerPhrase == null ||
        _triggerPhrase!.isEmpty ||
        message.senderId != auth.currentUser?.uid) {
      return false;
    }

    // Check if the message content matches the trigger phrase exactly
    if (message.content.trim() == _triggerPhrase!.trim()) {
      // Create a new emergency message
      final emergencyMessage = Message(
        id: message.id,
        senderId: message.senderId,
        receiverId: message.receiverId,
        chatRoomId: message.chatRoomId,
        content: message.content,
        timestamp: message.timestamp,
        type: MessageType.emergency,
        isRead: message.isRead,
      );

      // Send the emergency message
      chatBloc.add(SendEmergencyMessage(emergencyMessage));

      // For debugging
      debugPrint('Trigger phrase detected! Converting to emergency message.');

      return true;
    }

    return false;
  }
}
