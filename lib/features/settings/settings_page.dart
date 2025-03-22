import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Toggles for various settings.
  bool _isDarkTheme = false;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _locationSharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          // =========================
          // Account Settings Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Account Settings",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            subtitle: const Text("Edit your profile details"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Profile screen.
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change Password"),
            subtitle: const Text("Update your password"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Change Password screen.
            },
          ),
          const Divider(),

          // =========================
          // Emergency Features Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Emergency Features",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.vibration, color: Colors.red),
            title: const Text("Shake Detection"),
            subtitle: const Text(
                "Configure emergency alerts when you shake your device"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to shake settings screen
              context.push('/settings/shake');
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.location_on, color: Colors.red),
            title: const Text("Location Sharing in Emergencies"),
            value: _locationSharing,
            onChanged: (value) {
              setState(() {
                _locationSharing = value;
              });
            },
          ),
          const Divider(),

          // =========================
          // Notifications Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Notifications",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Push Notifications"),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.email),
            title: const Text("Email Notifications"),
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),
          const Divider(),

          // =========================
          // Privacy Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Privacy",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("Privacy Policy"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Privacy Policy screen.
            },
          ),
          ListTile(
            leading: const Icon(Icons.vpn_lock),
            title: const Text("Two-Factor Authentication"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Two-Factor Authentication screen.
            },
          ),
          const Divider(),

          // =========================
          // Display / Appearance Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Display",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.brightness_6),
            title: const Text("Dark Theme"),
            value: _isDarkTheme,
            onChanged: (value) {
              setState(() {
                _isDarkTheme = value;
                // TODO: Apply the theme change to the app if needed.
              });
            },
          ),
          const Divider(),

          // =========================
          // Other Settings Section
          // =========================
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Other",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Language"),
            subtitle: const Text("Change app language"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Language selection screen.
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            subtitle: const Text("Version info, Terms & Conditions, etc."),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to About screen.
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text("Feedback"),
            subtitle: const Text("Send us your feedback"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Navigate to Feedback screen.
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // TODO: Handle the logout functionality.
            },
          ),
        ],
      ),
    );
  }
}
