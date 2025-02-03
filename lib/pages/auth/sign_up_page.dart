import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:resq/constants/constants.dart';
import 'package:resq/pages/auth/login_page.dart';
import 'package:resq/widget/social_login_button.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Fade-in animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Slide-up animation
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start the animations
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the controller to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Sign Up"),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w700,
            ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: FadeTransition(
          opacity: _fadeAnimation, // Apply fade animation
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: SlideTransition(
              position: _slideAnimation, // Apply slide animation
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Create Your Account",
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Full Name Field
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Full name",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Email",
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
                      hintText: "Password",
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
                  const SizedBox(height: 16),

                  // Confirm Password Field with Visibility Toggle
                  TextField(
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "Re-enter password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
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

                  // Sign-Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle sign-up logic
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                  const SizedBox(height: 20),

                  // Google Sign-Up Button
                  SocialLoginButton(
                    iconWidget: const FaIcon(FontAwesomeIcons.google,
                        color: Colors.black),
                    label: "Sign Up with Google",
                    textColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    borderColor: AppColors.darkBlue,
                    borderRadius: 12.0,
                    paddingVertical: 14.0,
                    textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    onPressed: () {
                      // Handle Google Sign-Up
                    },
                  ),
                  const SizedBox(height: 12),

                  // Apple Sign-Up Button
                  SocialLoginButton(
                    iconWidget: const FaIcon(FontAwesomeIcons.apple,
                        color: Colors.white),
                    label: "Sign Up with Apple",
                    textColor: Colors.white,
                    backgroundColor: Colors.black,
                    borderColor: Colors.black,
                    borderRadius: 12.0,
                    paddingVertical: 14.0,
                    textStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w700, color: Colors.white),
                    onPressed: () {
                      // Handle Apple Sign-Up
                    },
                  ),
                  const SizedBox(height: 16),

                  // Already have an account? Sign In
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?",
                          style: TextStyle(color: Colors.grey[700])),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        ),
                        child: const Text(
                          "Sign In",
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
    );
  }
}
