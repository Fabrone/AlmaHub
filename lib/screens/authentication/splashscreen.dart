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
              Color.fromARGB(255, 66, 10, 113),
              Color.fromARGB(255, 132, 69, 161),
              Color.fromARGB(255, 95, 24, 150),
              Color.fromARGB(255, 66, 10, 113),
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
                  
                  // Calculate responsive sizes based on screen dimensions
                  final isSmallScreen = availableWidth < 360;
                  final isMediumScreen = availableWidth >= 360 && availableWidth < 600;
                  final isLargeScreen = availableWidth >= 600;
                  
                  // Adaptive sizing
                  final logoSize = isSmallScreen 
                      ? 50.0 
                      : isMediumScreen 
                          ? 60.0 
                          : 70.0;
                  
                  final titleFontSize = isSmallScreen 
                      ? 32.0 
                      : isMediumScreen 
                          ? 40.0 
                          : 48.0;
                  
                  final subtitleFontSize = isSmallScreen 
                      ? 13.0 
                      : isMediumScreen 
                          ? 15.0 
                          : 16.0;
                  
                  final taglineFontSize = isSmallScreen 
                      ? 11.0 
                      : isMediumScreen 
                          ? 12.0 
                          : 13.0;
                  
                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: availableHeight,
                          maxWidth: isLargeScreen ? 600 : availableWidth,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: availableWidth * 0.08,
                            vertical: availableHeight * 0.05,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: availableHeight * 0.1),
                              
                              // Animated logo with improved design
                              ScaleTransition(
                                scale: _logoAnimation,
                                child: Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: Colors.purple.withValues(alpha: 0.3),
                                        blurRadius: 40,
                                        spreadRadius: -5,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.business_center,
                                      size: logoSize,
                                      color: const Color.fromARGB(255, 66, 10, 113),
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: availableHeight * 0.05),
                              
                              // Animated company name
                              FadeTransition(
                                opacity: _textFadeAnimation,
                                child: SlideTransition(
                                  position: _textSlideAnimation,
                                  child: Column(
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0xFFE1BEE7),
                                            Colors.white,
                                          ],
                                          stops: [0.0, 0.5, 1.0],
                                        ).createShader(bounds),
                                        child: Text(
                                          'JV Almacis',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: titleFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 2,
                                            height: 1.2,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black26,
                                                offset: Offset(0, 3),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(height: availableHeight * 0.025),
                                      
                                      // Subtitle badge
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 16 : 20,
                                          vertical: isSmallScreen ? 8 : 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(25),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'Employee Onboarding System',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: subtitleFontSize,
                                            color: Colors.white.withValues(alpha: 0.95),
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w400,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(height: availableHeight * 0.015),
                                      
                                      // Tagline
                                      Text(
                                        'Italian Excellence, Global Reach',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: taglineFontSize,
                                          color: Colors.white.withValues(alpha: 0.75),
                                          letterSpacing: 0.8,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: availableHeight * 0.12),
                              
                              // Animated loading indicator
                              FadeTransition(
                                opacity: _textFadeAnimation,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: isSmallScreen ? 40 : 45,
                                      height: isSmallScreen ? 40 : 45,
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
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: taglineFontSize,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: availableHeight * 0.1),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
        // Top right circle
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
                    Colors.white.withValues(alpha: 0.08),
                    Colors.purple.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // Bottom left circle
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
                    Colors.white.withValues(alpha: 0.06),
                    Colors.purple.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        
        // Middle left circle
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
                  Colors.white.withValues(alpha: 0.04),
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