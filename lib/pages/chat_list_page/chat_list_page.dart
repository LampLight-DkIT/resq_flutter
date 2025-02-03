import 'package:flutter/material.dart';
import 'package:resq/pages/add_contact_page/add_contact_page.dart';
import 'package:resq/pages/chats/chats_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class Contact {
  final String name;
  final String relation;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? status;
  final bool isOnline;

  Contact({
    required this.name,
    required this.relation,
    this.lastMessage,
    this.lastMessageTime,
    this.status = 'Offline',
    this.isOnline = false,
  });

  Map<String, String> toMap() {
    return {
      'name': name,
      'relation': relation,
      'status': status ?? 'Offline',
    };
  }
}

class _ChatListPageState extends State<ChatListPage> {
  List<Contact> _contacts = [];
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _filteredContacts = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredContacts = _contacts;
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.relation.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _navigateToAddContactPage() async {
    final newContact = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddContactPage()),
    );

    if (newContact != null) {
      setState(() {
        _contacts.add(Contact(
          name: newContact['name']!,
          relation: newContact['relation']!,
          lastMessage: 'Hey there!',
          lastMessageTime: DateTime.now(),
          isOnline: true,
        ));
        _filterContacts();
      });
    }
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
                  hintText: 'Search contacts...',
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
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              // Handle menu selections
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
      body: Column(
        children: [
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(
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
                              ? "No contacts found"
                              : "No contacts yet!\nTap + to add new contacts",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      return Dismissible(
                        key: Key(contact.name),
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
                          setState(() {
                            _contacts.removeAt(index);
                            _filterContacts();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${contact.name} removed'),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  setState(() {
                                    _contacts.insert(index, contact);
                                    _filterContacts();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                child: Text(contact.name[0].toUpperCase()),
                              ),
                              if (contact.isOnline)
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
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            contact.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: contact.lastMessage != null
                              ? Text(
                                  contact.lastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(contact.relation),
                          trailing: contact.lastMessageTime != null
                              ? Text(
                                  _formatLastMessageTime(
                                      contact.lastMessageTime),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChatPage(contact: contact.toMap()),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddContactPage,
        child: const Icon(Icons.add),
      ),
    );
  }
}
