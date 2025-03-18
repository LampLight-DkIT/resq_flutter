import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_event.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_state.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';

class AddContactPage extends StatelessWidget {
  const AddContactPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a repository instance directly (not relying on RepositoryProvider)
    final repository = EmergencyContactsRepository();

    // Create a local EmergencyContactsBloc for this page
    return BlocProvider(
      create: (context) => EmergencyContactsBloc(repository: repository),
      child: const AddContactPageContent(),
    );
  }
}

class AddContactPageContent extends StatefulWidget {
  const AddContactPageContent({Key? key}) : super(key: key);

  @override
  State<AddContactPageContent> createState() => _AddContactPageContentState();
}

class _AddContactPageContentState extends State<AddContactPageContent>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _secretMessageController =
      TextEditingController();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Country code for phone
  String _countryCode = '+1';

  // Relation dropdown value
  String _selectedRelation = 'Family';

  // List of possible relations
  final List<String> _relations = [
    'Family',
    'Friend',
    'Colleague',
    'Emergency Contact',
    'Doctor',
    'Other'
  ];

  @override
  void initState() {
    super.initState();

    // Default emergency message
    _secretMessageController.text = "Help! I'm in an emergency situation.";

    // Animation setup: slide up from bottom
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _secretMessageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _saveContact() {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to add contacts"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ensure userId is assigned
    final contact = EmergencyContact(
      id: '', // Firestore will assign a unique ID
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      countryCode: _countryCode,
      relation: _selectedRelation,
      secretMessage: _secretMessageController.text.trim(),
      isFollowing: false, // This is a manually added contact
      userId: currentUser.uid, // ✅ Assign userId properly
    );

    // Add the contact via BLoC
    context.read<EmergencyContactsBloc>().add(
          AddEmergencyContact(currentUser.uid, contact),
        );

    // Navigate back
    Navigator.pop(context);
  }

  /// Helper method to create a consistent input decoration style.
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Icon? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Emergency Contact'),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      body: BlocListener<EmergencyContactsBloc, EmergencyContactsState>(
        listener: (context, state) {
          if (state is EmergencyContactsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Contact Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add,
                        size: 40,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Form Header
                  Text(
                    "Emergency Contact Information",
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Name Field
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      label: "Name",
                      hint: "Enter contact name",
                      icon: const Icon(Icons.person_outline),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // Phone Number Field with Country Code using IntlPhoneField
                  IntlPhoneField(
                    decoration: _inputDecoration(
                      label: "Phone Number",
                      hint: "Enter phone number",
                      icon: const Icon(Icons.phone_outlined),
                    ),
                    initialCountryCode: 'US',
                    onChanged: (phone) {
                      // Store country code and phone number separately
                      setState(() {
                        _countryCode = phone.countryCode;
                        _phoneController.text = phone.number;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Relation Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedRelation,
                    decoration: _inputDecoration(
                      label: "Relation",
                      hint: "Select relation",
                      icon: const Icon(Icons.people_outline),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: _relations.map((String relation) {
                      return DropdownMenuItem(
                        value: relation,
                        child: Text(relation),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRelation = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Emergency Message Field
                  TextField(
                    controller: _secretMessageController,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      label: "Emergency Message",
                      hint: "Message to send in emergency",
                      icon: const Icon(Icons.warning_amber_outlined),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Info text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "This message will be sent to your contact when you trigger an emergency alert.",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  BlocBuilder<EmergencyContactsBloc, EmergencyContactsState>(
                    builder: (context, state) {
                      final isLoading = state is EmergencyContactsLoading;

                      return SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _saveContact,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Save Contact",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
