import 'package:almahub/screens/role_selection_screen.dart';
import 'package:almahub/screens/welcome_screen.dart';
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
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        }
      } else {
        // No user logged in
        _logger.i('No user logged in, navigating to LoginScreen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
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
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    } on FirebaseException catch (e) {
      _logger.e('FirebaseException during Firestore query', error: e, stackTrace: e.stackTrace);
      _logger.e('Error code: ${e.code}, Message: ${e.message}');
      
      if (mounted) {
        _logger.i('Navigating to LoginScreen due to FirebaseException');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during auth check', error: e, stackTrace: stackTrace);
      
      // On error, navigate to login screen
      if (mounted) {
        _logger.i('Navigating to LoginScreen due to unexpected error');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background decoration
            _buildBackgroundDecoration(),
            
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
                            
                            // Animated logo with modern design
                            ScaleTransition(
                              scale: _logoAnimation,
                              child: Container(
                                width: isSmallScreen ? 120 : (isMediumScreen ? 140 : 160),
                                height: isSmallScreen ? 120 : (isMediumScreen ? 140 : 160),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF7B2CBF),
                                      Color(0xFF5A189A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.business_center,
                                  size: logoSize,
                                  color: Colors.white,
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
                                    Text(
                                      'JV Almacis',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1A1A2E),
                                        letterSpacing: -0.5,
                                        height: 1.2,
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
                                        color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF7B2CBF).withValues(alpha: 0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Employee Onboarding System',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: subtitleFontSize,
                                          color: const Color(0xFF7B2CBF),
                                          letterSpacing: 0.3,
                                          fontWeight: FontWeight.w600,
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
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 0.5,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w400,
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
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF7B2CBF),
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
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        // Top right accent
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7B2CBF).withValues(alpha: 0.05),
                  const Color(0xFF7B2CBF).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        
        // Bottom left accent
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF7B2CBF).withValues(alpha: 0.04),
                  const Color(0xFF7B2CBF).withValues(alpha: 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}