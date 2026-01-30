import 'dart:async';
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/services/firestore_service.dart';
import 'package:almahub/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

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

  @override
  void initState() {
    super.initState();
    _logger.i('=== EmployeeOnboardingWizard Initialized ===');
    _logger.d('Existing employee data: ${widget.existingEmployee != null ? "YES" : "NO"}');
    _initializeData();
    _loadExistingData();
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Employee Onboarding Form',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
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
                        ? const Color(0xFF1A237E)
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
                  side: const BorderSide(color: Color(0xFF1A237E), width: 2),
                  foregroundColor: const Color(0xFF1A237E),
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
                backgroundColor: const Color(0xFF1A237E),
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
      // REMOVED: Form save here since we're using onChanged for real-time updates
      // _formKeys[_currentStep].currentState?.save();
      
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
      // Note: We're not requiring validation to pass for draft saves
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
                backgroundColor: const Color(0xFF1A237E),
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

  // Step 1: Personal Information
  Widget _buildPersonalInfoStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[0],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('A. Personal Information'),
            const SizedBox(height: 24),
            
            // Full Name - FIXED: Added onChanged
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
            
            // National ID/Passport - FIXED: Added onChanged
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
            
            // Gender - FIXED: Added onChanged
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
            
            // Phone Number - FIXED: Added onChanged
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
            
            // Email - FIXED: Added onChanged
            TextFormField(
              initialValue: _personalInfo.email,
              decoration: _inputDecoration('Email Address *'),
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
            
            // Postal Address - FIXED: Added onChanged
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
            
            // Physical Address - FIXED: Added onChanged
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
            
            // Next of Kin Name - FIXED: Added onChanged
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
            
            // Next of Kin Relationship - FIXED: Added onChanged
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
            
            // Next of Kin Contact - FIXED: Added onChanged
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

  // Template for other steps - implement similarly
  Widget _buildEmploymentDetailsStep() {
    return _buildStepContainer(
      form: Form(
        key: _formKeys[1],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionTitle('B. Employment Details'),
            const SizedBox(height: 24),
            const Text('Note: Add employment detail fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add statutory document fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add payroll fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add academic document fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add contract fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add benefits fields with onChanged callbacks similar to Step 1'),
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
            const Text('Note: Add work tools fields with onChanged callbacks similar to Step 1'),
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
        color: Color(0xFF1A237E),
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
            foregroundColor: url != null ? Colors.green : const Color(0xFF1A237E),
            side: BorderSide(
              color: url != null ? Colors.green : const Color(0xFF1A237E),
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