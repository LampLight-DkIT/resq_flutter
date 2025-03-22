import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_event.dart';
import 'package:resq/router/router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<bool> _onWillPop() async {
    if (context.canPop()) {
      context.pop();
      return false;
    } else {
      // Navigate to home instead of exiting
      context.goToHome();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Safely navigate back without exiting the app
              if (context.canPop()) {
                context.pop();
              } else {
                context.goToHome();
              }
            },
          ),
        ),
        body: ListView(
          children: [
            // Only keep the logout option
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Show logout confirmation dialog
                _showLogoutConfirmationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Only keep the logout dialog method
  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog

              // Dispatch the correct logout event to AuthBloc
              try {
                context.read<AuthBloc>().add(AuthLogout());

                // Navigate to login page after logout
                Future.delayed(const Duration(milliseconds: 300), () {
                  context.goToLogin();
                });
              } catch (e) {
                print("Error during logout: $e");
                // Fallback if there's an error
                context.goToLogin();
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
