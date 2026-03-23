import 'package:almahub/screens/authentication/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recruitment_status_screen.dart';

class RecruitmentPortalScreen extends StatefulWidget {
  const RecruitmentPortalScreen({super.key});

  @override
  State<RecruitmentPortalScreen> createState() =>
      _RecruitmentPortalScreenState();
}

class _RecruitmentPortalScreenState extends State<RecruitmentPortalScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _areaOfExpertiseController = TextEditingController();

  bool _isSubmitting = false;
  bool _isUploadingFile = false;
  bool _isCheckingExisting = false;
  bool _isCheckingRegistered = false;
  String? _cvFileName;
  PlatformFile? _selectedCvFile;
  String? _errorMessage;

  /// Whether the currently logged-in Firebase Auth user's email is pre-filled
  bool _emailPrefilledFromAuth = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
    _logger.i('RecruitmentPortalScreen initialized');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();

    _prefillFromAuthUser();
    _checkForExistingSubmission();
  }

  /// If a Firebase Auth user is signed in (but is NOT a registered employee —
  /// they landed on WelcomeScreen which means they have no Users doc), their
  /// email is pre-filled and locked in the email field.
  void _prefillFromAuthUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null && user.email!.isNotEmpty) {
      _emailController.text = user.email!;
      _emailPrefilledFromAuth = true;
      _logger.i('Email pre-filled from signed-in user: ${user.email}');
    }
  }

  Future<void> _checkForExistingSubmission() async {
    _logger.i('Checking for existing submission from this device');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('recruitment_email');

      if (savedEmail != null && savedEmail.isNotEmpty) {
        _logger.i('Found saved email: $savedEmail — checking Firestore');
        final sanitizedEmail = _sanitizeEmail(savedEmail);
        final doc = await FirebaseFirestore.instance
            .collection('Recruitees')
            .doc(sanitizedEmail)
            .get();

        if (doc.exists) {
          _logger.i('Existing application found — redirecting to status screen');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RecruitmentStatusScreen(
                  recruiteeEmail: savedEmail,
                  sanitizedEmail: sanitizedEmail,
                ),
              ),
            );
          }
        } else {
          await prefs.remove('recruitment_email');
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking existing submission',
          error: e, stackTrace: stackTrace);
    }
  }

  String _sanitizeEmail(String email) {
    return email.replaceAll('.', '_').replaceAll('@', '_at_');
  }

  @override
  void dispose() {
    _logger.d('RecruitmentPortalScreen disposing');
    _fullNameController.dispose();
    _emailController.dispose();
    _areaOfExpertiseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── File helpers ──────────────────────────────────────────────────────────

  bool _validateFileSize(PlatformFile file) {
    const maxSize = 10 * 1024 * 1024;
    final fileSizeMB = file.size / (1024 * 1024);
    if (file.size > maxSize) {
      setState(() {
        _errorMessage =
            'File too large. Maximum size is 10 MB. Your file is ${fileSizeMB.toStringAsFixed(1)} MB';
      });
      return false;
    }
    return true;
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _selectCvFile() async {
    _logger.i('CV file selection initiated');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (!_validateFileSize(file)) return;
        setState(() {
          _selectedCvFile = file;
          _cvFileName = file.name;
          _errorMessage = null;
        });
        _logger.i('CV file set: $_cvFileName');
      } else {
        _logger.d('File selection cancelled');
      }
    } catch (e, stackTrace) {
      _logger.e('Error selecting file', error: e, stackTrace: stackTrace);
      setState(() => _errorMessage = 'Error selecting file. Please try again.');
    }
  }

  Future<String?> _uploadCvToStorage(
      PlatformFile file, String fullName, String email) async {
    _logger.i('=== STARTING CV UPLOAD ===');
    try {
      setState(() => _isUploadingFile = true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = fullName.replaceAll(' ', '_').toLowerCase();
      final fileExtension = file.extension ?? 'pdf';
      final fileName = '${sanitizedName}_$timestamp.$fileExtension';
      final contentType = _getContentType(fileExtension);

      final storageRef =
          FirebaseStorage.instance.ref().child('Recruitees/$fileName');

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': email,
          'uploaderName': fullName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': file.name,
        },
      );

      final uploadTask = await storageRef.putData(file.bytes!, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      _logger.i('✅ CV UPLOADED SUCCESSFULLY');
      return downloadUrl;
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('Firebase upload error', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage =
            'Upload failed: ${e.message}\nError code: ${e.code}';
      });
      return null;
    } catch (e, stackTrace) {
      _logger.e('Unexpected upload error', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to upload CV. Please try again.';
      });
      return null;
    } finally {
      setState(() => _isUploadingFile = false);
    }
  }

  // ── Email registration check ──────────────────────────────────────────────

  /// Returns true if the email is found in Firebase Auth (fetchSignInMethodsForEmail)
  /// OR as the `email` field in any document in the Users collection.
  ///
  /// fetchSignInMethodsForEmail is a supported client-side Firebase Auth call
  /// that returns the sign-in methods registered for an email without needing
  /// admin SDK access. An empty list means the email is NOT registered; a
  /// non-empty list means it IS registered.
  Future<bool> _isEmailRegistered(String email) async {
    _logger.i('Checking if email is registered: $email');

    // ── 1. Firebase Authentication check ─────────────────────────────────
    /*try {
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        _logger.w('Email found in Firebase Auth with methods: $methods');
        return true;
      }
      _logger.d('Email not found in Firebase Auth');
    } on FirebaseAuthException catch (e) {
      // invalid-email or other errors — treat as not registered so we don't
      // block a legitimate new applicant due to a transient error.
      _logger.w('fetchSignInMethodsForEmail error: ${e.code} — treating as unregistered');
    }*/

    // ── 2. Users collection check (email field in documents) ─────────────
    try {
      final usersQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        _logger.w('Email found in Users collection doc: ${usersQuery.docs.first.id}');
        return true;
      }
      _logger.d('Email not found in Users collection');
    } catch (e) {
      _logger.w('Error querying Users collection: $e — treating as unregistered');
    }

    return false;
  }

  Future<bool> _checkExistingApplication(String email) async {
    _logger.i('Checking if Recruitees application exists for: $email');
    setState(() => _isCheckingExisting = true);

    try {
      final sanitizedEmail = _sanitizeEmail(email);
      final doc = await FirebaseFirestore.instance
          .collection('Recruitees')
          .doc(sanitizedEmail)
          .get();

      if (doc.exists) {
        _logger.w('Existing application found for $email');
        final data = doc.data();
        final status = data?['status'] as String? ?? 'unknown';
        final fullName = data?['fullName'] as String? ?? 'applicant';

        if (mounted) {
          await _showExistingApplicationDialog(fullName, status, sanitizedEmail);
        }
        return true;
      }

      _logger.i('No existing application — can proceed');
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error checking existing application',
          error: e, stackTrace: stackTrace);
      return false;
    } finally {
      setState(() => _isCheckingExisting = false);
    }
  }

  Future<void> _showExistingApplicationDialog(
      String fullName, String status, String sanitizedEmail) async {
    final statusMessages = {
      'pending': 'Your application is awaiting review',
      'under_review': 'Your application is currently being reviewed',
      'shortlisted': 'Congratulations! You\'ve been shortlisted',
      'not_shortlisted': 'Your application was not shortlisted for this round',
      'accepted': 'Congratulations! Your application was accepted',
      'rejected': 'Your previous application was not selected',
    };
    final message =
        statusMessages[status] ?? 'You already have an application on file';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF7B2CBF), size: 28),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Application Already Submitted',
                    style: TextStyle(fontSize: 20))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi $fullName,',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            const Text(
              'We found an existing application submitted with this email address.',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF7B2CBF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF7B2CBF), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(message,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Would you like to check your application status?',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => RecruitmentStatusScreen(
                    recruiteeEmail: _emailController.text.trim(),
                    sanitizedEmail: sanitizedEmail,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Status'),
          ),
        ],
      ),
    );
  }

  /// Show a dialog informing the user their email is registered in the system
  /// and they must log in before submitting a recruitment application.
  Future<void> _showRegisteredEmailDialog(String email) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF7B2CBF), size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Account Detected',
                  style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF475569), height: 1.5),
                children: [
                  const TextSpan(text: 'The email address '),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E)),
                  ),
                  const TextSpan(
                    text:
                        ' is already registered in our system.\n\nFor the authenticity and confidentiality of your application, please sign in with this account before submitting.',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Stop the current submission and redirect to Login
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B2CBF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submission ────────────────────────────────────────────────────────────

  Future<void> _submitApplication() async {
    _logger.i('=== APPLICATION SUBMISSION INITIATED ===');

    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }

    if (_selectedCvFile == null) {
      setState(() => _errorMessage = 'Please upload your CV before submitting');
      return;
    }

    final email = _emailController.text.trim();
    final fullName = _fullNameController.text.trim();
    final areaOfExpertise = _areaOfExpertiseController.text.trim();

    // ── Step A: Check if email belongs to a registered account ────────────
    setState(() => _isCheckingRegistered = true);
    bool registered = false;
    try {
      registered = await _isEmailRegistered(email);
    } finally {
      setState(() => _isCheckingRegistered = false);
    }

    if (registered) {
      _logger.w('Email $email is registered — blocking submission, showing login prompt');
      if (mounted) await _showRegisteredEmailDialog(email);
      return; // Stop submission — user must log in first
    }

    // ── Step B: Check for duplicate Recruitees application ────────────────
    final exists = await _checkExistingApplication(email);
    if (exists) {
      _logger.i('Existing Recruitees application found — stopping submission');
      return;
    }

    // ── Step C: Upload CV & save to Firestore ─────────────────────────────
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    _logger.i('Submitting application for: $fullName ($email)');

    try {
      final cvUrl =
          await _uploadCvToStorage(_selectedCvFile!, fullName, email);
      if (cvUrl == null) {
        _logger.e('CV upload failed — aborting');
        return;
      }

      final sanitizedEmail = _sanitizeEmail(email);

      final recruiteeData = {
        'fullName': fullName,
        'email': email,
        'areaOfExpertise': areaOfExpertise,
        'cvUrl': cvUrl,
        'cvFileName': _cvFileName,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'reviewedAt': null,
        'reviewNotes': null,
      };

      await FirebaseFirestore.instance
          .collection('Recruitees')
          .doc(sanitizedEmail)
          .set(recruiteeData, SetOptions(merge: false));

      _logger.i('✅ APPLICATION SUBMITTED SUCCESSFULLY');

      // Save email locally to prevent re-submission
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recruitment_email', email);

      if (mounted) {
        _logger.i('Navigating to RecruitmentStatusScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RecruitmentStatusScreen(
              recruiteeEmail: email,
              sanitizedEmail: sanitizedEmail,
            ),
          ),
        );
      }
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('Firebase error during submission',
          error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage =
            'Failed to submit application. Please try again.\nError: ${e.message}';
      });
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during submission',
          error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage =
            'An unexpected error occurred. Please try again.\nError: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20.0 : 40.0,
                        vertical: 24.0,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInfoCard(),
                              const SizedBox(height: 32),

                              // Full Name
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Full name is required';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Email
                              _buildEmailField(),

                              const SizedBox(height: 20),

                              // Area of Expertise (new field)
                              _buildTextField(
                                controller: _areaOfExpertiseController,
                                label: 'Area of Expertise',
                                hint:
                                    'e.g. Civil Engineering, Project Management',
                                icon: Icons.workspace_premium_outlined,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Please enter your area of expertise';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'Please provide a meaningful description';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // CV Upload
                              _buildCvUploadSection(),

                              const SizedBox(height: 24),

                              if (_errorMessage != null) ...[
                                _buildErrorMessage(),
                                const SizedBox(height: 20),
                              ],

                              _buildSubmitButton(isSmallScreen),

                              const SizedBox(height: 24),

                              _buildPrivacyNote(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join Our Team',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E))),
                SizedBox(height: 2),
                Text('Submit your application',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2CBF), Color(0xFF5A189A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B2CBF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.work_outline, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Start Your Career Journey',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Fill in your details and upload your CV. One application per email address.',
            style: TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Standard text field used for Full Name and Area of Expertise.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon:
                Icon(icon, color: const Color(0xFF64748B), size: 20),
            filled: true,
            fillColor:
                readOnly ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF7B2CBF), width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  /// Special email field: read-only when pre-filled from auth user.
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Email Address',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155))),
            if (_emailPrefilledFromAuth) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Auto-detected',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7B2CBF),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          // Lock the field if the email was pulled from an active auth session
          readOnly: _emailPrefilledFromAuth,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 15),
          decoration: InputDecoration(
            hintText: 'you@example.com',
            hintStyle:
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            prefixIcon: const Icon(Icons.email_outlined,
                color: Color(0xFF64748B), size: 20),
            suffixIcon: _emailPrefilledFromAuth
                ? const Icon(Icons.lock_outline,
                    color: Color(0xFF7B2CBF), size: 20)
                : null,
            filled: true,
            fillColor: _emailPrefilledFromAuth
                ? const Color(0xFFEEF2FF)
                : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _emailPrefilledFromAuth
                        ? const Color(0xFF7B2CBF).withValues(alpha: 0.4)
                        : const Color(0xFFE2E8F0),
                    width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFF7B2CBF), width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: Color(0xFFDC2626), width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        if (_emailPrefilledFromAuth) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13,
                  color: const Color(0xFF64748B).withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'This is the email associated with your current session.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCvUploadSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _cvFileName != null
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file,
                    color: Color(0xFF7B2CBF), size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upload Your CV',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E))),
                    SizedBox(height: 4),
                    Text('PDF, DOC, or DOCX (Max 10 MB)',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          if (_cvFileName != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('File Selected',
                            style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(_cvFileName!,
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Color(0xFF64748B), size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedCvFile = null;
                        _cvFileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isUploadingFile ||
                      _isSubmitting ||
                      _isCheckingExisting ||
                      _isCheckingRegistered
                  ? null
                  : _selectCvFile,
              icon: Icon(_cvFileName != null ? Icons.refresh : Icons.attach_file),
              label: Text(_cvFileName != null ? 'Change CV' : 'Select CV File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7B2CBF),
                side: const BorderSide(color: Color(0xFF7B2CBF), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage!,
                style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen) {
    final isLoading = _isSubmitting ||
        _isUploadingFile ||
        _isCheckingExisting ||
        _isCheckingRegistered;

    String loadingLabel = 'Processing...';
    if (_isCheckingRegistered) loadingLabel = 'Verifying email...';
    if (_isCheckingExisting) loadingLabel = 'Checking records...';
    if (_isUploadingFile) loadingLabel = 'Uploading CV...';
    if (_isSubmitting) loadingLabel = 'Submitting...';

    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B2CBF),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Text(loadingLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 12),
                  Text('Submit Application',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                ],
              ),
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline,
              size: 18, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your information is secure and will only be used for recruitment purposes. One application per email address.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF475569), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}