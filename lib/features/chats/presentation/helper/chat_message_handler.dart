import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:resq/core/services/attachment_handler.dart';
import 'package:resq/core/services/chat_message_trigger_handler.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/router/router.dart';
import 'package:resq/widget/widget.dart';

/// Class responsible for handling all message-related operations
class ChatMessageHandler {
  final FirebaseAuth auth;
  final AttachmentHandler attachmentHandler;
  final ChatBloc chatBloc;
  final EmergencyContact contact;
  BuildContext context;
  ChatRoom? chatRoom;
  late ChatMessageTriggerHandler _triggerHandler;

  // Add a flag to prevent duplicate operations
  bool _isProcessing = false;

  ChatMessageHandler({
    required this.auth,
    required this.attachmentHandler,
    required this.chatBloc,
    required this.contact,
    required this.context,
    this.chatRoom,
  }) {
    // Initialize the trigger handler
    _triggerHandler = ChatMessageTriggerHandler(chatBloc: chatBloc);
    _triggerHandler.initialize();
  }

  // Update context when it changes
  void updateContext(BuildContext newContext) {
    context = newContext;
  }

  // Set chat room
  void setChatRoom(ChatRoom? room) {
    chatRoom = room;
  }

  // Show error message
  void showErrorSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Check if contact is valid for chat
  bool isValidChatContact() {
    return contact.isFollowing && contact.userId != null;
  }

  // Check if message can be sent
  bool canSendMessage() {
    if (_isProcessing) {
      return false; // Prevent duplicate operations
    }

    if (chatRoom == null) {
      showErrorSnackBar('Chat room not initialized properly');
      return false;
    }

    if (!contact.isFollowing || contact.userId == null) {
      showErrorSnackBar('Cannot send message to this contact');
      return false;
    }

    return true;
  }

  // Send a text message
  Future<Message?> sendTextMessage(String text,
      {bool isEmergency = false}) async {
    if (!canSendMessage()) return null;

    _isProcessing = true;

    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        _isProcessing = false;
        return null;
      }

      // Get location for emergency messages
      String? location;
      if (isEmergency) {
        location = await _getEmergencyLocation();
      }

      // Generate a unique ID that includes a timestamp prefix for better sorting
      final messageId =
          "${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid.substring(0, 4)}";

      // Create message object
      final message = Message(
        id: messageId,
        senderId: currentUser.uid,
        receiverId: contact.userId!,
        chatRoomId: chatRoom!.id,
        content: text,
        timestamp: DateTime.now(),
        type: isEmergency ? MessageType.emergency : MessageType.text,
      );

      // Check if this message matches the trigger phrase
      if (!isEmergency) {
        final isTrigger = await _triggerHandler.checkAndProcessTrigger(message);
        if (isTrigger) {
          // If it's a trigger, we send it as an emergency message
          // The _triggerHandler has already dispatched the emergency event
          return message.copyWith(type: MessageType.emergency);
        }
      }

      // Send message to backend if not already sent as a trigger
      if (isEmergency) {
        chatBloc.add(SendEmergencyMessage(message, location: location));
      } else {
        chatBloc.add(SendMessage(message));
      }

      return message;
    } catch (e) {
      showErrorSnackBar('Error sending message: ${e.toString()}');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  // Get location for emergency messages with better error handling
  Future<String?> _getEmergencyLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        showErrorSnackBar('Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          showErrorSnackBar('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        showErrorSnackBar('Location permissions are permanently denied');
        return null;
      }

      // Get position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      return '${position.latitude},${position.longitude}';
    } catch (e) {
      showErrorSnackBar('Could not get location: ${e.toString()}');
      return null;
    }
  }

  // Show emergency options dialog with improved UI
  void showEmergencyOptions({required Function onSendEmergency}) {
    if (!contact.isFollowing) {
      showErrorSnackBar('Emergency alerts only available for app users');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Send Emergency Alert',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 20.0,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined,
                    color: Colors.red, size: 32),
                title: Text(
                  '${contact.name}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                subtitle:
                    const Text('This will trigger an emergency notification'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToEmergencyAlertPage();
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Navigate to emergency alert page
  void _navigateToEmergencyAlertPage() {
    context.goToEmergencyAlert(contact);
  }

  // Show attachment options with improved UI and error handling
  void showAttachmentOptions({required Function(Message) onSuccess}) {
    if (_isProcessing) return; // Prevent multiple operations

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AttachmentOptionsBottomSheet(
        onImageSelected: (source) => _handleImageSelection(source, onSuccess),
        onDocumentSelected: () => _handleDocumentSelection(onSuccess),
        onAudioSelected: () => _handleAudioSelection(onSuccess),
        onLocationSelected: () => _handleLocationSelection(onSuccess),
        onRecordAudio: () => _handleAudioRecording(onSuccess),
      ),
    );
  }

  // Handle audio recording with improved error handling
  void _handleAudioRecording(Function(Message) onSuccess) {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Provider.value(
          value: attachmentHandler,
          child: AudioRecordingDialog(
            onComplete: (audioFile) {
              Navigator.pop(context); // Close the dialog first
              _handleAudioFile(audioFile, onSuccess);
            },
            onCancel: () {
              Navigator.pop(context);
              _isProcessing = false;
            },
          ),
        ),
      );
    } catch (e) {
      _isProcessing = false;
      showErrorSnackBar('Error starting audio recording: ${e.toString()}');
    }
  }

  // Process audio file with improved error handling
  Future<void> _handleAudioFile(
      File audioFile, Function(Message) onSuccess) async {
    // This function casuing every where
    // if (chatRoom == null || !canSendMessage()) {
    //   _isProcessing = false;
    //   return;
    // }

    _showLoadingDialog('Processing audio...');

    try {
      final audioUrl = await attachmentHandler.uploadFile(
          audioFile, chatRoom!.id, MessageType.audio);

      if (audioUrl != null) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // For recorded audio, include a placeholder duration or 'recorded_audio' tag
        final content = '$audioUrl|recorded_audio';
        final message = await _sendMediaMessage(content, MessageType.audio);
        if (message != null) {
          onSuccess(message);
        }
      } else {
        _handleUploadError('audio', 'Upload failed');
      }
    } catch (e) {
      _handleUploadError('audio', e);
    } finally {
      _isProcessing = false;
    }
  }

  // Handle image selection with improved error handling
  Future<void> _handleImageSelection(
      ImageSource source, Function(Message) onSuccess) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final File? imageFile = await attachmentHandler.pickImage(source);
      if (imageFile == null) {
        _isProcessing = false;
        return;
      }

      _showLoadingDialog('Uploading image...');

      final imageUrl = await attachmentHandler.uploadFile(
          imageFile, chatRoom!.id, MessageType.image);

      print(imageUrl);

      if (imageUrl != null) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        final message = await _sendMediaMessage(imageUrl, MessageType.image);
        if (message != null) {
          onSuccess(message);
        }
      } else {
        _handleUploadError('image', 'Upload failed');
      }
    } catch (e) {
      _handleUploadError('image', e);
    } finally {
      _isProcessing = false;
    }
  }

  // Handle document selection with improved error handling
  Future<void> _handleDocumentSelection(Function(Message) onSuccess) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final File? documentFile = await attachmentHandler.pickDocument();
      if (documentFile == null) {
        _isProcessing = false;
        return;
      }

      _showLoadingDialog('Uploading document...');

      final documentUrl = await attachmentHandler.uploadFile(
          documentFile, chatRoom!.id, MessageType.document);

      if (documentUrl != null) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final fileName = attachmentHandler.getFileName(documentFile.path);
        final fileSize = attachmentHandler.getFileSize(documentFile);
        final fileExt = attachmentHandler.getFileExtension(documentFile.path);

        final content = '$documentUrl|$fileName|$fileSize|$fileExt';
        final message = await _sendMediaMessage(content, MessageType.document);
        if (message != null) {
          onSuccess(message);
        }
      } else {
        _handleUploadError('document', 'Upload failed');
      }
    } catch (e) {
      _handleUploadError('document', e);
    } finally {
      _isProcessing = false;
    }
  }

  // Handle audio selection with improved error handling
  Future<void> _handleAudioSelection(Function(Message) onSuccess) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final File? audioFile = await attachmentHandler.pickAudio();
      if (audioFile == null) {
        _isProcessing = false;
        return;
      }

      _showLoadingDialog('Uploading audio...');

      final audioUrl = await attachmentHandler.uploadFile(
          audioFile, chatRoom!.id, MessageType.audio);

      if (audioUrl != null) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        // Use placeholder duration
        final content = '$audioUrl|0:30';
        final message = await _sendMediaMessage(content, MessageType.audio);
        if (message != null) {
          onSuccess(message);
        }
      } else {
        _handleUploadError('audio', 'Upload failed');
      }
    } catch (e) {
      _handleUploadError('audio', e);
    } finally {
      _isProcessing = false;
    }
  }

// handle location selection with improved error handling
  Future<void> _handleLocationSelection(Function(Message) onSuccess) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      _showLoadingDialog('Getting your location...');

      final position = await attachmentHandler.getCurrentLocation();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (position == null) {
        showErrorSnackBar('Could not get your location');
        _isProcessing = false;
        return;
      }

      // Validate coordinates
      if (position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        print(
            "LOCATION DEBUG: Invalid coordinates received: ${position.latitude}, ${position.longitude}");
        showErrorSnackBar('Invalid location coordinates');
        _isProcessing = false;
        return;
      }

      // Format with consistent decimal places - 6 is standard for GPS precision
      final locationString =
          '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';

      print("LOCATION DEBUG: Raw position = $position");
      print("LOCATION DEBUG: Formatted location string = $locationString");

      final currentUser = auth.currentUser;
      if (currentUser == null) {
        _isProcessing = false;
        showErrorSnackBar('User not authenticated');
        return;
      }

      // Generate a unique ID with timestamp prefix for better sorting
      final messageId =
          "${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid.substring(0, 4)}";

      // Create the message with the proper format for your Message model
      final message = Message(
        id: messageId,
        senderId: currentUser.uid,
        receiverId: contact.userId!,
        chatRoomId: chatRoom!.id,
        content: locationString,
        timestamp: DateTime.now(),
        type: MessageType.location,
        isRead: false,
        status: MessageStatus.sending,
        locationData: locationString, // Set both content and locationData
      );

      print("LOCATION DEBUG: Created message object: $message");
      print(
          "LOCATION DEBUG: Message type: ${message.type} (index: ${message.type.index})");
      print("LOCATION DEBUG: Message content: ${message.content}");

      // Send message through BLoC
      chatBloc.add(SendMessage(message));

      // Call success callback immediately for optimistic UI update
      onSuccess(message);
    } catch (e, stackTrace) {
      print("LOCATION ERROR: Error = $e");
      print("LOCATION ERROR: Stack trace: $stackTrace");

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showErrorSnackBar('Error sending location: ${e.toString()}');
      }
    } finally {
      _isProcessing = false;
    }
  }

  // Handle upload errors with improved UI
  void _handleUploadError(String type, dynamic error) {
    _isProcessing = false;

    if (context.mounted) {
      // Close loading dialog if it's open
      Navigator.of(context, rootNavigator: true).pop();

      // Show error message
      showErrorSnackBar('Error uploading $type: ${error.toString()}');
    }
  }

  // Show loading dialog with improved UI
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Send a media message with improved error handling
  Future<Message?> _sendMediaMessage(String content, MessageType type) async {
    try {
      final currentUser = auth.currentUser;
      if (currentUser == null) return null;

      // Generate a unique ID
      final messageId =
          "${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid.substring(0, 4)}";

      print("DEBUG: Creating media message with type: $type");
      print("DEBUG: Media content: $content");

      // Extract attachment URL
      String attachmentUrl = content;
      Map<String, dynamic>? metadata;

      if (content.contains('|')) {
        final parts = content.split('|');
        attachmentUrl = parts[0];

        // Create metadata based on message type
        if (type == MessageType.document && parts.length > 3) {
          metadata = {
            'fileName': parts[1],
            'fileSize': parts[2],
            'fileExt': parts[3]
          };
        } else if (type == MessageType.audio && parts.length > 1) {
          metadata = {'duration': parts[1]};
        }
      }

      final message = Message(
        id: messageId,
        senderId: currentUser.uid,
        receiverId: contact.userId!,
        chatRoomId: chatRoom!.id,
        content: content,
        timestamp: DateTime.now(),
        type: type,
        isRead: false,
        attachmentUrl: attachmentUrl,
        attachmentMetadata: metadata,
      );

      // Send through BLoC
      chatBloc.add(SendMessage(message));

      return message;
    } catch (e) {
      showErrorSnackBar('Error sending media: ${e.toString()}');
      return null;
    }
  }
}
