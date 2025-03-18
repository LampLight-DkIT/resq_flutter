import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';

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
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(), // Temporary ID for UI
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

    // Send message to backend
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTypingChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Explicit back button that uses GoRouter
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
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.contact.isFollowing
                              ? Colors.green
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.contact.isFollowing ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.contact.isFollowing
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    ],
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
            // Load messages for the chat room
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
            // Note: We're already handling this with optimistic updates
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
          // Show loading indicator while initializing
          if (_isLoading && _currentMessages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle different states for non-app users
          if (!widget.contact.isFollowing) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cannot chat with this contact\n'
                    'They are not an app user or not following you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Chat date header
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
                    'Today', // You can replace with actual date logic
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
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
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet.\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        itemCount: _currentMessages.length,
                        itemBuilder: (context, index) {
                          final message = _currentMessages[index];
                          final isCurrentUser =
                              message.senderId == _auth.currentUser?.uid;

                          // Check if we need to show timestamp header
                          bool showTimestamp = true;
                          if (index > 0) {
                            final prevMessage = _currentMessages[index - 1];
                            final timeDiff = message.timestamp
                                .difference(prevMessage.timestamp);
                            showTimestamp = timeDiff.inMinutes > 5;
                          }

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
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Row(
                                mainAxisAlignment: isCurrentUser
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (!isCurrentUser)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: 8.0, bottom: 4.0),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            widget.contact.photoURL != null
                                                ? NetworkImage(
                                                    widget.contact.photoURL!)
                                                : null,
                                        child: widget.contact.photoURL == null
                                            ? Text(
                                                widget.contact.name[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    fontSize: 12))
                                            : null,
                                      ),
                                    ),
                                  Flexible(
                                    child: Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 8.0),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 10.0),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser
                                            ? Colors.blue.shade100
                                            : Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.content,
                                            style: TextStyle(
                                              color: isCurrentUser
                                                  ? Colors.blue[900]
                                                  : Colors.black87,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (message.type ==
                                              MessageType.emergency)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.red.withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.warning_amber,
                                                      color: Colors.red,
                                                      size: 12),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'EMERGENCY',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: message.isRead
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
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
                      // Attachment button
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        color: Colors.grey,
                        onPressed: () {
                          // Implement attachment functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Attachments coming soon')),
                          );
                        },
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
                                  // Implement emoji picker
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
                          // Implement voice message recording
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
