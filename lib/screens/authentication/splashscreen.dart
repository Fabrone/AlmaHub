import 'package:almahub/screens/authentication/login_screen.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _progressAnimation;
  
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
    _logger.i('SplashScreen initialized');
    _initializeAnimations();
    _checkAuthStatus();
  }

  void _initializeAnimations() {
    _logger.d('Initializing animations');
    
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // Progress indicator controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
        _logger.d('Text animation started');
      }
    });
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _progressController.repeat();
        _logger.d('Progress animation started');
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    _logger.i('Starting authentication status check');
    
    // Extended wait for animations to play - increased from 3 to 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) {
      _logger.w('Widget not mounted, aborting auth check');
      return;
    }

    try {
      _logger.d('Checking current user authentication state');
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _logger.i('User is logged in: ${user.uid}');
        
        // Check in Draft collection first (for new/in-progress registrations)
        _logger.d('Checking Draft collection for user with uid: ${user.uid}');
        final draftQuery = await FirebaseFirestore.instance
            .collection('Draft')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (draftQuery.docs.isNotEmpty) {
          final draftData = draftQuery.docs.first.data();
          final username = draftData['personalInfo']?['fullName'] ?? draftQuery.docs.first.id;
          _logger.i('User found in Draft collection: $username');
          
          if (mounted) {
            _logger.i('Navigating to RoleSelectionScreen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
            );
          }
          return;
        }
        _logger.d('User not found in Draft collection, checking EmployeeDetails');

        // Check in EmployeeDetails collection (for completed profiles)
        final employeeQuery = await FirebaseFirestore.instance
            .collection('EmployeeDetails')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (employeeQuery.docs.isNotEmpty) {
          final employeeData = employeeQuery.docs.first.data();
          final username = employeeData['personalInfo']?['fullName'] ?? employeeQuery.docs.first.id;
          _logger.i('User found in EmployeeDetails collection: $username');
          
          if (mounted) {
            _logger.i('Navigating to RoleSelectionScreen');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
            );
          }
          return;
        }
        
        // User logged in but no data found in either collection
        _logger.w('User authenticated but no document found in Draft or EmployeeDetails. Signing out.');
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          _logger.i('Navigating to LoginScreen after signout');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        // No user logged in
        _logger.i('No user logged in, navigating to LoginScreen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during auth check', error: e, stackTrace: e.stackTrace);
      _logger.e('Error code: ${e.code}, Message: ${e.message}');
      
      // On error, navigate to login screen
      if (mounted) {
        _logger.i('Navigating to LoginScreen due to FirebaseAuthException');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } on FirebaseException catch (e) {
      _logger.e('FirebaseException during Firestore query', error: e, stackTrace: e.stackTrace);
      _logger.e('Error code: ${e.code}, Message: ${e.message}');
      
      if (mounted) {
        _logger.i('Navigating to LoginScreen due to FirebaseException');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during auth check', error: e, stackTrace: stackTrace);
      
      // On error, navigate to login screen
      if (mounted) {
        _logger.i('Navigating to LoginScreen due to unexpected error');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing SplashScreen controllers');
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    _logger.d('Building SplashScreen - Height: $screenHeight, Width: $screenWidth');
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 112, 28, 164), // Darkest purple
              Color.fromARGB(255, 95, 24, 150),
              Color.fromARGB(255, 107, 14, 160),
              Color.fromARGB(255, 117, 20, 166),
            ],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated background elements
              _buildBackgroundCircles(),
              
              // Main content - using LayoutBuilder for responsive design
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final availableWidth = constraints.maxWidth;
                  
                  // Calculate responsive sizes
                  final logoSize = (availableWidth * 0.2).clamp(60.0, 100.0);
                  final titleFontSize = (availableWidth * 0.12).clamp(32.0, 56.0);
                  final subtitleFontSize = (availableWidth * 0.04).clamp(14.0, 18.0);
                  
                  return Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: availableHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(flex: 2),
                              
                              // Animated logo
                              ScaleTransition(
                                scale: _logoAnimation,
                                child: Container(
                                  padding: EdgeInsets.all(availableWidth * 0.06),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(availableWidth * 0.05),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.business_center_rounded,
                                      size: logoSize,
                                      color: const Color.fromARGB(255, 112, 28, 164),
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: availableHeight * 0.06),
                              
                              // Animated company name
                              FadeTransition(
                                opacity: _textFadeAnimation,
                                child: SlideTransition(
                                  position: _textSlideAnimation,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: availableWidth * 0.05),
                                    child: Column(
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [Colors.white, Color(0xFFE1BEE7)],
                                          ).createShader(bounds),
                                          child: Text(
                                            'JV Almacis',
                                            style: TextStyle(
                                              fontSize: titleFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 3,
                                              shadows: const [
                                                Shadow(
                                                  color: Colors.black26,
                                                  offset: Offset(0, 4),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: availableHeight * 0.02),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: availableWidth * 0.05,
                                            vertical: availableHeight * 0.01,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Employee Onboarding System',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              color: Colors.white.withValues(alpha: 0.95),
                                              letterSpacing: 1.5,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: availableHeight * 0.01),
                                        Text(
                                          'Italian Excellence, Global Reach',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: subtitleFontSize * 0.78,
                                            color: Colors.white.withValues(alpha: 0.7),
                                            letterSpacing: 1,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              const Spacer(flex: 2),
                              
                              // Animated loading indicator
                              FadeTransition(
                                opacity: _textFadeAnimation,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white.withValues(alpha: 0.9),
                                        ),
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    SizedBox(height: availableHeight * 0.025),
                                    Text(
                                      'Loading your workspace...',
                                      style: TextStyle(
                                        fontSize: subtitleFontSize * 0.78,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: availableHeight * 0.08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Version text at bottom
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Center(
                    child: Text(
                      'v1.0.0 © 2026 JV Almacis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundCircles() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: RotationTransition(
            turns: _progressAnimation,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -150,
          child: RotationTransition(
            turns: Tween<double>(begin: 1.0, end: 0.0).animate(_progressController),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}