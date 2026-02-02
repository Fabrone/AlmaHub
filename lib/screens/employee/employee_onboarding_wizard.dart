import 'dart:async';
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/services/firestore_service.dart';
import 'package:almahub/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeOnboardingWizard extends StatefulWidget {
  final EmployeeOnboarding? existingEmployee;
  
  const EmployeeOnboardingWizard({
    super.key,
    this.existingEmployee,
  });

  @override
  State<EmployeeOnboardingWizard> createState() =>
      _EmployeeOnboardingWizardState();
}

class _EmployeeOnboardingWizardState extends State<EmployeeOnboardingWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 8;

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  bool _isUploadingFile = false;

  // Logger for comprehensive debugging
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

  // Form keys for validation
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(8, (_) => GlobalKey<FormState>());

  // Data models
  late PersonalInformation _personalInfo;
  late EmploymentDetails _employmentDetails;
  late StatutoryDocuments _statutoryDocs;
  late PayrollDetails _payrollDetails;
  late AcademicDocuments _academicDocs;
  late ContractsAndForms _contractsForms;
  late BenefitsInsurance _benefitsInsurance;
  late WorkToolsAccess _workTools;

  String? _draftId;
  bool _isSaving = false;
  bool _isLoadingUserData = true;
  
  // Store registered username and email
  String? _registeredUsername;
  String? _registeredEmail;

  @override
  void initState() {
    super.initState();
    _logger.i('=== EmployeeOnboardingWizard Initialized ===');
    _logger.d('Existing employee data: ${widget.existingEmployee != null ? "YES" : "NO"}');
    _initializeData();
    _loadUserDataFromAuth();  
  }

  void _initializeData() {
    _logger.d('Initializing default data models');
    _personalInfo = PersonalInformation(
      nextOfKin: NextOfKin(),
    );
    _employmentDetails = EmploymentDetails();
    _statutoryDocs = StatutoryDocuments();
    _payrollDetails = PayrollDetails(
      bankDetails: BankDetails(),
      mpesaDetails: MpesaDetails(),
    );
    _academicDocs = AcademicDocuments();
    _contractsForms = ContractsAndForms();
    _benefitsInsurance = BenefitsInsurance();
    _workTools = WorkToolsAccess();
    _logger.d('Default data models initialized successfully');
  }

  Future<void> _loadUserDataFromAuth() async {
    _logger.i('Loading user data from Firebase Auth');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        _logger.w('No authenticated user found');
        setState(() {
          _isLoadingUserData = false;
        });
        return;
      }
      
      _logger.d('Authenticated user UID: ${user.uid}');
      _logger.d('User email: ${user.email}');
      
      // ✅ ONLY SEARCH DRAFT COLLECTION - No Users collection
      _logger.i('Searching for Draft document with email: ${user.email}');
      final draftQuery = await FirebaseFirestore.instance
          .collection('Draft')
          .where('personalInfo.email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (draftQuery.docs.isNotEmpty) {
        final draftDoc = draftQuery.docs.first;
        _draftId = draftDoc.id;
        final draftData = draftDoc.data();
        
        _logger.i('Found Draft document: $_draftId');
        
        // Extract registered username and email
        _registeredUsername = draftData['registrationUsername'] as String?;
        _registeredEmail = draftData['registrationEmail'] as String?;
        
        _logger.d('Registered username: $_registeredUsername');
        _logger.d('Registered email: $_registeredEmail');
        
        // Load existing draft data if present
        if (widget.existingEmployee == null) {
          _logger.i('Loading draft data from Firestore');
          final employee = EmployeeOnboarding.fromMap(draftData);
          
          setState(() {
            _personalInfo = employee.personalInfo;
            _employmentDetails = employee.employmentDetails;
            _statutoryDocs = employee.statutoryDocs;
            _payrollDetails = employee.payrollDetails;
            _academicDocs = employee.academicDocs;
            _contractsForms = employee.contractsForms;
            _benefitsInsurance = employee.benefitsInsurance;
            _workTools = employee.workTools;
          });
          
          _logger.i('Draft data loaded successfully');
        } else {
          // Load existing employee data
          await _loadExistingData();
        }
      } else {
        _logger.w('No Draft document found for user: ${user.email}');
        
        // ✅ NO FALLBACK TO USERS COLLECTION - just set empty state
        _logger.i('Creating new draft with user email pre-filled');
        setState(() {
          _personalInfo = PersonalInformation(
            email: user.email ?? '',
            nextOfKin: NextOfKin(),
          );
          _registeredEmail = user.email;
        });
      }
      
    } catch (e, stackTrace) {
      _logger.e('Error loading user data from auth', error: e, stackTrace: stackTrace);
    } finally {
      setState(() {
        _isLoadingUserData = false;
      });
      _logger.d('User data loading completed');
    }
  }

  Future<void> _loadExistingData() async {
    if (widget.existingEmployee != null) {
      _logger.i('Loading existing employee data');
      final employee = widget.existingEmployee!;
      
      _logger.d('Existing employee details:');
      _logger.d('  - ID: ${employee.id}');
      _logger.d('  - Status: ${employee.status}');
      _logger.d('  - Full Name: ${employee.personalInfo.fullName}');
      _logger.d('  - Created: ${employee.createdAt}');
      _logger.d('  - Updated: ${employee.updatedAt}');
      
      setState(() {
        _draftId = employee.id;
        _personalInfo = employee.personalInfo;
        _employmentDetails = employee.employmentDetails;
        _statutoryDocs = employee.statutoryDocs;
        _payrollDetails = employee.payrollDetails;
        _academicDocs = employee.academicDocs;
        _contractsForms = employee.contractsForms;
        _benefitsInsurance = employee.benefitsInsurance;
        _workTools = employee.workTools;
      });
      
      _logger.i('Existing employee data loaded successfully (Draft ID: $_draftId)');
    } else {
      _logger.d('No existing employee data to load - starting fresh');
    }
  }

  bool _validateFileSize(PlatformFile file) {
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    final fileSizeMB = file.size / (1024 * 1024);
    
    _logger.d('Validating file size: ${file.name} (${fileSizeMB.toStringAsFixed(2)}MB)');
    
    if (file.size > maxSize) {
      _logger.w('File size exceeds limit: ${fileSizeMB.toStringAsFixed(1)}MB > 10MB');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File too large. Maximum size is 10MB. Your file is ${fileSizeMB.toStringAsFixed(1)}MB',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
    
    _logger.d('File size validation passed');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching user data
    if (_isLoadingUserData) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'Employee Onboarding Form',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 84, 4, 108),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your information...'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Employee Onboarding Form',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 84, 4, 108),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoStep(),
                _buildEmploymentDetailsStep(),
                _buildStatutoryDocsStep(),
                _buildPayrollDetailsStep(),
                _buildAcademicDocsStep(),
                _buildContractsFormsStep(),
                _buildBenefitsInsuranceStep(),
                _buildWorkToolsStep(),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isCompleted = index < _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? const Color.fromARGB(255, 84, 4, 108)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle(_currentStep)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Information';
      case 1:
        return 'Employment Details';
      case 2:
        return 'Statutory Documents';
      case 3:
        return 'Payroll & Payment';
      case 4:
        return 'Academic & Professional';
      case 5:
        return 'Contracts & HR Forms';
      case 6:
        return 'Benefits & Insurance';
      case 7:
        return 'Work Tools & Access';
      default:
        return '';
    }
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color.fromARGB(255, 84, 4, 121), width: 2),
                  foregroundColor: const Color.fromARGB(255, 78, 15, 118),
                ),
                child: const Text(
                  'Previous',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAsDraft,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Save as Draft',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _currentStep == _totalSteps - 1 ? _submitForm : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 84, 21, 132),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
              ),
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Submit' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousStep() {
    _logger.d('Going to previous step from step ${_currentStep + 1}');
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _logger.i('Moved to step ${_currentStep + 1}: ${_getStepTitle(_currentStep)}');
    }
  }

  void _nextStep() {
    _logger.d('Attempting to move to next step from step ${_currentStep + 1}');
    _logger.d('Validating current step form...');
    
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      _logger.i('Step ${_currentStep + 1} validation passed');
      
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
          _pageController.animateToPage(
            _currentStep,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
        _logger.i('Moved to step ${_currentStep + 1}: ${_getStepTitle(_currentStep)}');
      }
    } else {
      _logger.w('Step ${_currentStep + 1} validation FAILED');
    }
  }

  Future<void> _saveAsDraft() async {
    _logger.i('=== SAVE AS DRAFT INITIATED ===');
    _logger.d('Current draft ID: $_draftId');
    _logger.d('Current step: ${_currentStep + 1}/$_totalSteps');
    
    setState(() => _isSaving = true);

    try {
      // Validate current form to ensure data is captured
      _formKeys[_currentStep].currentState?.save();
      
      _logger.d('Checking for existing employee data...');
      // Get existing data if updating
      EmployeeOnboarding? existingEmployee;
      if (_draftId != null && _draftId!.isNotEmpty) {
        _logger.i('Fetching existing employee onboarding (ID: $_draftId)');
        try {
          existingEmployee = await _firestoreService.getEmployeeOnboarding(_draftId!)
              .timeout(const Duration(seconds: 10));
          if (existingEmployee != null) {
            _logger.i('Existing employee data found:');
            _logger.d('  - Created: ${existingEmployee.createdAt}');
            _logger.d('  - Status: ${existingEmployee.status}');
            _logger.d('  - Full Name: ${existingEmployee.personalInfo.fullName}');
          } else {
            _logger.w('No existing employee data found for ID: $_draftId');
          }
        } on TimeoutException {
          _logger.e('Timeout fetching existing employee - continuing with save');
        } catch (e, stackTrace) {
          _logger.e('Error fetching existing employee', error: e, stackTrace: stackTrace);
          // Continue with save even if fetch fails
        }
      } else {
        _logger.d('No draft ID set - this is a new draft');
      }

      _logger.d('Building EmployeeOnboarding object...');
      _logger.d('Personal Info: ${_personalInfo.fullName}');
      _logger.d('Employment: ${_employmentDetails.jobTitle}');
      
      final employee = EmployeeOnboarding(
        id: _draftId ?? '',
        status: 'draft',
        createdAt: existingEmployee?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        submittedAt: null,
        personalInfo: _personalInfo,
        employmentDetails: _employmentDetails,
        statutoryDocs: _statutoryDocs,
        payrollDetails: _payrollDetails,
        academicDocs: _academicDocs,
        contractsForms: _contractsForms,
        benefitsInsurance: _benefitsInsurance,
        workTools: _workTools,
      );

      _logger.i('Saving employee onboarding to Firestore...');
      _logger.d('Employee object details:');
      _logger.d('  - ID: ${employee.id}');
      _logger.d('  - Status: ${employee.status}');
      _logger.d('  - Created At: ${employee.createdAt}');
      _logger.d('  - Updated At: ${employee.updatedAt}');
      
      // Add timeout to prevent infinite loading
      final savedId = await _firestoreService.saveEmployeeOnboarding(employee)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Save operation timed out after 30 seconds');
            },
          );
      
      _logger.i('✅ Successfully saved! Returned ID: $savedId');
      
      if (savedId.isNotEmpty) {
        _draftId = savedId;
        _logger.i('Draft ID updated to: $_draftId');
      } else {
        _logger.w('⚠️ Saved but returned ID is null or empty');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _logger.i('Success message displayed to user');
      }
    } on TimeoutException catch (e) {
      _logger.e('❌ TIMEOUT ERROR', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save operation timed out. Please check your internet connection and try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR SAVING DRAFT', error: e, stackTrace: stackTrace);
      _logger.e('Error type: ${e.runtimeType}');
      _logger.e('Error message: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving draft: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _saveAsDraft,
            ),
          ),
        );
        _logger.w('Error message displayed to user');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      _logger.d('=== SAVE AS DRAFT COMPLETED ===');
    }
  }

  Future<void> _submitForm() async {
    _logger.i('=== FORM SUBMISSION INITIATED ===');
    _logger.d('Validating final step (${_currentStep + 1})...');
    
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      _logger.i('Final step validation passed');
      _formKeys[_currentStep].currentState?.save();

      // Validate all required fields across all steps
      _logger.d('Validating all required fields...');
      bool isValid = true;
      String errorMessage = '';

      if (_personalInfo.fullName.isEmpty) {
        isValid = false;
        errorMessage = 'Please complete Personal Information';
        _logger.w('Validation failed: Personal Information incomplete');
      } else if (_employmentDetails.jobTitle.isEmpty) {
        isValid = false;
        errorMessage = 'Please complete Employment Details';
        _logger.w('Validation failed: Employment Details incomplete');
      } else if (_statutoryDocs.kraPinNumber.isEmpty) {
        isValid = false;
        errorMessage = 'Please complete Statutory Documents';
        _logger.w('Validation failed: Statutory Documents incomplete');
      } else if (_payrollDetails.basicSalary <= 0) {
        isValid = false;
        errorMessage = 'Please complete Payroll Details';
        _logger.w('Validation failed: Payroll Details incomplete');
      }

      if (!isValid) {
        _logger.w('Overall validation FAILED: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      _logger.i('All validations passed ✓');

      // Confirm submission
      _logger.d('Showing confirmation dialog to user...');
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit Application'),
          content: const Text(
            'Are you sure you want to submit your application? '
            'You won\'t be able to edit it after submission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 85, 30, 122),
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        _logger.i('User confirmed submission');
        setState(() => _isSaving = true);

        try {
          // Get existing data to preserve createdAt
          _logger.d('Fetching existing data to preserve timestamps...');
          EmployeeOnboarding? existingEmployee;
          if (_draftId != null && _draftId!.isNotEmpty) {
            _logger.d('Fetching existing employee (ID: $_draftId)');
            try {
              existingEmployee = await _firestoreService.getEmployeeOnboarding(_draftId!);
              if (existingEmployee != null) {
                _logger.d('Existing data found - will preserve createdAt: ${existingEmployee.createdAt}');
              }
            } catch (e) {
              _logger.w('Could not fetch existing data: $e');
            }
          }

          _logger.d('Creating final employee object with status=submitted...');
          final employee = EmployeeOnboarding(
            id: _draftId ?? '',
            status: 'submitted',
            createdAt: existingEmployee?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
            submittedAt: DateTime.now(),
            personalInfo: _personalInfo,
            employmentDetails: _employmentDetails,
            statutoryDocs: _statutoryDocs,
            payrollDetails: _payrollDetails,
            academicDocs: _academicDocs,
            contractsForms: _contractsForms,
            benefitsInsurance: _benefitsInsurance,
            workTools: _workTools,
          );

          _logger.i('Submitting to Firestore...');
          await _firestoreService.saveEmployeeOnboarding(employee);
          _logger.i('✅ Application submitted successfully!');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Application submitted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Navigate back after short delay
            _logger.d('Waiting 2 seconds before navigating back...');
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              _logger.i('Navigating back to dashboard');
              Navigator.pop(context);
            }
          }
        } catch (e, stackTrace) {
          _logger.e('❌ ERROR SUBMITTING FORM', error: e, stackTrace: stackTrace);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error submitting form: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } finally {
          setState(() => _isSaving = false);
          _logger.d('=== FORM SUBMISSION COMPLETED ===');
        }
      } else {
        _logger.i('User cancelled submission');
      }
    } else {
      _logger.w('Final step validation FAILED');
    }
  }

  Future<void> _uploadFile(
    String fieldName,
    Function(String url) onUploadSuccess,
  ) async {
    _logger.i('=== FILE UPLOAD INITIATED ===');
    _logger.d('Field: $fieldName');
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _logger.i('File selected: ${file.name} (${(file.size / 1024).toStringAsFixed(2)} KB)');

        if (!_validateFileSize(file)) {
          _logger.w('File validation failed - upload cancelled');
          return;
        }

        setState(() => _isUploadingFile = true);

        try {
          _logger.d('Starting file upload to storage...');
          final employeeName = _personalInfo.fullName.isNotEmpty 
              ? _personalInfo.fullName 
              : 'temp_${DateTime.now().millisecondsSinceEpoch}';
          
          final url = await _storageService.uploadEmployeeDocument(
            employeeName: employeeName,
            fieldName: fieldName,
            file: file,
          );

          _logger.i('✅ File uploaded successfully!');
          _logger.d('File URL: $url');

          onUploadSuccess(url);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${file.name} uploaded successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e, stackTrace) {
          _logger.e('❌ Upload error', error: e, stackTrace: stackTrace);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading file: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } finally {
          setState(() => _isUploadingFile = false);
        }
      } else {
        _logger.d('No file selected - upload cancelled by user');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ File picker error', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Step 1: Personal Information - UPDATED WITH PRE-FILLED EMAIL
  Widget _buildPersonalInfoStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[0],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('A. Personal Information'),
            const SizedBox(height: 24),
            
            // Display registered username info if available
            if (_registeredUsername != null && _registeredUsername!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: const Color.fromARGB(255, 195, 25, 210), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Registered as: $_registeredUsername',
                        style: TextStyle(
                          color: const Color.fromARGB(255, 102, 13, 161),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Full Name
            TextFormField(
              initialValue: _personalInfo.fullName,
              decoration: _inputDecoration('Full Name *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: value,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // National ID/Passport
            TextFormField(
              initialValue: _personalInfo.nationalIdOrPassport,
              decoration: _inputDecoration('National ID / Passport Number *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: value,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // ID Document Upload
            _buildUploadButton(
              'Upload ID/Passport Document *',
              () => _uploadFile('id_document', (url) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: url,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              }),
              _personalInfo.idDocumentUrl,
            ),
            const SizedBox(height: 16),
            
            // Date of Birth
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _personalInfo.dateOfBirth ?? DateTime(1990),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _personalInfo = PersonalInformation(
                      fullName: _personalInfo.fullName,
                      nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                      idDocumentUrl: _personalInfo.idDocumentUrl,
                      dateOfBirth: date,
                      gender: _personalInfo.gender,
                      phoneNumber: _personalInfo.phoneNumber,
                      email: _personalInfo.email,
                      postalAddress: _personalInfo.postalAddress,
                      physicalAddress: _personalInfo.physicalAddress,
                      nextOfKin: _personalInfo.nextOfKin,
                    );
                  });
                }
              },
              child: InputDecorator(
                decoration: _inputDecoration('Date of Birth *'),
                child: Text(
                  _personalInfo.dateOfBirth != null
                      ? DateFormat('yyyy-MM-dd').format(_personalInfo.dateOfBirth!)
                      : 'Select date',
                  style: TextStyle(
                    color: _personalInfo.dateOfBirth != null
                        ? Colors.black
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Gender
            DropdownButtonFormField<String>(
              initialValue: _personalInfo.gender.isNotEmpty ? _personalInfo.gender : null,
              decoration: _inputDecoration('Gender *'),
              items: ['Male', 'Female', 'Other']
                  .map((gender) => DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      ))
                  .toList(),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _personalInfo = PersonalInformation(
                      fullName: _personalInfo.fullName,
                      nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                      idDocumentUrl: _personalInfo.idDocumentUrl,
                      dateOfBirth: _personalInfo.dateOfBirth,
                      gender: value,
                      phoneNumber: _personalInfo.phoneNumber,
                      email: _personalInfo.email,
                      postalAddress: _personalInfo.postalAddress,
                      physicalAddress: _personalInfo.physicalAddress,
                      nextOfKin: _personalInfo.nextOfKin,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Phone Number
            TextFormField(
              initialValue: _personalInfo.phoneNumber,
              decoration: _inputDecoration('Phone Number *'),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: value,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Email - PRE-FILLED FROM REGISTRATION (EDITABLE)
            TextFormField(
              initialValue: _personalInfo.email.isNotEmpty 
                  ? _personalInfo.email 
                  : _registeredEmail ?? '',
              decoration: _inputDecoration('Email Address *').copyWith(
                suffixIcon: _registeredEmail != null 
                    ? const Tooltip(
                        message: 'Pre-filled from registration. You can edit if needed.',
                        child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                      )
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (!value!.contains('@')) return 'Invalid email';
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: value,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Postal Address
            TextFormField(
              initialValue: _personalInfo.postalAddress,
              decoration: _inputDecoration('Postal Address *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: value,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Physical Address
            TextFormField(
              initialValue: _personalInfo.physicalAddress,
              decoration: _inputDecoration('Physical Address *'),
              maxLines: 2,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: value,
                    nextOfKin: _personalInfo.nextOfKin,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Next of Kin Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Next of Kin Name
            TextFormField(
              initialValue: _personalInfo.nextOfKin.name,
              decoration: _inputDecoration('Name *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: NextOfKin(
                      name: value,
                      relationship: _personalInfo.nextOfKin.relationship,
                      contact: _personalInfo.nextOfKin.contact,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Next of Kin Relationship
            TextFormField(
              initialValue: _personalInfo.nextOfKin.relationship,
              decoration: _inputDecoration('Relationship *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: NextOfKin(
                      name: _personalInfo.nextOfKin.name,
                      relationship: value,
                      contact: _personalInfo.nextOfKin.contact,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Next of Kin Contact
            TextFormField(
              initialValue: _personalInfo.nextOfKin.contact,
              decoration: _inputDecoration('Contact Number *'),
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _personalInfo = PersonalInformation(
                    fullName: _personalInfo.fullName,
                    nationalIdOrPassport: _personalInfo.nationalIdOrPassport,
                    idDocumentUrl: _personalInfo.idDocumentUrl,
                    dateOfBirth: _personalInfo.dateOfBirth,
                    gender: _personalInfo.gender,
                    phoneNumber: _personalInfo.phoneNumber,
                    email: _personalInfo.email,
                    postalAddress: _personalInfo.postalAddress,
                    physicalAddress: _personalInfo.physicalAddress,
                    nextOfKin: NextOfKin(
                      name: _personalInfo.nextOfKin.name,
                      relationship: _personalInfo.nextOfKin.relationship,
                      contact: value,
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentDetailsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[1],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('B. Employment Details'),
            const SizedBox(height: 24),
            
            // Job Title
            TextFormField(
              initialValue: _employmentDetails.jobTitle,
              decoration: _inputDecoration('Job Title *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _employmentDetails = EmploymentDetails(
                    jobTitle: value,
                    department: _employmentDetails.department,
                    employmentType: _employmentDetails.employmentType,
                    startDate: _employmentDetails.startDate,
                    workingHours: _employmentDetails.workingHours,
                    workLocation: _employmentDetails.workLocation,
                    supervisorName: _employmentDetails.supervisorName,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Department
            TextFormField(
              initialValue: _employmentDetails.department,
              decoration: _inputDecoration('Department *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _employmentDetails = EmploymentDetails(
                    jobTitle: _employmentDetails.jobTitle,
                    department: value,
                    employmentType: _employmentDetails.employmentType,
                    startDate: _employmentDetails.startDate,
                    workingHours: _employmentDetails.workingHours,
                    workLocation: _employmentDetails.workLocation,
                    supervisorName: _employmentDetails.supervisorName,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Employment Type
            DropdownButtonFormField<String>(
              initialValue: _employmentDetails.employmentType.isEmpty 
                  ? null 
                  : _employmentDetails.employmentType,
              decoration: _inputDecoration('Employment Type *'),
              items: ['Permanent', 'Contract', 'Casual']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              validator: (value) => value == null ? 'Required' : null,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _employmentDetails = EmploymentDetails(
                      jobTitle: _employmentDetails.jobTitle,
                      department: _employmentDetails.department,
                      employmentType: value,
                      startDate: _employmentDetails.startDate,
                      workingHours: _employmentDetails.workingHours,
                      workLocation: _employmentDetails.workLocation,
                      supervisorName: _employmentDetails.supervisorName,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Start Date
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _employmentDetails.startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() {
                    _employmentDetails = EmploymentDetails(
                      jobTitle: _employmentDetails.jobTitle,
                      department: _employmentDetails.department,
                      employmentType: _employmentDetails.employmentType,
                      startDate: date,
                      workingHours: _employmentDetails.workingHours,
                      workLocation: _employmentDetails.workLocation,
                      supervisorName: _employmentDetails.supervisorName,
                    );
                  });
                }
              },
              child: InputDecorator(
                decoration: _inputDecoration('Start Date *'),
                child: Text(
                  _employmentDetails.startDate != null
                      ? DateFormat('dd/MM/yyyy').format(_employmentDetails.startDate!)
                      : 'Select date',
                  style: TextStyle(
                    color: _employmentDetails.startDate != null 
                        ? Colors.black 
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Working Hours
            TextFormField(
              initialValue: _employmentDetails.workingHours,
              decoration: _inputDecoration('Working Hours (e.g., 8:00 AM - 5:00 PM) *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _employmentDetails = EmploymentDetails(
                    jobTitle: _employmentDetails.jobTitle,
                    department: _employmentDetails.department,
                    employmentType: _employmentDetails.employmentType,
                    startDate: _employmentDetails.startDate,
                    workingHours: value,
                    workLocation: _employmentDetails.workLocation,
                    supervisorName: _employmentDetails.supervisorName,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Work Location
            TextFormField(
              initialValue: _employmentDetails.workLocation,
              decoration: _inputDecoration('Work Location *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _employmentDetails = EmploymentDetails(
                    jobTitle: _employmentDetails.jobTitle,
                    department: _employmentDetails.department,
                    employmentType: _employmentDetails.employmentType,
                    startDate: _employmentDetails.startDate,
                    workingHours: _employmentDetails.workingHours,
                    workLocation: value,
                    supervisorName: _employmentDetails.supervisorName,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Supervisor Name
            TextFormField(
              initialValue: _employmentDetails.supervisorName,
              decoration: _inputDecoration('Supervisor/Reporting Manager *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _employmentDetails = EmploymentDetails(
                    jobTitle: _employmentDetails.jobTitle,
                    department: _employmentDetails.department,
                    employmentType: _employmentDetails.employmentType,
                    startDate: _employmentDetails.startDate,
                    workingHours: _employmentDetails.workingHours,
                    workLocation: _employmentDetails.workLocation,
                    supervisorName: value,
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutoryDocsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[2],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('C. Mandatory Statutory Documents'),
            const SizedBox(height: 24),
            
            // KRA PIN
            TextFormField(
              initialValue: _statutoryDocs.kraPinNumber,
              decoration: _inputDecoration('KRA PIN Number *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: value,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // KRA PIN Certificate Upload
            _buildUploadButton(
              'KRA PIN Certificate *',
              () => _uploadDocument('kra_pin', (url) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: url,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              }),
              _statutoryDocs.kraPinCertificateUrl,
            ),
            const SizedBox(height: 24),
            
            // NSSF Number
            TextFormField(
              initialValue: _statutoryDocs.nssfNumber,
              decoration: _inputDecoration('NSSF Number *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: value,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // NSSF Confirmation Upload
            _buildUploadButton(
              'NSSF Registration Confirmation *',
              () => _uploadDocument('nssf_confirmation', (url) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: url,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              }),
              _statutoryDocs.nssfConfirmationUrl,
            ),
            const SizedBox(height: 24),
            
            // NHIF Number
            TextFormField(
              initialValue: _statutoryDocs.nhifNumber,
              decoration: _inputDecoration('NHIF Number *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: value,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // NHIF Confirmation Upload
            _buildUploadButton(
              'NHIF Registration Confirmation *',
              () => _uploadDocument('nhif_confirmation', (url) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: url,
                    p9FormUrl: _statutoryDocs.p9FormUrl,
                  );
                });
              }),
              _statutoryDocs.nhifConfirmationUrl,
            ),
            const SizedBox(height: 24),
            
            // P9 Form Upload (Optional)
            _buildUploadButton(
              'P9 Form (if joining mid-year)',
              () => _uploadDocument('p9_form', (url) {
                setState(() {
                  _statutoryDocs = StatutoryDocuments(
                    kraPinNumber: _statutoryDocs.kraPinNumber,
                    kraPinCertificateUrl: _statutoryDocs.kraPinCertificateUrl,
                    nssfNumber: _statutoryDocs.nssfNumber,
                    nssfConfirmationUrl: _statutoryDocs.nssfConfirmationUrl,
                    nhifNumber: _statutoryDocs.nhifNumber,
                    nhifConfirmationUrl: _statutoryDocs.nhifConfirmationUrl,
                    p9FormUrl: url,
                  );
                });
              }),
              _statutoryDocs.p9FormUrl,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayrollDetailsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[3],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('D. Payroll & Payment Details'),
            const SizedBox(height: 24),
            
            // Basic Salary
            TextFormField(
              initialValue: _payrollDetails.basicSalary > 0 
                  ? _payrollDetails.basicSalary.toString() 
                  : '',
              decoration: _inputDecoration('Basic Salary (KES) *'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Enter valid amount';
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: double.tryParse(value) ?? 0,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Allowances',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Housing Allowance
            TextFormField(
              initialValue: _payrollDetails.allowances['housing']?.toString() ?? '',
              decoration: _inputDecoration('Housing Allowance (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newAllowances = Map<String, double>.from(_payrollDetails.allowances);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newAllowances['housing'] = amount;
                  } else {
                    newAllowances.remove('housing');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: newAllowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Transport Allowance
            TextFormField(
              initialValue: _payrollDetails.allowances['transport']?.toString() ?? '',
              decoration: _inputDecoration('Transport Allowance (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newAllowances = Map<String, double>.from(_payrollDetails.allowances);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newAllowances['transport'] = amount;
                  } else {
                    newAllowances.remove('transport');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: newAllowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Other Allowances
            TextFormField(
              initialValue: _payrollDetails.allowances['other']?.toString() ?? '',
              decoration: _inputDecoration('Other Allowances (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newAllowances = Map<String, double>.from(_payrollDetails.allowances);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newAllowances['other'] = amount;
                  } else {
                    newAllowances.remove('other');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: newAllowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Deductions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Loans
            TextFormField(
              initialValue: _payrollDetails.deductions['loans']?.toString() ?? '',
              decoration: _inputDecoration('Loans (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newDeductions = Map<String, double>.from(_payrollDetails.deductions);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newDeductions['loans'] = amount;
                  } else {
                    newDeductions.remove('loans');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: newDeductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // SACCO
            TextFormField(
              initialValue: _payrollDetails.deductions['sacco']?.toString() ?? '',
              decoration: _inputDecoration('SACCO Deductions (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newDeductions = Map<String, double>.from(_payrollDetails.deductions);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newDeductions['sacco'] = amount;
                  } else {
                    newDeductions.remove('sacco');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: newDeductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Advances
            TextFormField(
              initialValue: _payrollDetails.deductions['advances']?.toString() ?? '',
              decoration: _inputDecoration('Advances (KES)'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  final newDeductions = Map<String, double>.from(_payrollDetails.deductions);
                  final amount = double.tryParse(value) ?? 0;
                  if (amount > 0) {
                    newDeductions['advances'] = amount;
                  } else {
                    newDeductions.remove('advances');
                  }
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: newDeductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Bank Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Bank Name
            TextFormField(
              initialValue: _payrollDetails.bankDetails?.bankName ?? '',
              decoration: _inputDecoration('Bank Name *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: BankDetails(
                      bankName: value,
                      branch: _payrollDetails.bankDetails?.branch ?? '',
                      accountNumber: _payrollDetails.bankDetails?.accountNumber ?? '',
                    ),
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Branch
            TextFormField(
              initialValue: _payrollDetails.bankDetails?.branch ?? '',
              decoration: _inputDecoration('Branch *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: BankDetails(
                      bankName: _payrollDetails.bankDetails?.bankName ?? '',
                      branch: value,
                      accountNumber: _payrollDetails.bankDetails?.accountNumber ?? '',
                    ),
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Account Number
            TextFormField(
              initialValue: _payrollDetails.bankDetails?.accountNumber ?? '',
              decoration: _inputDecoration('Account Number *'),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: BankDetails(
                      bankName: _payrollDetails.bankDetails?.bankName ?? '',
                      branch: _payrollDetails.bankDetails?.branch ?? '',
                      accountNumber: value,
                    ),
                    mpesaDetails: _payrollDetails.mpesaDetails,
                  );
                });
              },
            ),
            const SizedBox(height: 24),
            
            const Text(
              'M-Pesa Details (Optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // M-Pesa Number
            TextFormField(
              initialValue: _payrollDetails.mpesaDetails?.phoneNumber ?? '',
              decoration: _inputDecoration('M-Pesa Phone Number'),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: MpesaDetails(
                      phoneNumber: value,
                      name: _payrollDetails.mpesaDetails?.name ?? '',
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 16),
            
            // M-Pesa Registered Name
            TextFormField(
              initialValue: _payrollDetails.mpesaDetails?.name ?? '',
              decoration: _inputDecoration('M-Pesa Registered Name'),
              onChanged: (value) {
                setState(() {
                  _payrollDetails = PayrollDetails(
                    basicSalary: _payrollDetails.basicSalary,
                    allowances: _payrollDetails.allowances,
                    deductions: _payrollDetails.deductions,
                    bankDetails: _payrollDetails.bankDetails,
                    mpesaDetails: MpesaDetails(
                      phoneNumber: _payrollDetails.mpesaDetails?.phoneNumber ?? '',
                      name: value,
                    ),
                  );
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicDocsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[4],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('E. Academic & Professional Documents'),
            const SizedBox(height: 24),
            
            const Text(
              'Academic Certificates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Academic Certificates List
            ..._academicDocs.academicCertificates.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.school, color: Color.fromARGB(255, 93, 26, 126)),
                  title: Text(entry.value.name),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(entry.value.uploadedAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newList = List<DocumentInfo>.from(_academicDocs.academicCertificates);
                        newList.removeAt(entry.key);
                        _academicDocs = AcademicDocuments(
                          academicCertificates: newList,
                          professionalCertificates: _academicDocs.professionalCertificates,
                          professionalRegistrations: _academicDocs.professionalRegistrations,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Add Academic Certificate Button
            ElevatedButton.icon(
              onPressed: () => _uploadDocument('academic_cert', (url) {
                final doc = DocumentInfo(
                  name: 'Academic Certificate ${_academicDocs.academicCertificates.length + 1}',
                  url: url,
                  type: 'pdf',
                  uploadedAt: DateTime.now(),
                );
                setState(() {
                  _academicDocs = AcademicDocuments(
                    academicCertificates: [..._academicDocs.academicCertificates, doc],
                    professionalCertificates: _academicDocs.professionalCertificates,
                    professionalRegistrations: _academicDocs.professionalRegistrations,
                  );
                });
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Academic Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 86, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Professional Certificates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Professional Certificates List
            ..._academicDocs.professionalCertificates.asMap().entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium, color: Color.fromARGB(255, 88, 26, 126)),
                  title: Text(entry.value.name),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(entry.value.uploadedAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newList = List<DocumentInfo>.from(_academicDocs.professionalCertificates);
                        newList.removeAt(entry.key);
                        _academicDocs = AcademicDocuments(
                          academicCertificates: _academicDocs.academicCertificates,
                          professionalCertificates: newList,
                          professionalRegistrations: _academicDocs.professionalRegistrations,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Add Professional Certificate Button
            ElevatedButton.icon(
              onPressed: () => _uploadDocument('professional_cert', (url) {
                final doc = DocumentInfo(
                  name: 'Professional Certificate ${_academicDocs.professionalCertificates.length + 1}',
                  url: url,
                  type: 'pdf',
                  uploadedAt: DateTime.now(),
                );
                setState(() {
                  _academicDocs = AcademicDocuments(
                    academicCertificates: _academicDocs.academicCertificates,
                    professionalCertificates: [..._academicDocs.professionalCertificates, doc],
                    professionalRegistrations: _academicDocs.professionalRegistrations,
                  );
                });
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Professional Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 86, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Professional Registration Numbers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'e.g., EBK, ICPAK, IHRM, etc.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Professional Registrations
            ..._academicDocs.professionalRegistrations.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Color.fromARGB(255, 81, 26, 126)),
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newMap = Map<String, String>.from(_academicDocs.professionalRegistrations);
                        newMap.remove(entry.key);
                        _academicDocs = AcademicDocuments(
                          academicCertificates: _academicDocs.academicCertificates,
                          professionalCertificates: _academicDocs.professionalCertificates,
                          professionalRegistrations: newMap,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Add Professional Registration Button
            ElevatedButton.icon(
              onPressed: () => _showAddProfessionalRegistrationDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Professional Registration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 88, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractsFormsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[5],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('F. Contracts & HR Forms'),
            const SizedBox(height: 24),
            
            // Employment Contract Upload
            _buildUploadButton(
              'Signed Employment Contract / Offer Letter *',
              () => _uploadDocument('employment_contract', (url) {
                setState(() {
                  _contractsForms = ContractsAndForms(
                    employmentContractUrl: url,
                    employeeInfoFormUrl: _contractsForms.employeeInfoFormUrl,
                    ndaUrl: _contractsForms.ndaUrl,
                    codeOfConductAcknowledged: _contractsForms.codeOfConductAcknowledged,
                    dataProtectionConsentGiven: _contractsForms.dataProtectionConsentGiven,
                    consentDate: _contractsForms.consentDate,
                  );
                });
              }),
              _contractsForms.employmentContractUrl,
            ),
            const SizedBox(height: 24),
            
            // Employee Info Form Upload
            _buildUploadButton(
              'Employee Information Form *',
              () => _uploadDocument('employee_info_form', (url) {
                setState(() {
                  _contractsForms = ContractsAndForms(
                    employmentContractUrl: _contractsForms.employmentContractUrl,
                    employeeInfoFormUrl: url,
                    ndaUrl: _contractsForms.ndaUrl,
                    codeOfConductAcknowledged: _contractsForms.codeOfConductAcknowledged,
                    dataProtectionConsentGiven: _contractsForms.dataProtectionConsentGiven,
                    consentDate: _contractsForms.consentDate,
                  );
                });
              }),
              _contractsForms.employeeInfoFormUrl,
            ),
            const SizedBox(height: 24),
            
            // NDA Upload (Optional)
            _buildUploadButton(
              'Confidentiality / NDA (if applicable)',
              () => _uploadDocument('nda', (url) {
                setState(() {
                  _contractsForms = ContractsAndForms(
                    employmentContractUrl: _contractsForms.employmentContractUrl,
                    employeeInfoFormUrl: _contractsForms.employeeInfoFormUrl,
                    ndaUrl: url,
                    codeOfConductAcknowledged: _contractsForms.codeOfConductAcknowledged,
                    dataProtectionConsentGiven: _contractsForms.dataProtectionConsentGiven,
                    consentDate: _contractsForms.consentDate,
                  );
                });
              }),
              _contractsForms.ndaUrl,
            ),
            const SizedBox(height: 24),
            
            // Code of Conduct Acknowledgment
            Card(
              child: CheckboxListTile(
                title: const Text('Code of Conduct Acknowledged *'),
                subtitle: const Text('I have read and understood the company code of conduct'),
                value: _contractsForms.codeOfConductAcknowledged,
                onChanged: (value) {
                  setState(() {
                    _contractsForms = ContractsAndForms(
                      employmentContractUrl: _contractsForms.employmentContractUrl,
                      employeeInfoFormUrl: _contractsForms.employeeInfoFormUrl,
                      ndaUrl: _contractsForms.ndaUrl,
                      codeOfConductAcknowledged: value ?? false,
                      dataProtectionConsentGiven: _contractsForms.dataProtectionConsentGiven,
                      consentDate: _contractsForms.consentDate,
                    );
                  });
                },
                activeColor: const Color.fromARGB(255, 86, 26, 126),
              ),
            ),
            const SizedBox(height: 16),
            
            // Data Protection Consent
            Card(
              child: CheckboxListTile(
                title: const Text('Data Protection Consent (Kenya Data Protection Act) *'),
                subtitle: const Text('I consent to the processing of my personal data as per the Data Protection Act'),
                value: _contractsForms.dataProtectionConsentGiven,
                onChanged: (value) {
                  setState(() {
                    _contractsForms = ContractsAndForms(
                      employmentContractUrl: _contractsForms.employmentContractUrl,
                      employeeInfoFormUrl: _contractsForms.employeeInfoFormUrl,
                      ndaUrl: _contractsForms.ndaUrl,
                      codeOfConductAcknowledged: _contractsForms.codeOfConductAcknowledged,
                      dataProtectionConsentGiven: value ?? false,
                      consentDate: value == true ? DateTime.now() : null,
                    );
                  });
                },
                activeColor: const Color.fromARGB(255, 84, 26, 126),
              ),
            ),
            
            if (_contractsForms.dataProtectionConsentGiven && _contractsForms.consentDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16),
                child: Text(
                  'Consent given on: ${DateFormat('dd/MM/yyyy HH:mm').format(_contractsForms.consentDate!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsInsuranceStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[6],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('G. Benefits & Insurance'),
            const SizedBox(height: 24),
            
            const Text(
              'NHIF Dependants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // NHIF Dependants List
            ..._benefitsInsurance.nhifDependants.asMap().entries.map((entry) {
              final dependant = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color.fromARGB(255, 83, 26, 126)),
                  title: Text(dependant.name),
                  subtitle: Text('${dependant.relationship}${dependant.dateOfBirth != null ? ' - ${DateFormat('dd/MM/yyyy').format(dependant.dateOfBirth!)}' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newList = List<Dependant>.from(_benefitsInsurance.nhifDependants);
                        newList.removeAt(entry.key);
                        _benefitsInsurance = BenefitsInsurance(
                          nhifDependants: newList,
                          medicalInsuranceFormUrl: _benefitsInsurance.medicalInsuranceFormUrl,
                          beneficiaries: _benefitsInsurance.beneficiaries,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Add Dependant Button
            ElevatedButton.icon(
              onPressed: () => _showAddDependantDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add NHIF Dependant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 83, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            // Medical Insurance Form Upload
            _buildUploadButton(
              'Medical Insurance Enrolment Form',
              () => _uploadDocument('medical_insurance', (url) {
                setState(() {
                  _benefitsInsurance = BenefitsInsurance(
                    nhifDependants: _benefitsInsurance.nhifDependants,
                    medicalInsuranceFormUrl: url,
                    beneficiaries: _benefitsInsurance.beneficiaries,
                  );
                });
              }),
              _benefitsInsurance.medicalInsuranceFormUrl,
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Beneficiaries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Beneficiaries List
            ..._benefitsInsurance.beneficiaries.asMap().entries.map((entry) {
              final beneficiary = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.account_circle, color: Color(0xFF1A237E)),
                  title: Text(beneficiary.name),
                  subtitle: Text('${beneficiary.relationship} - ${beneficiary.percentage}%\n${beneficiary.contact}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newList = List<Beneficiary>.from(_benefitsInsurance.beneficiaries);
                        newList.removeAt(entry.key);
                        _benefitsInsurance = BenefitsInsurance(
                          nhifDependants: _benefitsInsurance.nhifDependants,
                          medicalInsuranceFormUrl: _benefitsInsurance.medicalInsuranceFormUrl,
                          beneficiaries: newList,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Total Percentage Display
            if (_benefitsInsurance.beneficiaries.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _getBeneficiaryTotalPercentage() == 100 
                      ? Colors.green.shade50 
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: _getBeneficiaryTotalPercentage() == 100 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Percentage:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_getBeneficiaryTotalPercentage()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getBeneficiaryTotalPercentage() == 100 
                            ? Colors.green 
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Add Beneficiary Button
            ElevatedButton.icon(
              onPressed: () => _showAddBeneficiaryDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Beneficiary'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 83, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkToolsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[7],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('H. Work Tools & Access'),
            const SizedBox(height: 24),
            
            // Work Email
            TextFormField(
              initialValue: _workTools.workEmail,
              decoration: _inputDecoration('Work Email Address'),
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Usually created by IT
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // HRIS Profile Status
            Card(
              child: SwitchListTile(
                title: const Text('HRIS / Payroll System Profile Created'),
                subtitle: const Text('Has your profile been set up in the HRIS system?'),
                value: _workTools.hrisProfileCreated,
                onChanged: (value) {
                  setState(() {
                    _workTools = WorkToolsAccess(
                      workEmail: _workTools.workEmail,
                      hrisProfileCreated: value,
                      systemAccessGranted: _workTools.systemAccessGranted,
                      issuedEquipment: _workTools.issuedEquipment,
                    );
                  });
                },
                activeThumbColor: const Color.fromARGB(255, 83, 26, 126),
              ),
            ),
            const SizedBox(height: 16),
            
            // System Access Status
            Card(
              child: SwitchListTile(
                title: const Text('Access to Internal Systems Granted'),
                subtitle: const Text('Have you been given access to required systems?'),
                value: _workTools.systemAccessGranted,
                onChanged: (value) {
                  setState(() {
                    _workTools = WorkToolsAccess(
                      workEmail: _workTools.workEmail,
                      hrisProfileCreated: _workTools.hrisProfileCreated,
                      systemAccessGranted: value,
                      issuedEquipment: _workTools.issuedEquipment,
                    );
                  });
                },
                activeThumbColor: const Color.fromARGB(255, 83, 26, 126),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Issued Equipment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track laptops, phones, PPE, and other issued items',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Issued Equipment List
            ..._workTools.issuedEquipment.asMap().entries.map((entry) {
              final equipment = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.devices, color: Color.fromARGB(255, 86, 26, 126)),
                  title: Text(equipment.itemName),
                  subtitle: Text('S/N: ${equipment.serialNumber}${equipment.issuedDate != null ? '\nIssued: ${DateFormat('dd/MM/yyyy').format(equipment.issuedDate!)}' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        final newList = List<IssuedEquipment>.from(_workTools.issuedEquipment);
                        newList.removeAt(entry.key);
                        _workTools = WorkToolsAccess(
                          workEmail: _workTools.workEmail,
                          hrisProfileCreated: _workTools.hrisProfileCreated,
                          systemAccessGranted: _workTools.systemAccessGranted,
                          issuedEquipment: newList,
                        );
                      });
                    },
                  ),
                ),
              );
            }),
            
            // Add Equipment Button
            ElevatedButton.icon(
              onPressed: () => _showAddEquipmentDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Issued Equipment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 84, 26, 126),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED CODE
  double _getBeneficiaryTotalPercentage() {
    return _benefitsInsurance.beneficiaries.fold(
      0.0,
      (total, beneficiary) => total + beneficiary.percentage,
    );
  }

  Future<void> _uploadDocument(String docType, Function(String) onUploadComplete) async {
    try {
      _logger.i('Starting document upload for type: $docType');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        _logger.d('File selected: ${file.name} (${file.size} bytes)');
        
        if (!_validateFileSize(file)) {
          _logger.w('File size validation failed');
          return;
        }

        setState(() {
          _isUploadingFile = true;
        });

        _logger.i('Uploading file to storage...');
        
        // CORRECTED: Use uploadEmployeeDocument with named parameters
        final downloadUrl = await _storageService.uploadEmployeeDocument(
          employeeName: _personalInfo.fullName.isNotEmpty 
              ? _personalInfo.fullName 
              : 'temp_${DateTime.now().millisecondsSinceEpoch}',
          fieldName: docType,
          file: file,
        );
        
        _logger.i('File uploaded successfully. URL: $downloadUrl');
        onUploadComplete(downloadUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _logger.d('File selection cancelled by user');
      }
    } catch (e) {
      _logger.e('Error uploading file', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  void _showAddProfessionalRegistrationDialog() {
    final bodyController = TextEditingController();
    final numberController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Professional Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                labelText: 'Registration Body (e.g., EBK, ICPAK)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (bodyController.text.isNotEmpty && numberController.text.isNotEmpty) {
                setState(() {
                  final newMap = Map<String, String>.from(_academicDocs.professionalRegistrations);
                  newMap[bodyController.text] = numberController.text;
                  _academicDocs = AcademicDocuments(
                    academicCertificates: _academicDocs.academicCertificates,
                    professionalCertificates: _academicDocs.professionalCertificates,
                    professionalRegistrations: newMap,
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 83, 26, 126),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddDependantDialog() {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    DateTime? selectedDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add NHIF Dependant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: relationshipController,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Select date',
                      style: TextStyle(
                        color: selectedDate != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && relationshipController.text.isNotEmpty) {
                  setState(() {
                    final newList = List<Dependant>.from(_benefitsInsurance.nhifDependants);
                    newList.add(Dependant(
                      name: nameController.text,
                      relationship: relationshipController.text,
                      dateOfBirth: selectedDate,
                    ));
                    _benefitsInsurance = BenefitsInsurance(
                      nhifDependants: newList,
                      medicalInsuranceFormUrl: _benefitsInsurance.medicalInsuranceFormUrl,
                      beneficiaries: _benefitsInsurance.beneficiaries,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 86, 26, 126),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBeneficiaryDialog() {
    final nameController = TextEditingController();
    final relationshipController = TextEditingController();
    final contactController = TextEditingController();
    final percentageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Beneficiary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: percentageController,
                decoration: const InputDecoration(
                  labelText: 'Percentage (%)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && 
                  relationshipController.text.isNotEmpty &&
                  contactController.text.isNotEmpty &&
                  percentageController.text.isNotEmpty) {
                final percentage = double.tryParse(percentageController.text) ?? 0;
                final currentTotal = _getBeneficiaryTotalPercentage();
                
                if (currentTotal + percentage > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Total percentage cannot exceed 100%'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                setState(() {
                  final newList = List<Beneficiary>.from(_benefitsInsurance.beneficiaries);
                  newList.add(Beneficiary(
                    name: nameController.text,
                    relationship: relationshipController.text,
                    contact: contactController.text,
                    percentage: percentage,
                  ));
                  _benefitsInsurance = BenefitsInsurance(
                    nhifDependants: _benefitsInsurance.nhifDependants,
                    medicalInsuranceFormUrl: _benefitsInsurance.medicalInsuranceFormUrl,
                    beneficiaries: newList,
                  );
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 86, 26, 126),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddEquipmentDialog() {
    final itemNameController = TextEditingController();
    final serialNumberController = TextEditingController();
    DateTime? issuedDate;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Issued Equipment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: itemNameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name (e.g., Laptop, Phone)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serialNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Serial Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        issuedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Issue Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      issuedDate != null
                          ? DateFormat('dd/MM/yyyy').format(issuedDate!)
                          : 'Select date',
                      style: TextStyle(
                        color: issuedDate != null ? Colors.black : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (itemNameController.text.isNotEmpty && serialNumberController.text.isNotEmpty) {
                  setState(() {
                    final newList = List<IssuedEquipment>.from(_workTools.issuedEquipment);
                    newList.add(IssuedEquipment(
                      itemName: itemNameController.text,
                      serialNumber: serialNumberController.text,
                      issuedDate: issuedDate,
                    ));
                    _workTools = WorkToolsAccess(
                      workEmail: _workTools.workEmail,
                      hrisProfileCreated: _workTools.hrisProfileCreated,
                      systemAccessGranted: _workTools.systemAccessGranted,
                      issuedEquipment: newList,
                    );
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 84, 26, 126),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // UI Helper widgets
  Widget _buildStepContainer({required Widget form}) {
    return Container(
      color: Colors.grey.shade50,
      child: form,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color.fromARGB(255, 86, 26, 126),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildUploadButton(String label, VoidCallback onPressed, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isUploadingFile ? null : onPressed,
          icon: _isUploadingFile
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(url != null ? Icons.check_circle : Icons.upload_file),
          label: Text(
            _isUploadingFile
                ? 'Uploading...'
                : (url != null ? 'File Uploaded' : 'Choose File'),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: url != null ? Colors.green : const Color.fromARGB(255, 83, 26, 126),
            side: BorderSide(
              color: url != null ? Colors.green : const Color.fromARGB(255, 83, 26, 126),
            ),
          ),
        ),
        if (url != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'File uploaded successfully',
              style: TextStyle(fontSize: 12, color: Colors.green.shade700),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _logger.i('EmployeeOnboardingWizard disposed');
    _pageController.dispose();
    super.dispose();
  }
}