import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:resq/core/services/attachment_handler.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/widget/widget.dart';

class ChatPage extends StatefulWidget {
  final EmergencyContact contact;

  const ChatPage({Key? key, required this.contact}) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late ChatBloc _chatBloc;
  ChatRoom? _chatRoom;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isTyping = false;
  Timer? _typingTimer;
  List<Message> _currentMessages = [];
  final AttachmentHandler _attachmentHandler = AttachmentHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _chatBloc = context.read<ChatBloc>();

    // Listen for typing
    _messageController.addListener(_onTypingChanged);

    // Initialize chat room
    _initializeChatRoom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle changes if needed (e.g., mark user as away when app is in background)
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;

    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });

      // Reset typing timer
      _typingTimer?.cancel();

      if (isCurrentlyTyping) {
        // In a real app, you would notify the other user that this user is typing
        // For example: _chatBloc.add(UpdateTypingStatus(isTyping: true));

        // Auto-reset typing status after 5 seconds of inactivity
        _typingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _isTyping = false;
            });
            // Notify that user stopped typing
            // _chatBloc.add(UpdateTypingStatus(isTyping: false));
          }
        });
      }
    }
  }

  void _initializeChatRoom() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Only create chat room if contact is an app user
    if (widget.contact.isFollowing && widget.contact.userId != null) {
      _chatBloc.add(CreateChatRoom(
        currentUserId: currentUser.uid,
        otherUserId: widget.contact.userId!,
        otherUserName: widget.contact.name,
        otherUserPhotoUrl: widget.contact.photoURL,
      ));
    } else {
      // Handle non-app user scenario
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot chat with non-app user')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sendMessage({bool isEmergency = false}) async {
    if (_chatRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat room not initialized properly')),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Ensure we can only send messages to app users
    if (!widget.contact.isFollowing || widget.contact.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send message to this contact')),
      );
      return;
    }

    String? location;
    if (isEmergency) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        location = '${position.latitude},${position.longitude}';
      } catch (e) {
        // Handle location error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location')),
        );
      }
    }

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUser.uid,
      receiverId: widget.contact.userId!,
      chatRoomId: _chatRoom!.id,
      content: messageText,
      timestamp: DateTime.now(),
      type: isEmergency ? MessageType.emergency : MessageType.text,
    );

    // Optimistically add message to UI
    setState(() {
      _currentMessages = [..._currentMessages, message];
    });

    // Clear message input
    _messageController.clear();

    // Scroll to bottom
    _scrollToBottom();

    // Send message to backend - BLoC will handle offline scenarios
    if (isEmergency) {
      _chatBloc.add(SendEmergencyMessage(message, location: location));
    } else {
      _chatBloc.add(SendMessage(message));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showEmergencyOptions() {
    // Only show emergency options for app users
    if (!widget.contact.isFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Emergency alerts only available for app users')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.warning_amber_outlined, color: Colors.red),
              title: const Text('Send Emergency Alert'),
              onTap: () {
                Navigator.pop(context);
                _sendMessage(isEmergency: true);

                // Navigate to emergency alert page using GoRouter
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EmergencyAlertPage(contact: widget.contact),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AttachmentOptionsBottomSheet(
        onImageSelected: _handleImageSelection,
        onDocumentSelected: _handleDocumentSelection,
        onAudioSelected: _handleAudioSelection,
        onLocationSelected: _handleLocationSelection,
        onRecordAudio: _handleAudioRecording, // Add this new handler
      ),
    );
  }

  void _handleAudioRecording() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Provider.value(
        value: _attachmentHandler,
        child: AudioRecordingDialog(
          onComplete: (File audioFile) {
            _handleAudioFile(audioFile);
          },
        ),
      ),
    );
  }

  void _handleAudioFile(File audioFile) async {
    if (_chatRoom == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Processing audio...'),
          ],
        ),
      ),
    );

    try {
      final audioUrl = await _attachmentHandler.uploadFile(
          audioFile, _chatRoom!.id, MessageType.audio);

      if (audioUrl != null && mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        // For recorded audio, we can include a duration if we track it during recording
        // For now, we'll use a placeholder
        final content = '$audioUrl|recorded_audio';
        _sendMediaMessage(content, MessageType.audio);
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading audio: $e')),
        );
      }
    }
  }

  void _handleImageSelection(ImageSource source) async {
    final File? imageFile = await _attachmentHandler.pickImage(source);
    if (imageFile == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading image...'),
          ],
        ),
      ),
    );

    try {
      final imageUrl = await _attachmentHandler.uploadFile(
          imageFile, _chatRoom!.id, MessageType.image);

      if (imageUrl != null && mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        _sendMediaMessage(imageUrl, MessageType.image);
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  void _handleDocumentSelection() async {
    final File? documentFile = await _attachmentHandler.pickDocument();
    if (documentFile == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading document...'),
          ],
        ),
      ),
    );

    try {
      final documentUrl = await _attachmentHandler.uploadFile(
          documentFile, _chatRoom!.id, MessageType.document);

      if (documentUrl != null && mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        final fileName = _attachmentHandler.getFileName(documentFile.path);
        final fileSize = _attachmentHandler.getFileSize(documentFile);
        final fileExt = _attachmentHandler.getFileExtension(documentFile.path);

        final content = '$documentUrl|$fileName|$fileSize|$fileExt';
        _sendMediaMessage(content, MessageType.document);
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading document: $e')),
        );
      }
    }
  }

  void _handleAudioSelection() async {
    final File? audioFile = await _attachmentHandler.pickAudio();
    if (audioFile == null || !mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Uploading audio...'),
          ],
        ),
      ),
    );

    try {
      final audioUrl = await _attachmentHandler.uploadFile(
          audioFile, _chatRoom!.id, MessageType.audio);

      if (audioUrl != null && mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        // Here you could calculate the duration of the audio file
        // For now, we'll just use a placeholder
        final content = '$audioUrl|0:30';
        _sendMediaMessage(content, MessageType.audio);
      }
    } catch (e) {
      if (mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading audio: $e')),
        );
      }
    }
  }

  void _handleLocationSelection() async {
    final position = await _attachmentHandler.getCurrentLocation();
    if (position == null || !mounted) return;

    final locationString = '${position.latitude},${position.longitude}';
    _sendMediaMessage(locationString, MessageType.location);
  }

  // Add a helper method for sending media messages
  void _sendMediaMessage(String content, MessageType type) async {
    if (_chatRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat room not initialized properly')),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUser.uid,
      receiverId: widget.contact.userId!,
      chatRoomId: _chatRoom!.id,
      content: content,
      timestamp: DateTime.now(),
      type: type,
    );

    // Optimistically add message to UI
    setState(() {
      _currentMessages = [..._currentMessages, message];
    });

    // Scroll to bottom
    _scrollToBottom();

    // Send message to backend
    _chatBloc.add(SendMessage(message));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _attachmentHandler.dispose(); // Add this line
    super.dispose();
  }

  // Helper method to build message bubbles
  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    return Row(
      mainAxisAlignment:
          isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isCurrentUser)
          CircleAvatar(
            radius: 16,
            backgroundImage: widget.contact.photoURL != null
                ? NetworkImage(widget.contact.photoURL!)
                : null,
            child: widget.contact.photoURL == null
                ? Text(widget.contact.name[0].toUpperCase(),
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

  // Helper method to get the appropriate message content based on type
  Widget _getMessageContent(Message message, bool isCurrentUser) {
    // Handle specialized message types with their custom widgets
    if (message.type == MessageType.image)
      return ImageMessageBubble(message: message, isCurrentUser: isCurrentUser);
    if (message.type == MessageType.document)
      return DocumentMessageBubble(
          message: message, isCurrentUser: isCurrentUser);
    if (message.type == MessageType.audio)
      return AudioMessageBubble(message: message, isCurrentUser: isCurrentUser);
    if (message.type == MessageType.location)
      return LocationMessageBubble(
          message: message, isCurrentUser: isCurrentUser);

    // Default case: text and emergency messages
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.contact.id}',
              child: CircleAvatar(
                backgroundImage: widget.contact.photoURL != null
                    ? NetworkImage(widget.contact.photoURL!)
                    : null,
                child: widget.contact.photoURL == null
                    ? Text(widget.contact.name[0].toUpperCase())
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.name,
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
          if (widget.contact.isFollowing)
            IconButton(
              icon: const Icon(Icons.warning_amber_outlined, color: Colors.red),
              onPressed: _showEmergencyOptions,
            ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          if (state is ChatRoomCreated) {
            setState(() {
              _chatRoom = state.chatRoom;
              _isLoading = false;
            });
            _chatBloc.add(LoadMessages(state.chatRoom.id));
          } else if (state is MessagesLoaded) {
            setState(() {
              _currentMessages = state.messages;
            });
            _scrollToBottom();
          } else if (state is EmergencyMessageSent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Emergency alert sent!'),
                backgroundColor: Colors.red,
              ),
            );
            _scrollToBottom();
          } else if (state is MessageSent) {
            _scrollToBottom();
          } else if (state is ChatError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${state.message}')),
            );
            setState(() {
              _isLoading = false;
            });
          }
        },
        builder: (context, state) {
          if (_isLoading && _currentMessages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!widget.contact.isFollowing) {
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

          return Column(
            children: [
              // Today header
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ),

              // Messages list
              Expanded(
                child: _currentMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet.\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _currentMessages.length,
                        itemBuilder: (context, index) {
                          final message = _currentMessages[index];
                          final isCurrentUser =
                              message.senderId == _auth.currentUser?.uid;

                          // Show timestamp if it's the first message or if the time gap is significant
                          final showTimestamp = index == 0 ||
                              message.timestamp
                                      .difference(
                                          _currentMessages[index - 1].timestamp)
                                      .inMinutes >
                                  5;

                          return Column(
                            children: [
                              if (showTimestamp)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    DateFormat('MMM d, h:mm a')
                                        .format(message.timestamp),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic),
                                  ),
                                ),
                              _buildMessageBubble(message, isCurrentUser),
                            ],
                          );
                        },
                      ),
              ),

              // Typing indicator
              if (_isTyping && _chatRoom != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    "Typing...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),

              // Message input bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
                      // Attachment button - updated to use _showAttachmentOptions
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        color: Colors.grey,
                        onPressed: _showAttachmentOptions,
                      ),

                      // Message text field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.emoji_emotions_outlined),
                                color: Colors.amber,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Emoji picker coming soon')),
                                  );
                                },
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Send button
                      GestureDetector(
                        onLongPress: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Voice messages coming soon')),
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
                            onPressed: _messageController.text.trim().isEmpty
                                ? null
                                : () => _sendMessage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
