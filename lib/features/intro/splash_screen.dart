import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/features/auth/bloc/auth_bloc.dart';
import 'package:resq/features/auth/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Background fade-in animation
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Logo scale animation
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward(); // Start animation

    // Navigate based on auth state after animation completes
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _navigateBasedOnAuthState();
      }
    });
  }

  void _navigateBasedOnAuthState() {
    // Get the current auth state from the BLoC
    final authState = context.read<AuthBloc>().state;

    if (authState is AuthAuthenticated) {
      // If authenticated, go to home
      context.go("/home");
    } else {
      // If not authenticated, go to intro
      context.go("/intro");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      body: Stack(
        children: [
          // Background Fade-in Animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                );
              },
              child: Image.asset(
                AssetsManager.background,
                filterQuality: FilterQuality.high,
                color: AppColors.goldenYellow,
                fit: BoxFit.cover,
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.height / 2,
              ),
            ),
          ),

          // Logo Scaling Animation
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Image.asset(
                "assets/imgs/logos/resq-new.jpg",
                color: AppColors.goldenYellow,
                width: 250.0,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
