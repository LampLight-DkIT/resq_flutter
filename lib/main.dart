// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_event.dart';
import 'package:resq/features/auth/bloc/auth_state.dart';
import 'package:resq/features/auth/repository/auth_repository.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/repository/chat_repository.dart';
import 'package:resq/features/user/repository/user_repository.dart';
import 'package:resq/firebase_options.dart';
import 'package:resq/router/router.dart';

import 'constants/constants.dart';
import 'features/user/bloc/user_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize repositories
  final authRepository = AuthRepository();
  final emergencyContactsRepository = EmergencyContactsRepository();
  final chatRepository = ChatRepository();
  final userRepository = UserRepository();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: emergencyContactsRepository),
        RepositoryProvider.value(value: chatRepository),
        RepositoryProvider.value(value: userRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepository)
              ..add(AuthCheckStatus()),
          ),
          BlocProvider(
            create: (context) =>
                EmergencyContactsBloc(repository: emergencyContactsRepository),
          ),
          BlocProvider(
            create: (context) => ChatBloc(repository: chatRepository),
          ),
          BlocProvider<UserBloc>(
            create: (context) => UserBloc(
              repository: UserRepository(), // Provide the repository directly
            ),
          ),
        ],
        child: MyApp(
          routerConfig: router,
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter routerConfig;

  const MyApp({super.key, required this.routerConfig});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          routerConfig.go('/home');
        } else if (state is AuthUnauthenticated) {
          routerConfig.go('/intro');
        }
      },
      child: MaterialApp.router(
        title: "Resq",
        debugShowCheckedModeBanner: false,
        routerConfig: routerConfig,
        theme: ThemeData(
          fontFamily: "TT Norms Pro",
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.darkBlue,
            primary: AppColors.darkBlue,
          ),
          useMaterial3: true,
        ),
      ),
    );
  }
}
