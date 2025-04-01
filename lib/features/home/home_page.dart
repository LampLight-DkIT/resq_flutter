import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_contacts_page.dart';
import 'package:resq/features/chats/presentation/chat_list_page.dart';
import 'package:resq/features/notification/notification_page.dart';
import 'package:resq/features/profile/presentation/profile_page.dart';
import 'package:resq/core/services/shake_detection_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  double _shakeSensitivity = 15.0;

  // Updated pages list to include EmergencyContactsPage
  final List<Widget> _pages = [
    const ChatListPage(),
    const EmergencyContactsPage(),
    const NotificationPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize shake detection service
    ShakeDetectionService().initialize(
      onShake: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.vibration, color: Colors.white),
                SizedBox(width: 8),
                Text('Hard shake detected! 🎯'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _adjustSensitivity(double value) {
    setState(() {
      _shakeSensitivity = value;
    });
    ShakeDetectionService().setSensitivity(value);
  }

  @override
  void dispose() {
    ShakeDetectionService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _pages[_selectedIndex],
          // Add sensitivity control button
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton.small(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Adjust Shake Sensitivity'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            'Current sensitivity: ${_shakeSensitivity.toStringAsFixed(1)}'),
                        Slider(
                          value: _shakeSensitivity,
                          min: 5.0,
                          max: 30.0,
                          divisions: 25,
                          label: _shakeSensitivity.toStringAsFixed(1),
                          onChanged: _adjustSensitivity,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              backgroundColor: AppColors.darkBlue,
              child: Icon(Icons.tune),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
        child: GNav(
          gap: 8,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.0),
          backgroundColor: Colors.white,
          color: Colors.grey[800],
          activeColor: Colors.white,
          tabBackgroundColor: AppColors.darkBlue,
          selectedIndex: _selectedIndex,
          onTabChange: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          iconSize: 20.0,
          textStyle: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Colors.white,
              ),
          tabs: [
            const GButton(icon: Icons.forum, text: 'Chats'),
            const GButton(
              icon: Icons.help_outlined,
              text: 'Alerts',
            ),
            const GButton(icon: Icons.notifications, text: 'Alerts'),
            const GButton(icon: Icons.person, text: 'Profile'),
          ],
        ),
      ),
    );
  }
}
