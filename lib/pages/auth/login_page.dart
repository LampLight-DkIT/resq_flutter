import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/pages/auth/sign_up_page.dart';
import 'package:resq/pages/home/home_page.dart';
import 'package:resq/widget/social_login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    // Initialize Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Slide-Up Animation
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fade-in Animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start Animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the animation controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      AssetsManager.logoFull,
                      color: AppColors.goldenYellow,
                      width: 190.0,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 40),

                    // Email Field
                    TextField(
                      decoration: InputDecoration(
                        hintText: "Enter your email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),

                    // Password Field with Visibility Toggle
                    TextField(
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: "Enter your password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),

                    // Sign-in Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => HomePage()),
                            (Route<dynamic> route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkBlue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Sign In",
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text("OR",
                              style: TextStyle(color: Colors.grey[600])),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Google Sign-In Button
                    SocialLoginButton(
                      iconWidget: const FaIcon(FontAwesomeIcons.google,
                          color: Colors.black),
                      label: "Sign In with Google",
                      textColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      borderColor: AppColors.darkBlue,
                      borderRadius: 12.0,
                      paddingVertical: 14.0,
                      textStyle:
                          Theme.of(context).textTheme.bodyLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                      onPressed: () {
                        // Handle Google Sign-In
                      },
                    ),
                    const SizedBox(height: 12),

                    // Apple Sign-In Button
                    SocialLoginButton(
                      iconWidget: const FaIcon(FontAwesomeIcons.apple,
                          color: Colors.white),
                      label: "Sign In with Apple",
                      textColor: Colors.white,
                      backgroundColor: Colors.black,
                      borderColor: Colors.black,
                      borderRadius: 12.0,
                      paddingVertical: 14.0,
                      textStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(
                              fontWeight: FontWeight.w700, color: Colors.white),
                      onPressed: () {
                        // Handle Apple Sign-In
                      },
                    ),
                    const SizedBox(height: 16),

                    // Forgot Password & Sign Up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?",
                            style: TextStyle(color: Colors.grey[700])),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SignUpPage()),
                          ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: AppColors.darkBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
