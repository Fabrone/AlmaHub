import 'package:almahub/screens/authentication/registration_screen.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Initialize logger with same configuration as registration screen
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
    _logger.i('LoginScreen initialized');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _logger.d('Animation controller initialized and started');
  }

  /// Convert username with underscores back to original format if needed
  String _formatUsernameForDisplay(String username) {
    final formatted = username.replaceAll('_', ' ');
    _logger.d('Formatted username for display: "$username" -> "$formatted"');
    return formatted;
  }

  /// Search for user data in both Draft and EmployeeDetails collections
  Future<Map<String, dynamic>?> _findUserDataByEmail(
      String email, String uid) async {
    _logger.i('Starting user data search for email: $email, uid: $uid');

    try {
      // First, check Draft collection
      _logger.d('Searching Draft collection for user with email: $email');
      final draftQuery = await FirebaseFirestore.instance
          .collection('Draft')
          .where('personalInfo.email', isEqualTo: email)
          .limit(1)
          .get();

      if (draftQuery.docs.isNotEmpty) {
        final draftDoc = draftQuery.docs.first;
        final draftData = draftDoc.data();
        final docId = draftDoc.id;

        _logger.i('✅ User found in Draft collection');
        _logger.d('Draft document ID: $docId');
        _logger.d('Draft document status: ${draftData['status']}');
        _logger.d('Draft document UID: ${draftData['uid']}');

        // Verify UID matches
        if (draftData['uid'] == uid) {
          _logger.i('UID verification successful in Draft collection');
          return {
            'collection': 'Draft',
            'documentId': docId,
            'data': draftData,
            'username': draftData['registrationUsername'] ?? docId,
            'status': draftData['status'],
          };
        } else {
          _logger.w(
              'UID mismatch in Draft collection. Expected: $uid, Found: ${draftData['uid']}');
        }
      } else {
        _logger.d('No user found in Draft collection with email: $email');
      }

      // Second, check EmployeeDetails collection
      _logger.d('Searching EmployeeDetails collection for user with email: $email');
      final employeeQuery = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .where('personalInfo.email', isEqualTo: email)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        final employeeDoc = employeeQuery.docs.first;
        final employeeData = employeeDoc.data();
        final docId = employeeDoc.id;

        _logger.i('✅ User found in EmployeeDetails collection');
        _logger.d('EmployeeDetails document ID: $docId');
        _logger.d('EmployeeDetails document status: ${employeeData['status']}');
        _logger.d('EmployeeDetails document UID: ${employeeData['uid']}');

        // Verify UID matches
        if (employeeData['uid'] == uid) {
          _logger.i('UID verification successful in EmployeeDetails collection');
          return {
            'collection': 'EmployeeDetails',
            'documentId': docId,
            'data': employeeData,
            'username': employeeData['registrationUsername'] ?? docId,
            'status': employeeData['status'],
          };
        } else {
          _logger.w(
              'UID mismatch in EmployeeDetails collection. Expected: $uid, Found: ${employeeData['uid']}');
        }
      } else {
        _logger.d('No user found in EmployeeDetails collection with email: $email');
      }

      // Also check by registrationEmail field as fallback
      _logger.d('Searching Draft collection by registrationEmail field');
      final draftEmailQuery = await FirebaseFirestore.instance
          .collection('Draft')
          .where('registrationEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (draftEmailQuery.docs.isNotEmpty) {
        final draftDoc = draftEmailQuery.docs.first;
        final draftData = draftDoc.data();
        final docId = draftDoc.id;

        _logger.i('✅ User found in Draft collection via registrationEmail');
        _logger.d('Draft document ID: $docId');

        if (draftData['uid'] == uid) {
          _logger.i('UID verification successful via registrationEmail in Draft');
          return {
            'collection': 'Draft',
            'documentId': docId,
            'data': draftData,
            'username': draftData['registrationUsername'] ?? docId,
            'status': draftData['status'],
          };
        }
      }

      _logger.d('Searching EmployeeDetails collection by registrationEmail field');
      final employeeEmailQuery = await FirebaseFirestore.instance
          .collection('EmployeeDetails')
          .where('registrationEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (employeeEmailQuery.docs.isNotEmpty) {
        final employeeDoc = employeeEmailQuery.docs.first;
        final employeeData = employeeDoc.data();
        final docId = employeeDoc.id;

        _logger.i('✅ User found in EmployeeDetails collection via registrationEmail');
        _logger.d('EmployeeDetails document ID: $docId');

        if (employeeData['uid'] == uid) {
          _logger.i('UID verification successful via registrationEmail in EmployeeDetails');
          return {
            'collection': 'EmployeeDetails',
            'documentId': docId,
            'data': employeeData,
            'username': employeeData['registrationUsername'] ?? docId,
            'status': employeeData['status'],
          };
        }
      }

      _logger.e('❌ User not found in any collection (Draft or EmployeeDetails)');
      _logger.e('Searched email: $email');
      _logger.e('Searched uid: $uid');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error searching for user data', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _handleLogin() async {
    _logger.i('Login process initiated');

    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }
    _logger.d('Form validation passed');

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    _logger.i('Login attempt for email: $email');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Authenticate with Firebase Auth
      _logger.d('Attempting Firebase Authentication');
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        _logger.e('User credential returned null user');
        throw Exception('User not found after login');
      }

      _logger.i('✅ Firebase Authentication successful');
      _logger.d('User UID: ${user.uid}');
      _logger.d('User email: ${user.email}');
      _logger.d('Email verified: ${user.emailVerified}');

      // Step 2: Find user data in Draft or EmployeeDetails collections
      _logger.i('Searching for user data in Firestore collections');
      final userData = await _findUserDataByEmail(email, user.uid);

      if (userData == null) {
        _logger.e('❌ User data not found in any collection');
        _logger.e('This user has authenticated but has no associated document');
        throw Exception(
            'User profile not found. Please contact support or re-register.');
      }

      // Step 3: Extract user information
      final collection = userData['collection'] as String;
      final documentId = userData['documentId'] as String;
      final username = userData['username'] as String;
      final status = userData['status'] as String?;

      _logger.i('✅ User data retrieved successfully');
      _logger.i('Collection: $collection');
      _logger.i('Document ID: $documentId');
      _logger.i('Username: $username');
      _logger.i('Status: $status');

      // Step 4: Navigate to appropriate screen
      if (mounted) {
        _logger.i('Preparing to navigate to RoleSelectionScreen');

        // Show welcome message
        final displayUsername = _formatUsernameForDisplay(username);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, $displayUsername!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );

        _logger.d('Displayed welcome message for: $displayUsername');
        _logger.d('Login status: ${status ?? "unknown"}');

        // Navigate to role selection
        _logger.i('Navigating to RoleSelectionScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RoleSelectionScreen(),
          ),
        );

        _logger.i('✅ Login process completed successfully');
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('Firebase Authentication error', error: e, stackTrace: stackTrace);
      _logger.e('Error code: ${e.code}');
      _logger.e('Error message: ${e.message}');

      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _logger.w('Authentication failed: User not found');
            _errorMessage = 'No account found with this email address.';
            break;
          case 'wrong-password':
            _logger.w('Authentication failed: Wrong password');
            _errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'invalid-email':
            _logger.w('Authentication failed: Invalid email format');
            _errorMessage = 'Invalid email address format.';
            break;
          case 'user-disabled':
            _logger.w('Authentication failed: User account disabled');
            _errorMessage = 'This account has been disabled.';
            break;
          case 'invalid-credential':
            _logger.w('Authentication failed: Invalid credentials');
            _errorMessage = 'Invalid email or password.';
            break;
          case 'too-many-requests':
            _logger.w('Authentication failed: Too many requests');
            _errorMessage = 'Too many failed attempts. Try again later.';
            break;
          default:
            _logger.e('Authentication failed: Unknown error (${e.code})');
            _errorMessage = 'Login failed: ${e.message ?? "Unknown error"}';
        }
      });
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during login', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = e.toString().contains('User profile not found')
            ? e.toString().replaceAll('Exception: ', '')
            : 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _logger.d('Login loading state cleared');
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    _logger.i('Forgot password process initiated');

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _logger.w('Forgot password failed: Email field is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _logger.w('Forgot password failed: Invalid email format - $email');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _logger.d('Valid email format confirmed: $email');

    try {
      _logger.i('Sending password reset email to: $email');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _logger.i('✅ Password reset email sent successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _logger.d('Password reset confirmation shown to user');
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      _logger.e('Password reset failed', error: e, stackTrace: stackTrace);
      _logger.e('Error code: ${e.code}');

      String message;
      switch (e.code) {
        case 'user-not-found':
          _logger.w('Password reset failed: User not found');
          message = 'No account found with this email.';
          break;
        case 'invalid-email':
          _logger.w('Password reset failed: Invalid email');
          message = 'Invalid email format.';
          break;
        default:
          _logger.e('Password reset failed: ${e.code}');
          message = 'Failed to send reset email.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during password reset', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _logger.d('LoginScreen disposing');
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _logger.d('Controllers disposed successfully');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 71, 5, 101),
              Color.fromARGB(255, 62, 6, 93),
              Color.fromARGB(255, 113, 13, 147),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      color: Colors.white.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Icon(
                                Icons.admin_panel_settings_rounded,
                                size: 80,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(height: 16),

                              // Title
                              const Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Subtitle
                              Text(
                                'Sign in to continue',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Email',
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
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
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
                                  hintText: 'Enter your password',
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
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _handleForgotPassword,
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

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

                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1A237E),
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
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Sign up link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _logger.i('Navigating to RegistrationScreen');
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegistrationScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Sign Up',
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
      ),
    );
  }
}