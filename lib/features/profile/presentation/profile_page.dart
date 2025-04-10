import 'dart:io';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_state.dart';
import 'package:resq/features/auth/repository/auth_repository.dart';
import 'package:resq/features/profile/bloc/profile_bloc.dart';
import 'package:resq/features/profile/bloc/profile_event.dart';
import 'package:resq/features/profile/bloc/profile_state.dart';
import 'package:resq/router/router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the AuthRepository from the widget tree
    final authRepository = RepositoryProvider.of<AuthRepository>(context);

    // Create a ProfileBloc for this page
    return BlocProvider(
      create: (context) => ProfileBloc(authRepository: authRepository),
      child: const ProfilePageContent(),
    );
  }
}

class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  // Indicates whether the profile is in editing mode.
  bool _isEditing = false;

  // Text controllers for each editable field.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Country code data
  String _selectedCountryCode = '+1';

  // Image upload state
  File? _selectedImage;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Load profile data when the page is created
    _loadProfileData();
  }

  void _loadProfileData() {
    // Get the current user ID from Firebase Auth
    final currentUser = context.read<AuthBloc>().state;
    if (currentUser is AuthAuthenticated) {
      // Load profile using the ProfileBloc
      context
          .read<ProfileBloc>()
          .add(LoadProfile(userId: currentUser.user.uid));
    }
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
      _saveProfileChanges();
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  /// Save profile changes
  void _saveProfileChanges() {
    final currentUser = context.read<AuthBloc>().state;
    if (currentUser is AuthAuthenticated) {
      // Strip any country code prefix from the phone number if it exists
      final phoneWithoutCode = _phoneController.text.startsWith('+')
          ? _phoneController.text.replaceFirst(RegExp(r'^\+\d+\s*'), '')
          : _phoneController.text.trim();

      context.read<ProfileBloc>().add(
            UpdateProfile(
              userId: currentUser.user.uid,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phoneNumber: phoneWithoutCode,
              countryCode: _selectedCountryCode,
              bio: _bioController.text.trim(),
            ),
          );
    }
  }

  /// Method to pick and update the profile picture
  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        // If we're in edit mode, upload the image immediately
        if (_isEditing) {
          _uploadProfileImage();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: ${e.toString()}')),
      );
    }
  }

  /// Upload the profile image to Firebase Storage
  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) return;

    final currentUser = context.read<AuthBloc>().state;
    if (currentUser is! AuthAuthenticated) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Create a reference to the location you want to upload to in Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${currentUser.user.uid}.jpg');

      // Upload the file
      await storageRef.putFile(_selectedImage!);

      // Get download URL
      final downloadURL = await storageRef.getDownloadURL();

      // Update profile with new photo URL
      context.read<ProfileBloc>().add(
            UpdateProfile(
              userId: currentUser.user.uid,
              photoURL: downloadURL,
            ),
          );

      setState(() {
        _isUploadingImage = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
    }
  }

  /// Helper widget to build an editable text field.
  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      enabled: _isEditing,
      maxLines: maxLines,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// Helper widget to build the phone field with country code picker
  Widget _buildPhoneField() {
    return Row(
      children: [
        // Country code picker
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey,
            ),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(4),
            ),
          ),
          child: CountryCodePicker(
            onChanged: (CountryCode countryCode) {
              setState(() {
                _selectedCountryCode = countryCode.dialCode ?? '+1';
              });
            },
            initialSelection: _getCountryFromDialCode(_selectedCountryCode),
            favorite: const ['US', 'CA', 'GB', 'IN'],
            showCountryOnly: false,
            showOnlyCountryWhenClosed: false,
            alignLeft: false,
            enabled: _isEditing,
          ),
        ),
        // Phone number input
        Expanded(
          child: TextField(
            controller: _phoneController,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Helper method to convert dial code to country code
  String _getCountryFromDialCode(String dialCode) {
    // Map common dial codes to country codes
    Map<String, String> dialToCountry = {
      '+1': 'US',
      '+44': 'GB',
      '+91': 'IN',
      '+61': 'AU',
      '+86': 'CN',
      '+49': 'DE',
      '+33': 'FR',
      '+81': 'JP',
      '+7': 'RU',
      '+55': 'BR',
      '+52': 'MX',
      '+39': 'IT',
      '+34': 'ES',
      '+82': 'KR',
      '+1': 'CA',
    };

    return dialToCountry[dialCode] ?? 'US'; // Default to US if not found
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
              context.goToSettings();
            },
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ProfileLoaded) {
            if (!_isEditing) {
              // Update text controllers with loaded data
              _nameController.text = state.profileData['name'] ?? '';
              _emailController.text = state.profileData['email'] ?? '';
              _bioController.text = state.profileData['bio'] ?? '';

              // Set country code from profile data
              _selectedCountryCode = state.profileData['countryCode'] ?? '+1';

              // Set phone number without the country code
              _phoneController.text = state.profileData['phoneNumber'] ?? '';
            }
          }
        },
        builder: (context, state) {
          if (state is ProfileInitial || state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Picture with an edit icon overlay when in edit mode.
                Center(
                  child: Stack(
                    children: [
                      if (_isUploadingImage)
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          child: CircularProgressIndicator(),
                        )
                      else if (_selectedImage != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: FileImage(_selectedImage!),
                        )
                      else if (state is ProfileLoaded &&
                          state.profileData['photoURL'] != null)
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              NetworkImage(state.profileData['photoURL']),
                        )
                      else
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.darkBlue,
                          child: Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : '?',
                            style: TextStyle(fontSize: 30, color: Colors.white),
                          ),
                        ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _changeProfilePicture,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: AppColors.darkBlue,
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
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildTextField("Bio", _bioController, maxLines: 3),
              ],
            ),
          );
        },
      ),
    );
  }
}
