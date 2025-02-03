import 'package:flutter/material.dart';
// Import the intl_phone_field package
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:resq/constants/constants.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({Key? key}) : super(key: key);

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  // We'll still use _contactController to store the complete number.
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _secretMessageController =
      TextEditingController();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

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
    _contactController.dispose();
    _secretMessageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _saveContact() {
    if (_nameController.text.isEmpty || _contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newContact = {
      "name": _nameController.text.trim(),
      "contact": _contactController.text.trim(),
      "relation": _selectedRelation,
      "secretMessage": _secretMessageController.text.trim(),
    };

    Navigator.pop(context, newContact);
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
      body: Center(
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
                  "Contact Information",
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
                  initialCountryCode:
                      'US', // Change this to your default country code.
                  onChanged: (phone) {
                    // phone.completeNumber contains the country code and number.
                    _contactController.text = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 16),

                // Relation Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedRelation,
                  decoration: _inputDecoration(
                    label: "",
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

                // Secret Message Field
                TextField(
                  controller: _secretMessageController,
                  maxLines: 1,
                  decoration: _inputDecoration(
                    label: "",
                    hint: "Enter secret message",
                    icon: const Icon(Icons.lock_outline),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text(
                      "Save Contact",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
