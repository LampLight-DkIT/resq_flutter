import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/widget/widget.dart';

/// Class containing reusable UI components for the chat interface
class ChatUIComponents {
  // Build the chat appbar
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
            icon: const Icon(Icons.warning_amber_outlined, color: Colors.red),
            onPressed: onEmergencyPressed,
          ),
      ],
    );
  }

  // Build message bubble
  static Widget buildMessageBubble({
    required Message message,
    required bool isCurrentUser,
    String? contactPhotoURL,
    required String contactName,
  }) {
    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isCurrentUser)
          CircleAvatar(
            radius: 16,
            backgroundImage:
                contactPhotoURL != null ? NetworkImage(contactPhotoURL) : null,
            child: contactPhotoURL == null
                ? Text(contactName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12))
                : null,
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: _getMessageContent(message, isCurrentUser),
          ),
        ),
        if (isCurrentUser)
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(Icons.done_all,
                size: 16, color: message.isRead ? Colors.blue : Colors.grey),
          ),
      ],
    );
  }

  // Get appropriate message content widget based on type
  static Widget _getMessageContent(Message message, bool isCurrentUser) {
    // Handle different message types with their custom widgets
    switch (message.type) {
      case MessageType.image:
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
      default:
        // Default case: text and emergency messages
        return _buildTextMessageBubble(message, isCurrentUser);
    }
  }

  // Build text message bubble
  static Widget _buildTextMessageBubble(Message message, bool isCurrentUser) {
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
                  Text('EMERGENCY',
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

  // Build message input bar
  static Widget buildMessageInputBar({
    required BuildContext context,
    required TextEditingController messageController,
    required Function() onSendPressed,
    required Function() onAttachmentPressed,
    FocusNode? focusNode, // Added focus node parameter
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
            // Attachment button
            IconButton(
              icon: const Icon(Icons.attach_file),
              color: Colors.grey,
              onPressed: onAttachmentPressed,
            ),

            // Message text field
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

            // Send button
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

  // Build date header
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

  // Build empty chat placeholder
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

  // Build non-app user message
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
}
