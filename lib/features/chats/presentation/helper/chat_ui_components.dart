import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_message_bubble.dart';
import 'image_message_bubble.dart';
import 'location_message_bubble.dart';

class ChatUIComponents {
  static AppBar buildAppBar({
    required BuildContext context,
    required EmergencyContact contact,
    required VoidCallback onEmergencyPressed,
  }) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Hero(
            tag: 'avatar_${contact.id}',
            child: CircleAvatar(
              backgroundImage: contact.photoURL != null
                  ? NetworkImage(contact.photoURL!)
                  : null,
              child: contact.photoURL == null
                  ? Text(contact.name[0].toUpperCase())
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (contact.isFollowing)
          IconButton(
            icon: const Icon(
              Icons.info_outline,
            ),
            onPressed: onEmergencyPressed,
          ),
      ],
    );
  }

// Updated buildMessageBubble function with improved media handling
  static Widget buildMessageBubble({
    required Message message,
    required bool isCurrentUser,
    String? contactPhotoURL,
    String? currentUserPhotoURL,
    required String contactName,
    required String currentUserName,
  }) {
    print("DEBUG: Building message bubble for message type: ${message.type}");
    print("DEBUG: Message content: ${message.content}");

    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: FutureBuilder<String?>(
              future: _getTriggerPhrase(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return _renderMessageByType(message, isCurrentUser);
                }

                final triggerPhrase = snapshot.data;
                final isTriggerMessage = triggerPhrase != null &&
                    message.content.trim().toLowerCase() ==
                        triggerPhrase.toLowerCase();

                // For sender: show the actual message with a red underline
                if (isCurrentUser && isTriggerMessage) {
                  return _buildSubtleTriggerBubble(message, isCurrentUser);
                }

                // For receiver: replace trigger message with EMERGENCY ALERT
                if (!isCurrentUser && isTriggerMessage) {
                  // Create a modified message for display
                  final emergencyMessage = message.copyWith(
                    content: "EMERGENCY ALERT",
                    type: MessageType.emergency,
                  );
                  return _renderMessageByType(emergencyMessage, isCurrentUser);
                }

                // Handle regular messages by type
                return _renderMessageByType(message, isCurrentUser);
              },
            ),
          ),
        ),
        if (isCurrentUser)
          CircleAvatar(
            radius: 16,
            backgroundImage: currentUserPhotoURL != null
                ? NetworkImage(currentUserPhotoURL)
                : null, // Use currentUserPhotoURL
            child: currentUserPhotoURL == null
                ? Text(
                    currentUserName[0].toUpperCase(), // Use currentUserName
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
      ],
    );
  }

// New helper function to render different message types
  static Widget _renderMessageByType(Message message, bool isCurrentUser) {
    switch (message.type) {
      case MessageType.image:
        print("DEBUG: Rendering image bubble with content: ${message.content}");
        return ImageMessageBubble(
            message: message, isCurrentUser: isCurrentUser);

      case MessageType.document:
        return DocumentMessageBubble(
            message: message, isCurrentUser: isCurrentUser);

      case MessageType.audio:
        return AudioMessageBubble(
            message: message, isCurrentUser: isCurrentUser);

      case MessageType.location:
        return LocationMessageBubble(
            message: message, isCurrentUser: isCurrentUser);

      case MessageType.emergency:
        return _buildEmergencyMessageBubble(message, isCurrentUser);

      default:
        return _buildBasicMessageBubble(message, isCurrentUser);
    }
  }

// New helper for emergency messages
  static Widget _buildEmergencyMessageBubble(
      Message message, bool isCurrentUser) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 13.0,
                  color: Colors.red.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  'Emergency',
                  style: TextStyle(
                    fontSize: 13.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _getTriggerPhrase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('alert_trigger_phrase');
  }

  static Widget _buildBasicMessageBubble(Message message, bool isCurrentUser) {
    final content = message.content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: TextStyle(
                color: isCurrentUser ? Colors.blue[900] : Colors.black87,
                fontSize: 15),
          ),
          if (message.type == MessageType.emergency)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 12),
                  SizedBox(width: 4),
                  Text('EMERGENCY ALERT',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildSubtleTriggerBubble(Message message, bool isCurrentUser) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isCurrentUser ? Colors.blue[900] : Colors.black87,
              fontSize: 15,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 2,
            width: 25,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  static String extractAttachmentUrl(Message message) {
    if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
      return message.attachmentUrl!;
    }

    if (message.content.contains('|')) {
      final parts = message.content.split('|');
      return parts[0];
    }

    return message.content;
  }

  static Map<String, String> extractDocumentMetadata(Message message) {
    Map<String, String> metadata = {
      'fileName': 'Document',
      'fileSize': '',
      'fileExt': '',
    };

    if (message.attachmentMetadata != null) {
      if (message.attachmentMetadata!.containsKey('fileName')) {
        metadata['fileName'] =
            message.attachmentMetadata!['fileName'] as String;
      }
      if (message.attachmentMetadata!.containsKey('fileSize')) {
        metadata['fileSize'] =
            message.attachmentMetadata!['fileSize'] as String;
      }
      if (message.attachmentMetadata!.containsKey('fileExt')) {
        metadata['fileExt'] = message.attachmentMetadata!['fileExt'] as String;
      }
      return metadata;
    }

    if (message.content.contains('|')) {
      final parts = message.content.split('|');
      if (parts.length > 1) metadata['fileName'] = parts[1];
      if (parts.length > 2) metadata['fileSize'] = parts[2];
      if (parts.length > 3) metadata['fileExt'] = parts[3];
    }

    return metadata;
  }

  static String extractAudioDuration(Message message) {
    if (message.attachmentMetadata != null &&
        message.attachmentMetadata!.containsKey('duration')) {
      return message.attachmentMetadata!['duration'] as String;
    }

    if (message.content.contains('|')) {
      final parts = message.content.split('|');
      if (parts.length > 1) return parts[1];
    }

    return '0:00';
  }

  static Widget buildMessageInputBar({
    required BuildContext context,
    required TextEditingController messageController,
    required Function() onSendPressed,
    required Function() onAttachmentPressed,
    FocusNode? focusNode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              color: Colors.grey,
              onPressed: onAttachmentPressed,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: messageController,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  key: const ValueKey('messageTextField'),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voice messages coming soon')),
                );
              },
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: Colors.white,
                  onPressed: () {
                    if (messageController.text.trim().isNotEmpty) {
                      onSendPressed();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildDateHeader(String date) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          date,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
    );
  }

  static Widget buildEmptyChatPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No messages yet.\nStart the conversation!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  static Widget buildNonAppUserMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Cannot chat with this contact\nThey are not an app user or not following you',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  static String ensureDisplayableImageUrl(String url) {
    // Check if the URL points to a HEIC image
    if (url.toLowerCase().contains('.heic')) {
      print("DEBUG: Converting HEIC URL to JPG: $url");
      return url.replaceAll('.heic', '.jpg');
    }
    return url;
  }
}

class DocumentMessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const DocumentMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final documentUrl = ChatUIComponents.extractAttachmentUrl(message);
    final metadata = ChatUIComponents.extractDocumentMetadata(message);

    return Container(
      width: MediaQuery.of(context).size.width * 0.6,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                _getFileIcon(metadata['fileExt'] ?? ''),
                color: Colors.blue,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata['fileName'] ?? 'Document',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata['fileSize']?.isNotEmpty ?? false)
                  Text(
                    metadata['fileSize']!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              // Implement document download/preview
            },
            color: Colors.blue,
            iconSize: 20,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.article;
      default:
        return Icons.insert_drive_file;
    }
  }
}
