import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
import 'package:resq/features/notification/notification_items.dart';
import 'package:resq/router/router.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create repository directly instead of getting it from the widget tree
    final repository = EmergencyContactsRepository();

    // Create a local EmergencyContactsBloc for this page
    return BlocProvider(
      create: (context) => EmergencyContactsBloc(repository: repository),
      child: const EmergencyContactsPageContent(),
    );
  }
}

class EmergencyContactsPageContent extends StatefulWidget {
  const EmergencyContactsPageContent({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsPageContent> createState() =>
      _EmergencyContactsPageContentState();
}

class _EmergencyContactsPageContentState
    extends State<EmergencyContactsPageContent> {
  final currentUser = FirebaseAuth.instance.currentUser;
  List<NotificationItem> _recentAlerts = [];
  bool _isLoadingAlerts = true;
  bool _showAlerts = true; // Controls visibility of the alerts section

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _loadRecentAlerts();
  }

  void _loadContacts() {
    if (currentUser != null) {
      context
          .read<EmergencyContactsBloc>()
          .add(LoadEmergencyContacts(currentUser!.uid));
    }
  }

  // Load recent emergency alerts from NotificationService
  Future<void> _loadRecentAlerts() async {
    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      // Get all notifications from the service
      final allNotifications = await NotificationService().getNotifications();

      // Filter to only show emergency type notifications
      final emergencyAlerts = allNotifications
          .where((notification) =>
              notification.type == 'emergency' ||
              notification.type == 'trigger')
          .toList();

      // Sort by timestamp (newest first)
      emergencyAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Take only the most recent 5 alerts
      final recentAlerts = emergencyAlerts.take(5).toList();

      setState(() {
        _recentAlerts = recentAlerts;
        _isLoadingAlerts = false;
      });
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        _isLoadingAlerts = false;
      });
    }
  }

  void _navigateToAddContact() async {
    context.goToAddContact();
    // Refresh contacts after returning
    _loadContacts();
  }

  void _deleteContact(EmergencyContact contact) {
    if (currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
            'Are you sure you want to delete ${contact.name} from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<EmergencyContactsBloc>().add(
                    DeleteEmergencyContact(currentUser!.uid, contact.id),
                  );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showContactActions(EmergencyContact contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact.isFollowing)
              IconButton(
                icon:
                    const Icon(Icons.chat_outlined, color: AppColors.darkBlue),
                onPressed: () {
                  context.goToChat(contact);
                },
              ),
            if (contact.isFollowing) // Only show for app users you're following
              ListTile(
                leading: const Icon(Icons.person_outlined,
                    color: AppColors.darkBlue),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to user profile here
                  context.goToEmergencyAlert(contact);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.warning_amber_outlined, color: Colors.red),
              title: const Text('Send Emergency Alert'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyAlertPage(contact: contact),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.darkBlue),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit contact page
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Format timestamp for alerts
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Build the alerts section
  Widget _buildAlertsSection() {
    if (_isLoadingAlerts) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_recentAlerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No recent alerts',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Alerts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.goToNotifications(); // Assuming you have this route
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentAlerts.length,
          itemBuilder: (context, index) {
            final alert = _recentAlerts[index];

            IconData iconData;
            Color iconColor;

            // Determine icon and color based on notification type
            switch (alert.type) {
              case 'emergency':
                iconData = Icons.warning_amber_rounded;
                iconColor = Colors.red;
                break;
              case 'trigger':
                iconData = Icons.notifications_active;
                iconColor = Colors.orange;
                break;
              default:
                iconData = Icons.notifications;
                iconColor = Colors.blue;
            }

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor),
                ),
                title: Text(
                  alert.title,
                  style: TextStyle(
                    fontWeight:
                        alert.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${alert.message}\n${_formatTimestamp(alert.timestamp)}',
                ),
                isThreeLine: true,
                onTap: () async {
                  // Mark as read and navigate to detailed view if needed
                  await NotificationService().markAsRead(alert.id);
                  setState(() {
                    final index =
                        _recentAlerts.indexWhere((item) => item.id == alert.id);
                    if (index >= 0) {
                      _recentAlerts[index] = alert.copyWith(isRead: true);
                    }
                  });
                },
              ),
            );
          },
        ),
        const Divider(thickness: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(
        child: Text('You must be logged in to view emergency contacts'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        titleTextStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w700,
            ),
        centerTitle: true,
        actions: [
          // Add refresh button to refresh alerts
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadRecentAlerts();
              _loadContacts();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadRecentAlerts(),
          ]);
          _loadContacts();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Alerts section with expand/collapse functionality
              InkWell(
                onTap: () {
                  setState(() {
                    _showAlerts = !_showAlerts;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text(
                        'Emergency Alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showAlerts
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                      ),
                    ],
                  ),
                ),
              ),

              // Collapsible alerts section
              if (_showAlerts) _buildAlertsSection(),

              // Contacts section
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contacts',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // Contacts list with BlocBuilder
              BlocBuilder<EmergencyContactsBloc, EmergencyContactsState>(
                builder: (context, state) {
                  print("Bloc State: $state");

                  if (state is EmergencyContactsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is EmergencyContactsError) {
                    return Center(
                      child: Text(
                        'Error: ${state.message}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (state is EmergencyContactsLoaded) {
                    final contacts = state.contacts;

                    if (contacts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No emergency contacts yet\nTap + to add new contacts',
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

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return Dismissible(
                          key: Key(contact.id),
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
                          confirmDismiss: (direction) async {
                            final confirmed = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Contact'),
                                content: Text(
                                    'Are you sure you want to delete ${contact.name} from your emergency contacts?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            return confirmed;
                          },
                          onDismissed: (direction) {
                            context.read<EmergencyContactsBloc>().add(
                                  DeleteEmergencyContact(
                                      currentUser!.uid, contact.id),
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${contact.name} removed'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () {
                                    // Re-add the contact
                                    context.read<EmergencyContactsBloc>().add(
                                          AddEmergencyContact(
                                              currentUser!.uid, contact),
                                        );
                                  },
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            leading: contact.photoURL != null
                                ? CircleAvatar(
                                    backgroundImage:
                                        NetworkImage(contact.photoURL!),
                                  )
                                : CircleAvatar(
                                    backgroundColor: AppColors.darkBlue,
                                    child: Text(
                                      contact.name[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ),
                            title: Text(contact.name),
                            subtitle: Text(
                              contact.isFollowing
                                  ? 'App User'
                                  : contact.relation,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (contact.isFollowing)
                                  IconButton(
                                    icon: const Icon(Icons.chat_outlined,
                                        color: AppColors.darkBlue),
                                    onPressed: () {
                                      context.goToChat(contact);
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.warning_amber_outlined,
                                      color: Colors.red),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EmergencyAlertPage(
                                                contact: contact),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showContactActions(contact),
                                ),
                              ],
                            ),
                            onTap: () => _showContactActions(contact),
                          ),
                        );
                      },
                    );
                  }

                  // Default state
                  return const Center(child: Text('Add emergency contacts'));
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddContact,
        backgroundColor: AppColors.darkBlue,
        child: Icon(
          Icons.add,
          color: AppColors.base,
        ),
      ),
    );
  }
}
