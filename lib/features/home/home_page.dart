import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_contacts_page.dart';
import 'package:resq/features/chats/presentation/chat_list_page.dart';
import 'package:resq/features/notification/notification_page.dart';
import 'package:resq/features/profile/presentation/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // Updated pages list to include EmergencyContactsPage
  final List<Widget> _pages = [
    const ChatListPage(),
    const EmergencyContactsPage(), // Add the emergency contacts page
    const NotificationPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_selectedIndex],
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
