import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:resq/core/services/attachment_handler.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/features/chats/models/message_model.dart';
import 'package:resq/features/chats/presentation/helper/chat_message_handler.dart';
import 'package:resq/features/chats/presentation/helper/chat_ui_components.dart';

class ChatPage extends StatefulWidget {
  final EmergencyContact contact;

  const ChatPage({super.key, required this.contact});

  @override
  _ChatPageState createState() => _ChatPageState();
}

// Observer that detects changes in keyboard visibility through metrics
class _KeyboardVisibilityObserver extends WidgetsBindingObserver {
  final void Function(bool) onVisibilityChanged;
  double _previousBottomInset = 0.0;

  _KeyboardVisibilityObserver({required this.onVisibilityChanged});

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset != _previousBottomInset) {
      _previousBottomInset = bottomInset;
      onVisibilityChanged(bottomInset > 0);
    }
  }
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  // Controllers and state variables
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  late FocusNode _messageFocusNode;
  late ChatBloc _chatBloc;
  late ChatMessageHandler _messageHandler;

  // For keyboard visibility
  late _KeyboardVisibilityObserver _keyboardObserver;

  // Chat data
  ChatRoom? _chatRoom;
  List<Message> _currentMessages = [];

  // UI state
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _keyboardVisible = false;

  // Utilities
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AttachmentHandler _attachmentHandler = AttachmentHandler();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeChatRoom();
    WidgetsBinding.instance.addObserver(this);

    // Monitor for keyboard visibility manually using view insets
    _keyboardObserver = _KeyboardVisibilityObserver(
      onVisibilityChanged: (bool visible) {
        if (mounted) {
          setState(() {
            _keyboardVisible = visible;
          });
        }
      },
    );
    WidgetsBinding.instance.addObserver(_keyboardObserver);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatRoom != null && mounted) {
        _chatBloc.add(LoadMessages(_chatRoom!.id));
      }
    });
  }

  void _initializeControllers() {
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _messageFocusNode = FocusNode();
    _chatBloc = context.read<ChatBloc>();
    _messageHandler = ChatMessageHandler(
      auth: _auth,
      attachmentHandler: _attachmentHandler,
      chatBloc: _chatBloc,
      contact: widget.contact,
      context: context,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app comes back to foreground, refresh messages and reset focus
    if (state == AppLifecycleState.resumed && _chatRoom != null) {
      _chatBloc.add(LoadMessages(_chatRoom!.id));

      // Give TextField focus after a short delay
      if (_messageController.text.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _messageFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _initializeChatRoom() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _messageHandler.showErrorSnackBar('User not authenticated');
      setState(() => _isLoading = false);
      return;
    }

    // Verify contact is an app user
    if (!_messageHandler.isValidChatContact()) {
      _messageHandler.showErrorSnackBar('Cannot chat with non-app user');
      setState(() => _isLoading = false);
      return;
    }

    _chatBloc.add(CreateChatRoom(
      currentUserId: currentUser.uid,
      otherUserId: widget.contact.userId!,
      otherUserName: widget.contact.name,
      otherUserPhotoUrl: widget.contact.photoURL,
    ));
  }

  // Regular message sending
  Future<void> _sendMessage() async {
    // Prevent duplicate sends
    if (_isSendingMessage) return;

    setState(() {
      _isSendingMessage = true;
    });

    // Set chat room in message handler
    _messageHandler.setChatRoom(_chatRoom);

    // Validate prerequisites
    if (!_messageHandler.canSendMessage()) {
      setState(() {
        _isSendingMessage = false;
      });
      return;
    }

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      setState(() {
        _isSendingMessage = false;
      });
      return;
    }

    try {
      // Send message using handler
      final message = await _messageHandler.sendTextMessage(messageText);

      if (message != null) {
        // Add to UI immediately (optimistic update)
        _addMessageToUI(message);

        // Clear input
        _messageController.clear();

        // Scroll to bottom
        _scrollToBottom();
      }
    } catch (e) {
      _messageHandler
          .showErrorSnackBar('Failed to send message: ${e.toString()}');
    } finally {
      // Reset sending state
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });

        // Ensure we have focus back
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _messageFocusNode.requestFocus();
          }
        });
      }
    }
  }

  // Emergency message sending
  // In chats_page.dart
  Future<void> _sendEmergencyMessage() async {
    // Prevent duplicate sends
    if (_isSendingMessage) return;

    setState(() {
      _isSendingMessage = true;
    });

    // Set chat room in message handler
    _messageHandler.setChatRoom(_chatRoom);

    // Validate prerequisites
    if (!_messageHandler.canSendMessage()) {
      setState(() {
        _isSendingMessage = false;
      });
      return;
    }

    final messageText = _messageController.text.isEmpty
        ? "EMERGENCY ALERT!"
        : _messageController.text.trim();

    try {
      // Send emergency message
      final message =
          await _messageHandler.sendTextMessage(messageText, isEmergency: true);

      if (message != null) {
        // Add to UI immediately (optimistic update) - this is crucial
        _addMessageToUI(message);

        // Clear input
        _messageController.clear();

        // Scroll to bottom
        _scrollToBottom();

        // Add this debug print to verify message was created correctly
        print("Emergency message sent: ${message.type} - ${message.content}");
      }
    } catch (e) {
      _messageHandler.showErrorSnackBar(
          'Failed to send emergency message: ${e.toString()}');
    } finally {
      // Reset sending state
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  void _addMessageToUI(Message message) {
    if (mounted) {
      setState(() {
        // Check if message already exists
        if (!_currentMessages.any((m) => m.id == message.id)) {
          _currentMessages = [..._currentMessages, message];
          // Sort messages by timestamp to ensure correct order
          _currentMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      });
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

  @override
  void dispose() {
    // Remove our keyboard observer
    WidgetsBinding.instance.removeObserver(_keyboardObserver);
    // Remove the widget binding observer (this)
    WidgetsBinding.instance.removeObserver(this);

    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _attachmentHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update context in message handler to ensure it's current
    _messageHandler.updateContext(context);

    return GestureDetector(
      // Add this wrapper to handle taps outside the TextField
      onTap: () {
        // Hide keyboard when tapping outside TextField
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: ChatUIComponents.buildAppBar(
          context: context,
          contact: widget.contact,
          onEmergencyPressed: () =>
              _messageHandler.showEmergencyOptions(onSendEmergency: () {
            _sendEmergencyMessage();
          }),
        ),
        body: BlocConsumer<ChatBloc, ChatState>(
          listener: _handleChatStateChanges,
          builder: (context, state) {
            if (_isLoading && _currentMessages.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!widget.contact.isFollowing) {
              return ChatUIComponents.buildNonAppUserMessage();
            }

            return _buildChatUI();
          },
        ),
      ),
    );
  }

  void _handleChatStateChanges(BuildContext context, ChatState state) {
    if (state is ChatRoomCreated) {
      setState(() {
        _chatRoom = state.chatRoom;
        _isLoading = false;
        // Pass chat room to message handler
        _messageHandler.setChatRoom(state.chatRoom);
      });
      _chatBloc.add(LoadMessages(state.chatRoom.id));
    } else if (state is MessagesLoaded) {
      // Handle empty state case before setting messages
      final wasEmpty = _currentMessages.isEmpty;

      setState(() {
        // Replace all messages with fresh ones from server
        _currentMessages = List<Message>.from(state.messages);
        // Ensure messages are sorted by timestamp
        _currentMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _isLoading = false;
      });

      if (wasEmpty || _shouldScrollToBottom()) {
        _scrollToBottom();
      }
    } else if (state is MessageReceived) {
      // Real-time message received - add to UI if not already there
      if (!_currentMessages.any((m) => m.id == state.message.id)) {
        _addMessageToUI(state.message);
        _scrollToBottom();
      }
    } else if (state is EmergencyMessageSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergency alert sent!'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSendingMessage = false;
      });
      _scrollToBottom();
    } else if (state is MessageSent) {
      // Ensure the message is in the list and scroll to bottom
      if (!_currentMessages.any((m) => m.id == state.message.id)) {
        _addMessageToUI(state.message);
      }
      setState(() {
        _isSendingMessage = false;
      });
      _scrollToBottom();

      // Ensure we're focused on the TextField
      _messageFocusNode.requestFocus();
    } else if (state is ChatError) {
      _messageHandler.showErrorSnackBar('Error: ${state.message}');
      setState(() {
        _isLoading = false;
        _isSendingMessage = false;
      });
    }
  }

  // Helper method to determine if we should auto-scroll
  bool _shouldScrollToBottom() {
    if (!_scrollController.hasClients) return true;

    final position = _scrollController.position;
    // Auto-scroll if we're already near the bottom (within 100 pixels)
    return position.maxScrollExtent - position.pixels < 100;
  }

  Widget _buildChatUI() {
    return Column(
      children: [
        // Today header
        ChatUIComponents.buildDateHeader('Today'),

        // Messages list
        Expanded(
          child: _currentMessages.isEmpty
              ? ChatUIComponents.buildEmptyChatPlaceholder()
              : _buildMessagesList(),
        ),

        // Message input bar with visual feedback for sending state
        Stack(
          children: [
            ChatUIComponents.buildMessageInputBar(
              context: context,
              messageController: _messageController,
              focusNode: _messageFocusNode,
              onSendPressed: _isSendingMessage
                  ? () {} // Empty function when sending
                  : () => _sendMessage(),
              onAttachmentPressed: _isSendingMessage
                  ? () {} // Empty function when sending
                  : () {
                      _messageHandler.showAttachmentOptions(
                          onSuccess: (message) {
                        _addMessageToUI(message);
                        _scrollToBottom();
                      });
                    },
            ),
            if (_isSendingMessage)
              Positioned(
                right: 12,
                bottom: 12,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: _currentMessages.length,
      itemBuilder: (context, index) {
        final message = _currentMessages[index];
        final isCurrentUser = message.senderId == _auth.currentUser?.uid;

        // Show timestamp if first message or if time gap is significant
        final showTimestamp = index == 0 ||
            message.timestamp
                    .difference(_currentMessages[index - 1].timestamp)
                    .inMinutes >
                5;

        return Column(
          children: [
            if (showTimestamp)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  DateFormat('MMM d, h:mm a').format(message.timestamp),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic),
                ),
              ),
            ChatUIComponents.buildMessageBubble(
              message: message,
              isCurrentUser: isCurrentUser,
              contactPhotoURL: widget.contact.photoURL,
              contactName: widget.contact.name,
            ),
          ],
        );
      },
    );
  }
}
