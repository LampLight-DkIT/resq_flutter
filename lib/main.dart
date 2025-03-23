import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:resq/core/services/app_initialization_service.dart';
import 'package:resq/features/add_contact_page/bloc/emergency_contact_bloc.dart';
import 'package:resq/features/add_contact_page/repository/emergency_contact_repository.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_event.dart';
import 'package:resq/features/auth/bloc/auth_state.dart';
import 'package:resq/features/auth/repository/auth_repository.dart';
import 'package:resq/features/chats/bloc/chat_bloc.dart';
import 'package:resq/features/chats/bloc/chat_event.dart';
import 'package:resq/features/chats/repository/chat_repository.dart';
import 'package:resq/features/user/bloc/user_bloc.dart';
import 'package:resq/features/user/repository/user_repository.dart';
import 'package:resq/firebase_options.dart';
import 'package:resq/router/router.dart';

import 'constants/constants.dart';
import 'core/services/emergency_alert_listener.dart';
import 'core/services/trigger_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize the notification service
  await TriggerNotificationService().initialize();

  await EmergencyAlertListener().initialize();

  // First, initialize the AppInitializationService properly
  final appInitService = AppInitializationService();
  await appInitService.initializeApp();

  // Use the chatCacheRepository from the service instead of creating a new one
  final chatCacheRepository = appInitService.chatCacheRepository;

  // Initialize repositories
  final authRepository = AuthRepository();
  final emergencyContactsRepository = EmergencyContactsRepository();

  // Create chat repository with the cache from the service
  final chatRepository = ChatRepository(cacheRepository: chatCacheRepository);

  // Now create user repository with the properly initialized chat repository
  final userRepository = UserRepository();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: emergencyContactsRepository),
        RepositoryProvider.value(value: chatRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: chatCacheRepository),
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
            create: (context) => ChatBloc(
              repository: chatRepository,
            )..add(ProcessPendingMessages()),
          ),
          BlocProvider<UserBloc>(
            create: (context) => UserBloc(
              repository: userRepository,
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

class MyApp extends StatefulWidget {
  final GoRouter routerConfig;

  const MyApp({super.key, required this.routerConfig});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authState = context.watch<AuthBloc>().state;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Only trigger navigation when state actually changes
        return previous.runtimeType != current.runtimeType;
      },
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.read<ChatBloc>().add(ProcessPendingMessages());
          widget.routerConfig.go('/home');
        } else if (state is AuthUnauthenticated) {
          widget.routerConfig.go('/intro');
        }
      },
      child: MaterialApp.router(
        title: "Resq",
        debugShowCheckedModeBanner: false,
        routerConfig: widget.routerConfig,
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
