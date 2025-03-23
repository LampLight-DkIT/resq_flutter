import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/add_contact_page/presentation/add_contact_page.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_alert_page.dart';
import 'package:resq/features/add_contact_page/presentation/emergency_contacts_page.dart';
import 'package:resq/features/auth/presentation/login_screen.dart';
import 'package:resq/features/auth/presentation/sign_up_screen.dart';
import 'package:resq/features/chats/presentation/chats_page.dart';
import 'package:resq/features/home/home_page.dart';
import 'package:resq/features/intro/intro_one.dart';
import 'package:resq/features/intro/splash_screen.dart';
import 'package:resq/features/notification/notification_page.dart';
import 'package:resq/features/profile/presentation/profile_page.dart';
import 'package:resq/features/settings/settings_page.dart';
import 'package:resq/features/user_discovery/presentation/user_discovery_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const intro = '/intro';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const emergencyContacts = '/emergency-contacts';
  static const addContact = '/add-contact';
  static const emergencyAlert = '/emergency-alert';
  static const chat = '/chat';
  static const profile = '/profile';
  static const settings = '/settings';
  static const shakeSettings = '/settings/shake'; // Add new route
  static const discoverUsers = '/discover-users';
  static const notifications = '/notifications';
}

final GoRouter router = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.intro,
      builder: (context, state) => const IntroPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignUpPage(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.emergencyContacts,
      builder: (context, state) => const EmergencyContactsPage(),
    ),
    GoRoute(
      path: AppRoutes.addContact,
      builder: (context, state) => const AddContactPage(),
    ),
    GoRoute(
      path: AppRoutes.emergencyAlert,
      builder: (context, state) {
        final contact = state.extra as EmergencyContact;
        return EmergencyAlertPage(contact: contact);
      },
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (context, state) {
        final contact = state.extra as EmergencyContact;
        return ChatPage(contact: contact);
      },
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfilePage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.discoverUsers,
      builder: (context, state) => const DiscoverUsersPage(),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => const NotificationPage(),
    ),
  ],
  // Optional: Add error handler for unknown routes
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);

// Extension to simplify navigation
extension NavigationExtensions on BuildContext {
  // Shorthand methods for common navigation actions
  void goToHome() => go(AppRoutes.home);
  void goToLogin() => go(AppRoutes.login);
  void goToSignup() => go(AppRoutes.signup);
  void goToEmergencyContacts() => go(AppRoutes.emergencyContacts);
  void goToAddContact() => go(AppRoutes.addContact);
  void goToProfile() => go(AppRoutes.profile);
  void goToSettings() => go(AppRoutes.settings);
  void goToShakeSettings() =>
      go(AppRoutes.shakeSettings); // Add new navigation method

  // Method to navigate to chat with a specific contact
  // Changed from go() to push() to maintain navigation stack
  void goToChat(EmergencyContact contact) =>
      push(AppRoutes.chat, extra: contact);

  // Method to navigate to emergency alert for a specific contact
  void goToEmergencyAlert(EmergencyContact contact) =>
      push(AppRoutes.emergencyAlert, extra: contact);

  void goToDiscoverUsers() => push(AppRoutes.discoverUsers);

  void goToNotifications() => go(AppRoutes.notifications);
}
