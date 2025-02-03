import 'package:flutter/material.dart';
import 'package:resq/pages/settings/settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Indicates whether the profile is in editing mode.
  bool _isEditing = false;

  // Text controllers for each editable field.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with default values. In a real app these might come from a backend.
    _nameController.text = "John Doe";
    _emailController.text = "john.doe@example.com";
    _phoneController.text = "123-456-7890";
    _bioController.text = "A short bio about John Doe...";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Toggle between edit and view mode.
  void _toggleEdit() {
    if (_isEditing) {
      // Save changes if needed. You could add logic here to update a backend.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details saved.')),
      );
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  /// Optionally, add a method to update the profile picture.
  void _changeProfilePicture() {
    // TODO: Implement logic to pick a new profile picture (e.g., using image_picker).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change profile picture tapped.')),
    );
  }

  /// Helper widget to build an editable text field.
  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      enabled: _isEditing,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Picture with an edit icon overlay when in edit mode.
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: const AssetImage(
                      'assets/images/profile_pic.png',
                    ),
                    // You can use a NetworkImage if you have a URL.
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _changeProfilePicture,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(
                            Icons.camera_alt,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Editable fields for profile details.
            _buildTextField("Name", _nameController),
            const SizedBox(height: 16),
            _buildTextField("Email", _emailController),
            const SizedBox(height: 16),
            _buildTextField("Phone", _phoneController),
            const SizedBox(height: 16),
            _buildTextField("Bio", _bioController, maxLines: 3),
          ],
        ),
      ),
    );
  }
}
