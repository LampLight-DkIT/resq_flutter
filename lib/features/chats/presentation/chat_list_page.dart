// lib/features/chats/presentation/chat_list_page.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/bloc/chat_state.dart';
import 'package:resq/features/chats/models/chat_room_model.dart';
import 'package:resq/router/router.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterChatRooms);

    // Load chat rooms when page initializes
    if (_auth.currentUser != null) {
      context.read<ChatBloc>().add(LoadChatRooms());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterChatRooms() {
    if (_searchController.text.isNotEmpty) {
      context.read<ChatBloc>().add(FilterChatRooms(_searchController.text));
    } else {
      context.read<ChatBloc>().add(LoadChatRooms());
    }
  }

  void _navigateToDiscoverUsers() {
    context.goToDiscoverUsers();
  }

  String _formatLastMessageTime(DateTime? time) {
    if (time == null) return '';

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Chats'),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  context.read<ChatBloc>().add(LoadChatRooms());
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sort_name') {
                context
                    .read<ChatBloc>()
                    .add(const SortChatRooms(SortType.name));
              } else if (value == 'sort_recent') {
                context
                    .read<ChatBloc>()
                    .add(const SortChatRooms(SortType.recent));
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'sort_name',
                  child: Text('Sort by name'),
                ),
                const PopupMenuItem(
                  value: 'sort_recent',
                  child: Text('Sort by recent'),
                ),
              ];
            },
          ),
        ],
      ),
      body: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          // First check if we have a loading state with no cached data
          if (state is ChatLoading) {
            // Check if BLoC already has cached chat rooms
            final chatBloc = context.read<ChatBloc>();
            if (chatBloc.hasCachedChatRooms) {
              // Use cached rooms while loading new data
              return _buildChatList(chatBloc.cachedChatRooms);
            }
            return const Center(child: CircularProgressIndicator());
          } else if (state is ChatRoomsLoaded) {
            return _buildChatList(state.chatRooms);
          } else if (state is ChatRoomsFiltered) {
            return _buildChatList(state.filteredChatRooms);
          } else if (state is ChatError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  // Even on error, try to show cached rooms if available
                  if (context.read<ChatBloc>().hasCachedChatRooms)
                    _buildChatList(context.read<ChatBloc>().cachedChatRooms),
                ],
              ),
            );
          }

          // Instead of showing "Loading chats...", try to use cached data
          final chatBloc = context.read<ChatBloc>();
          if (chatBloc.hasCachedChatRooms) {
            return _buildChatList(chatBloc.cachedChatRooms);
          }

          // Only as a fallback
          return const Center(child: Text('Loading chats...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToDiscoverUsers,
        backgroundColor: AppColors.darkBlue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  // Extract chat list building logic to a separate method
  Widget _buildChatList(List<ChatRoom> chatRooms) {
    if (chatRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching
                  ? "No chats found"
                  : "No chats yet!\nFollow users to start chatting",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.people_alt_outlined),
              label: const Text('Discover Users'),
              onPressed: _navigateToDiscoverUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chatRooms.length,
      itemBuilder: (context, index) {
        final chatRoom = chatRooms[index];

        return Dismissible(
          key: Key(chatRoom.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            context.read<ChatBloc>().add(DeleteChatRoom(chatRoom.id));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Chat with ${chatRoom.otherUserName} removed'),
                action: SnackBarAction(
                  label: 'UNDO',
                  onPressed: () {
                    context.read<ChatBloc>().add(UndoDeleteChatRoom());
                  },
                ),
              ),
            );
          },
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundImage: chatRoom.otherUserPhotoUrl != null
                      ? NetworkImage(chatRoom.otherUserPhotoUrl!)
                      : null,
                  child: chatRoom.otherUserPhotoUrl == null
                      ? Text(chatRoom.otherUserName[0].toUpperCase())
                      : null,
                ),
                if (chatRoom.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              chatRoom.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: chatRoom.lastMessage != null
                ? Text(
                    chatRoom.lastMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const Text("No messages yet"),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                chatRoom.lastMessageTime != null
                    ? Text(
                        _formatLastMessageTime(chatRoom.lastMessageTime),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      )
                    : const SizedBox(),
                const SizedBox(height: 4),
                if (chatRoom.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chatRoom.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              // Create EmergencyContact from ChatRoom
              final contact = EmergencyContact(
                id: chatRoom.otherUserId,
                name: chatRoom.otherUserName,
                phoneNumber: '',
                countryCode: '+1',
                relation: '',
                secretMessage: '',
                isFollowing: true,
                userId: chatRoom.otherUserId,
                photoURL: chatRoom.otherUserPhotoUrl,
              );

              // Navigate to chat page
              context.goToChat(contact);
            },
          ),
        );
      },
    );
  }
}
