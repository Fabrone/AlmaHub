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

  // ✅ NEW: Helper method to get proper content type
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

      // ✅ UPDATED: Create metadata with explicit contentType
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 60,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Application Submitted!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 66, 10, 113),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you for your interest in joining JV Almacis. Our recruitment team will review your application and contact you soon.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your email for confirmation',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
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
                backgroundColor: const Color.fromARGB(255, 66, 10, 113),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
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
    final contentWidth = screenWidth > 800 ? screenWidth * 0.5 : screenWidth * 0.9;

    return Scaffold(
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
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        _logger.i('Back button pressed - returning to previous screen');
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recruitment Portal',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Join Our Team',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Info card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.work_outline,
                                      size: 48,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(height: 16),
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
                                    Text(
                                      'Submit your application by filling in your details and uploading your CV. No account required!',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Full Name field
                              TextFormField(
                                controller: _fullNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  labelStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  hintText: 'Enter your full name',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
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
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              // CV Upload section
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _cvFileName != null
                                        ? Colors.green.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.upload_file,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Upload Your CV',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'PDF, DOC, or DOCX (Max 10MB)',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (_cvFileName != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.greenAccent,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'File Selected',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _cvFileName!,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.9),
                                                      fontSize: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white70,
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
                                      const SizedBox(height: 12),
                                    ],
                                    ElevatedButton.icon(
                                      onPressed: _isUploadingFile || _isSubmitting
                                          ? null
                                          : _selectCvFile,
                                      icon: Icon(_cvFileName != null
                                          ? Icons.refresh
                                          : Icons.attach_file),
                                      label: Text(_cvFileName != null
                                          ? 'Change CV'
                                          : 'Select CV File'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor:
                                            const Color.fromARGB(255, 66, 10, 113),
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 20,
                                        ),
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

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting || _isUploadingFile
                                      ? null
                                      : _submitApplication,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                        const Color.fromARGB(255, 66, 10, 113),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 8,
                                    shadowColor: Colors.black45,
                                  ),
                                  child: _isSubmitting || _isUploadingFile
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Color.fromARGB(255, 66, 10, 113),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              _isUploadingFile
                                                  ? 'Uploading CV...'
                                                  : 'Submitting...',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.send),
                                            SizedBox(width: 12),
                                            Text(
                                              'Submit Application',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Privacy note
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 20,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Your information is secure and will only be used for recruitment purposes.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.white.withValues(alpha: 0.8),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}