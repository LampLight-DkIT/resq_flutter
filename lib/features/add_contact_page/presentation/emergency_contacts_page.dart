import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    if (currentUser != null) {
      context
          .read<EmergencyContactsBloc>()
          .add(LoadEmergencyContacts(currentUser!.uid));
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
      ),
      body: BlocBuilder<EmergencyContactsBloc, EmergencyContactsState>(
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
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
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
                          DeleteEmergencyContact(currentUser!.uid, contact.id),
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
                            backgroundImage: NetworkImage(contact.photoURL!),
                          )
                        : CircleAvatar(
                            backgroundColor: AppColors.darkBlue,
                            child: Text(
                              contact.name[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                    title: Text(contact.name),
                    subtitle: Text(
                      contact.isFollowing ? 'App User' : contact.relation,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (contact.isFollowing)
                          IconButton(
                            icon: const Icon(Icons.chat_outlined,
                                color: AppColors.darkBlue),
                            onPressed: () {},
                          ),
                        IconButton(
                          icon: const Icon(Icons.warning_amber_outlined,
                              color: Colors.red),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EmergencyAlertPage(contact: contact),
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
