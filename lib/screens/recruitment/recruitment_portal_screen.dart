import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';

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

  bool _isSubmitting = false;
  bool _isUploadingFile = false;
  String? _cvFileName;
  PlatformFile? _selectedCvFile;
  String? _errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
    _logger.i('RecruitmentPortalScreen initialized');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
    _logger.d('Animation initialized and started');
  }

  @override
  void dispose() {
    _logger.d('RecruitmentPortalScreen disposing');
    _fullNameController.dispose();
    _emailController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _validateFileSize(PlatformFile file) {
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    final fileSizeMB = file.size / (1024 * 1024);

    _logger.d(
        'Validating file size: ${file.name} (${fileSizeMB.toStringAsFixed(2)}MB)');

    if (file.size > maxSize) {
      _logger.w(
          'File size exceeds limit: ${fileSizeMB.toStringAsFixed(1)}MB > 10MB');
      setState(() {
        _errorMessage =
            'File too large. Maximum size is 10MB. Your file is ${fileSizeMB.toStringAsFixed(1)}MB';
      });
      return false;
    }

    _logger.d('File size validation passed');
    return true;
  }

  String _getContentType(String extension) {
    final ext = extension.toLowerCase();
    _logger.d('Getting content type for extension: $ext');
    
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        _logger.w('Unknown extension, using application/octet-stream');
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
        _logger.i('File selected: ${file.name} (${file.size} bytes)');
        _logger.d('File extension: ${file.extension}');

        if (!_validateFileSize(file)) {
          _logger.w('File size validation failed');
          return;
        }

        setState(() {
          _selectedCvFile = file;
          _cvFileName = file.name;
          _errorMessage = null;
        });

        _logger.i('CV file set successfully: $_cvFileName');
      } else {
        _logger.d('File selection cancelled by user');
      }
    } catch (e, stackTrace) {
      _logger.e('Error selecting file', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Error selecting file. Please try again.';
      });
    }
  }

  Future<String?> _uploadCvToStorage(
      PlatformFile file, String fullName, String email) async {
    _logger.i('=== STARTING CV UPLOAD TO FIREBASE STORAGE ===');
    _logger.d('Full Name: $fullName');
    _logger.d('Email: $email');
    _logger.d('File: ${file.name}');
    _logger.d('File size: ${file.size} bytes');
    _logger.d('File extension: ${file.extension}');

    try {
      setState(() => _isUploadingFile = true);

      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedName = fullName.replaceAll(' ', '_').toLowerCase();
      final fileExtension = file.extension ?? 'pdf';
      final fileName = '${sanitizedName}_$timestamp.$fileExtension';

      _logger.d('Generated filename: $fileName');

      // Get proper content type
      final contentType = _getContentType(fileExtension);
      _logger.i('Content-Type: $contentType');

      // Upload to Firebase Storage in Recruitees folder
      final storageRef =
          FirebaseStorage.instance.ref().child('Recruitees/$fileName');

      _logger.d('Storage path: Recruitees/$fileName');

      // Create metadata with explicit contentType
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedBy': email,
          'uploaderName': fullName,
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalFileName': file.name,
        },
      );

      _logger.i('Uploading file with metadata...');
      _logger.d('Metadata: contentType=$contentType');

      // Upload with explicit metadata
      final uploadTask = await storageRef.putData(
        file.bytes!,
        metadata,
      );

      _logger.i('Upload task completed');
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      _logger.i('✅ CV UPLOADED SUCCESSFULLY');
      _logger.d('Download URL: $downloadUrl');

      return downloadUrl;
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('❌ FIREBASE EXCEPTION during upload', error: e, stackTrace: stackTrace);
      _logger.e('Error code: ${e.code}');
      _logger.e('Error message: ${e.message}');
      _logger.e('Error plugin: ${e.plugin}');
      
      setState(() {
        _errorMessage = 'Upload failed: ${e.message}\nError code: ${e.code}';
      });
      return null;
    } catch (e, stackTrace) {
      _logger.e('❌ UNEXPECTED ERROR during upload', error: e, stackTrace: stackTrace);
      setState(() {
        _errorMessage = 'Failed to upload CV. Please try again. Error: ${e.toString()}';
      });
      return null;
    } finally {
      setState(() => _isUploadingFile = false);
      _logger.d('=== CV UPLOAD COMPLETED ===');
    }
  }

  Future<void> _submitApplication() async {
    _logger.i('=== APPLICATION SUBMISSION INITIATED ===');

    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }

    if (_selectedCvFile == null) {
      _logger.w('No CV file selected');
      setState(() {
        _errorMessage = 'Please upload your CV before submitting';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

    _logger.i('Submitting application for: $fullName ($email)');

    try {
      // Step 1: Upload CV to Firebase Storage
      _logger.d('Step 1: Uploading CV to storage');
      final cvUrl = await _uploadCvToStorage(_selectedCvFile!, fullName, email);

      if (cvUrl == null) {
        _logger.e('❌ CV upload failed - aborting submission');
        return;
      }

      _logger.i('✅ CV upload successful, proceeding to Firestore save');

      // Step 2: Save recruitee data to Firestore
      _logger.d('Step 2: Saving recruitee data to Firestore');

      final recruiteeData = {
        'fullName': fullName,
        'email': email,
        'cvUrl': cvUrl,
        'cvFileName': _cvFileName,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, shortlisted, rejected
        'reviewedAt': null,
        'reviewNotes': null,
      };

      _logger.d('Recruitee data prepared');
      _logger.d('Data keys: ${recruiteeData.keys.toList()}');

      // Use email as document ID to prevent duplicate submissions
      final sanitizedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
      _logger.d('Document ID: $sanitizedEmail');

      _logger.i('Saving to Firestore...');
      await FirebaseFirestore.instance
          .collection('Recruitees')
          .doc(sanitizedEmail)
          .set(recruiteeData, SetOptions(merge: true));

      _logger.i('✅ APPLICATION SUBMITTED SUCCESSFULLY');

      // Step 3: Show success dialog
      if (mounted) {
        await _showSuccessDialog();
      }
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('❌ FIREBASE ERROR during submission',
          error: e, stackTrace: stackTrace);
      _logger.e('Error code: ${e.code}');
      _logger.e('Error message: ${e.message}');

      setState(() {
        _errorMessage =
            'Failed to submit application. Please try again.\nError: ${e.message}';
      });
    } catch (e, stackTrace) {
      _logger.e('❌ UNEXPECTED ERROR during submission',
          error: e, stackTrace: stackTrace);

      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.\nError: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      _logger.d('=== APPLICATION SUBMISSION COMPLETED ===');
    }
  }

  Future<void> _showSuccessDialog() async {
    _logger.i('Showing success dialog');

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 60,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Application Submitted!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you for your interest in joining JV Almacis. Our recruitment team will review your application and contact you soon.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check your email for confirmation',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _logger.i('Closing success dialog and returning to previous screen');
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to welcome screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            _buildHeader(),

            // Main content
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
                              // Info card
                              _buildInfoCard(),

                              const SizedBox(height: 32),

                              // Full Name field
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Full name is required';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Email field
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'you@example.com',
                                icon: Icons.email_outlined,
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

                              const SizedBox(height: 24),

                              // CV Upload section
                              _buildCvUploadSection(),

                              const SizedBox(height: 24),

                              // Error message
                              if (_errorMessage != null) ...[
                                _buildErrorMessage(),
                                const SizedBox(height: 20),
                              ],

                              // Submit button
                              _buildSubmitButton(isSmallScreen),

                              const SizedBox(height: 24),

                              // Privacy note
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
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF1A1A2E),
              ),
              onPressed: () {
                _logger.i('Back button pressed - returning to previous screen');
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join Our Team',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Submit your application',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
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
          colors: [
            Color(0xFFEA580C),
            Color(0xFFC2410C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.3),
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
            child: const Icon(
              Icons.work_outline,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Start Your Career Journey',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Submit your application by filling in your details and uploading your CV. No account required!',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 15,
            ),
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF64748B),
              size: 20,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEA580C),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
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
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.upload_file,
                  color: Color(0xFFEA580C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Your CV',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF, DOC, or DOCX (Max 10MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'File Selected',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _cvFileName!,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedCvFile = null;
                        _cvFileName = null;
                      });
                      _logger.i('CV file removed');
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
              onPressed: _isUploadingFile || _isSubmitting
                  ? null
                  : _selectCvFile,
              icon: Icon(_cvFileName != null
                  ? Icons.refresh
                  : Icons.attach_file),
              label: Text(_cvFileName != null
                  ? 'Change CV'
                  : 'Select CV File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEA580C),
                side: const BorderSide(
                  color: Color(0xFFEA580C),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
        border: Border.all(
          color: const Color(0xFFFECACA),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 52 : 56,
      child: ElevatedButton(
        onPressed: _isSubmitting || _isUploadingFile
            ? null
            : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEA580C),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isSubmitting || _isUploadingFile
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _isUploadingFile
                        ? 'Uploading CV...'
                        : 'Submitting...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Submit Application',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
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
          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 18,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your information is secure and will only be used for recruitment purposes.',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}