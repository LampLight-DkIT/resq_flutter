import 'package:flutter/material.dart';
import 'package:resq/constants/constants.dart';

class ResqApp extends StatefulWidget {
  const ResqApp({super.key});

  @override
  _ResqAppState createState() => _ResqAppState();
}

class _ResqAppState extends State<ResqApp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Adjust for smoothness
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
                color: AppColors.goldenYellow.withOpacity(0.3),
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
                AssetsManager.logoFull,
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
