import 'package:almahub/screens/authentication/login_screen.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Initialize logger
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void initState() {
    super.initState();
    _logger.i('RegistrationScreen initialized');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward();
    _logger.d('Animation controller initialized and started');
  }

  Future<void> _signUp() async {
    _logger.i('Sign up process initiated');

    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }
    _logger.d('Form validation passed');

    if (_passwordController.text != _confirmPasswordController.text) {
      _logger.w('Password mismatch detected');
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    _logger.d('Password confirmation matched');

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _logger.w('Username is empty after trimming');
      setState(() => _errorMessage = 'Username is required');
      return;
    }
    _logger.d('Username validated: $username');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _logger.i('Registration process starting for username: $username');

    try {
      // Check if username already exists
      _logger.d('Checking if username exists in Firestore: $username');
      final existingDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(username)
          .get();

      if (existingDoc.exists) {
        _logger.w('Username already exists: $username');
        throw Exception('Username already taken');
      }
      _logger.d('Username is available: $username');

      // Create user with email and password
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      _logger.i('Creating Firebase Auth user with email: $email');

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      _logger.i('Firebase Auth user created successfully');

      final user = userCredential.user;
      if (user == null) {
        _logger.e('User credential returned null user');
        throw Exception('User creation failed');
      }
      _logger.d('User UID obtained: ${user.uid}');

      // Create document in 'Users' with ID = username
      final userData = {
        'Username': username,
        'email': email,
        'uid': user.uid,
        'role': 'Client',
        'createdAt': FieldValue.serverTimestamp(),
      };
      _logger.d('Creating Firestore document with data: $userData');

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(username)
          .set(userData);
      _logger.i('Firestore document created successfully for: $username');

      if (mounted) {
        _logger.i(
          'Showing success message and navigating to RoleSelectionScreen',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to JV Almacis, $username!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
        _logger.i('Navigation to RoleSelectionScreen completed');
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e(
        'FirebaseAuthException during registration',
        error: e,
        stackTrace: stackTrace,
      );
      _logger.e('Error code: ${e.code}, Message: ${e.message}');

      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'This email is already registered. Please login.';
            _logger.w('Email already in use: ${_emailController.text.trim()}');
            break;
          case 'invalid-email':
            _errorMessage = 'Invalid email address format.';
            _logger.w('Invalid email format: ${_emailController.text.trim()}');
            break;
          case 'weak-password':
            _errorMessage = 'Password is too weak. Use at least 6 characters.';
            _logger.w('Weak password detected');
            break;
          case 'operation-not-allowed':
            _errorMessage = 'Registration is currently disabled.';
            _logger.e('Email/password registration is not enabled in Firebase');
            break;
          default:
            _errorMessage =
                'Registration failed: ${e.message ?? "Unknown error"}';
            _logger.e('Unknown FirebaseAuthException: ${e.code}');
        }
      });
    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        'FirebaseException during Firestore operation',
        error: e,
        stackTrace: stackTrace,
      );
      _logger.e('Error code: ${e.code}, Message: ${e.message}');

      setState(() {
        _errorMessage = 'Failed to save user data. Please try again.';
      });
    } catch (e, stackTrace) {
      _logger.e(
        'Unexpected error during registration',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        if (e.toString().contains('Username already taken')) {
          _errorMessage = 'This username is already taken.';
          _logger.w('Username taken: ${_usernameController.text.trim()}');
        } else {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _logger.e('Unknown error type: ${e.runtimeType}');
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _logger.d('Registration process completed, loading state reset');
      }
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing RegistrationScreen controllers');
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth = screenWidth > 800
        ? screenWidth * 0.5
        : screenWidth * 0.9;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white38,
          selectionHandleColor: Colors.white,
        ),
      ),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 72, 7, 118),
                Color.fromARGB(255, 135, 98, 195),
                Color.fromARGB(255, 72, 7, 118),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo/Icon
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 60,
                                color: Color.fromARGB(255, 57, 5, 95),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Title
                            const Text(
                              'Join AlmaHub by JV Almacis',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Create your account to get started',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Username field
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                hintText: 'Choose a unique username',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.account_circle_outlined,
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                if (value.trim().length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                if (!RegExp(
                                  r'^[a-zA-Z0-9_]+$',
                                ).hasMatch(value.trim())) {
                                  return 'Only letters, numbers, and underscores allowed';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+',
                                ).hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                hintText: 'Create a strong password',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outlined,
                                  color: Colors.white70,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Confirm Password field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                labelStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                hintText: 'Re-enter your password',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outlined,
                                  color: Colors.white70,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white38,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.1),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Error message
                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Sign up button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color.fromARGB(
                                    255,
                                    23,
                                    3,
                                    46,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black45,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF1A237E),
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Login link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 15,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _logger.i('Navigating to LoginScreen');
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
            ),
          ),
        ),
      ),
    );
  }
}
