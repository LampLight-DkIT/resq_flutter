// lib/features/user_discovery/presentation/user_discovery_screen.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/add_contact_page/model/emergency_contact_model.dart';
import 'package:resq/features/user/bloc/user_state.dart';
import 'package:resq/router/router.dart';

import '../../user/bloc/user_bloc.dart' show UserBloc;
import '../../user/bloc/user_event.dart'
    show FollowUser, SearchUsers, UnfollowUser;
import '../../user/repository/user_repository.dart';

class DiscoverUsersPage extends StatelessWidget {
  const DiscoverUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a UserRepository and provide a UserBloc
    return BlocProvider(
      create: (context) => UserBloc(repository: UserRepository()),
      child: const DiscoverUsersPageContent(),
    );
  }
}

class DiscoverUsersPageContent extends StatefulWidget {
  const DiscoverUsersPageContent({super.key});

  @override
  _DiscoverUsersPageContentState createState() =>
      _DiscoverUsersPageContentState();
}

class _DiscoverUsersPageContentState extends State<DiscoverUsersPageContent> {
  final TextEditingController _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Add debug output
    if (kDebugMode) {
      print("⚡ DiscoverUsersPage initialized");
      print("⚡ Using BLoC: ${context.read<UserBloc>().runtimeType}");
    }

    // Load all users initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print("⚡ Attempting to load all users with empty query");
        // Use explicit import for SearchUsers from users/bloc/user_event.dart
        context.read<UserBloc>().add(
              SearchUsers(
                '', // Empty query to get all users
                currentUser.uid,
              ),
            );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        // Use explicit import for SearchUsers from users/bloc/user_event.dart
        context.read<UserBloc>().add(
              SearchUsers(
                _searchController.text,
                _auth.currentUser!.uid,
              ),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Users'),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          BlocBuilder<UserBloc, UserState>(
            builder: (context, state) {
              if (state is UserSearchLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is UserSearchError) {
                return Center(
                  child: Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              } else if (state is UserSearchLoaded) {
                final users = state.users;

                if (users.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? "Search to find users"
                                : "No users found",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isFollowing = user['isFollowing'] ?? false;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['photoURL'] != null
                              ? NetworkImage(user['photoURL'])
                              : null,
                          child: user['photoURL'] == null
                              ? Text(user['name'][0].toUpperCase())
                              : null,
                        ),
                        title: Text(user['name'] ?? 'User'),
                        subtitle: Text(user['email'] ?? ''),
                        trailing: isFollowing
                            ? ElevatedButton(
                                onPressed: () {
                                  // Use explicit import for UnfollowUser from users/bloc/user_event.dart
                                  context.read<UserBloc>().add(
                                        UnfollowUser(
                                          _auth.currentUser!.uid,
                                          user['id'],
                                        ),
                                      );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                  foregroundColor: Colors.black,
                                ),
                                child: const Text('Unfollow'),
                              )
                            : ElevatedButton(
                                onPressed: () {
                                  // Use explicit import for FollowUser from users/bloc/user_event.dart
                                  context.read<UserBloc>().add(
                                        FollowUser(
                                          _auth.currentUser!.uid,
                                          user['id'],
                                        ),
                                      );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBlue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Follow'),
                              ),
                        onTap: () {
                          if (isFollowing) {
                            // Create EmergencyContact from user data
                            final contact = EmergencyContact(
                              id: user['id'],
                              name: user['name'] ?? 'User',
                              phoneNumber: user['phoneNumber'] ?? '',
                              countryCode: user['countryCode'] ?? '+1',
                              relation: 'App User',
                              secretMessage: '',
                              isFollowing: true,
                              userId: user['id'],
                              photoURL: user['photoURL'],
                            );

                            // Navigate to chat
                            context.goToChat(contact);
                          }
                        },
                      );
                    },
                  ),
                );
              }

              return Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Search to find users",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
