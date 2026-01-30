import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/employee/employee_onboarding_wizard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Employee dashboard for viewing and managing their onboarding application
class EmployeeDashboard extends StatefulWidget {
  final String? employeeEmail; // Will be set after authentication

  const EmployeeDashboard({
    super.key,
    this.employeeEmail,
  });

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
    _logger.i('EmployeeDashboard initialized with email: ${widget.employeeEmail}');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building EmployeeDashboard widget');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Application',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            _buildWelcomeBanner(),
            Expanded(
              child: _buildApplicationsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewApplication(),
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.add),
        label: const Text('New Application'),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    _logger.d('Building welcome banner');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to AlmaHub',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your employee onboarding application below',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha:0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    _logger.d('Building applications list stream');
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('employee_onboarding')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error loading applications stream', error: snapshot.error);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading applications',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('Waiting for applications stream data...');
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final applications = snapshot.data?.docs ?? [];
        _logger.i('Loaded ${applications.length} application(s) from Firestore');

        if (applications.isEmpty) {
          _logger.d('No applications found, showing empty state');
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final doc = applications[index];
            _logger.d('Building application card for document ID: ${doc.id}');
            try {
              final data = doc.data() as Map<String, dynamic>;
              final employee = EmployeeOnboarding.fromMap(data);
              _logger.d('Successfully parsed employee data for: ${employee.personalInfo.fullName}');
              
              return _buildApplicationCard(employee, doc.id);
            } catch (e, stackTrace) {
              _logger.e('Error parsing application document ${doc.id}', error: e, stackTrace: stackTrace);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading application: $e'),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    _logger.d('Building empty state widget');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 120,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            'No Applications Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Click the button below to start your\nonboarding application',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _startNewApplication(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              'Start New Application',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(EmployeeOnboarding employee, String docId) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    
    // Calculate completion percentage
    int completedSections = 0;
    int totalSections = 8;
    
    if (employee.personalInfo.fullName.isNotEmpty) completedSections++;
    if (employee.employmentDetails.jobTitle.isNotEmpty) completedSections++;
    if (employee.statutoryDocs.kraPinNumber.isNotEmpty) completedSections++;
    if (employee.payrollDetails.basicSalary > 0) completedSections++;
    if (employee.academicDocs.academicCertificates.isNotEmpty) completedSections++;
    if (employee.contractsForms.codeOfConductAcknowledged) completedSections++;
    if (employee.benefitsInsurance.beneficiaries.isNotEmpty) completedSections++;
    if (employee.workTools.workEmail != null) completedSections++;
    
    final completionPercentage = (completedSections / totalSections * 100).round();
    
    _logger.d('Application card for ${employee.personalInfo.fullName}: '
        'Status=${employee.status}, Completion=$completionPercentage%, DocID=$docId');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _viewOrEditApplication(employee, docId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.personalInfo.fullName.isNotEmpty
                              ? employee.personalInfo.fullName
                              : 'Untitled Application',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employee.employmentDetails.jobTitle.isNotEmpty
                              ? employee.employmentDetails.jobTitle
                              : 'No job title',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(employee.status),
                ],
              ),
              const SizedBox(height: 16),
              
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completion',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        '$completionPercentage%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completionPercentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1A237E),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Metadata row
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.calendar_today,
                    'Created: ${dateFormat.format(employee.createdAt)}',
                  ),
                  if (employee.submittedAt != null)
                    _buildInfoChip(
                      Icons.send,
                      'Submitted: ${dateFormat.format(employee.submittedAt!)}',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _viewOrEditApplication(employee, docId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: employee.status == 'draft'
                        ? const Color(0xFF1A237E)
                        : Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    employee.status == 'draft' ? Icons.edit : Icons.visibility,
                  ),
                  label: Text(
                    employee.status == 'draft'
                        ? 'Continue Editing'
                        : 'View Application',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String text;
    
    switch (status) {
      case 'submitted':
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        text = 'Submitted';
        break;
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        icon = Icons.edit_note;
        text = 'Draft';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _startNewApplication() {
    _logger.i('Starting new application');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmployeeOnboardingWizard(),
      ),
    ).then((_) {
      _logger.d('Returned from new application wizard, refreshing list');
      // Refresh the list when returning
      setState(() {});
    });
  }

  void _viewOrEditApplication(EmployeeOnboarding employee, String docId) {
    _logger.i('Viewing/editing application for ${employee.personalInfo.fullName} '
        '(DocID: $docId, Status: ${employee.status})');
    
    if (employee.status == 'draft') {
      _logger.d('Opening application in edit mode');
      // Allow editing - pass the employee data to the wizard
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmployeeOnboardingWizard(
            existingEmployee: employee,
          ),
        ),
      ).then((_) {
        _logger.d('Returned from editing application, refreshing list');
        setState(() {});
      });
    } else {
      _logger.d('Opening application in view-only mode');
      // View only mode
      _showApplicationDetails(employee);
    }
  }

  void _showApplicationDetails(EmployeeOnboarding employee) {
    _logger.d('Showing application details dialog for ${employee.personalInfo.fullName}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Application Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Name', employee.personalInfo.fullName),
              _buildDetailRow('Email', employee.personalInfo.email),
              _buildDetailRow('Phone', employee.personalInfo.phoneNumber),
              _buildDetailRow('Job Title', employee.employmentDetails.jobTitle),
              _buildDetailRow('Department', employee.employmentDetails.department),
              _buildDetailRow('Status', employee.status.toUpperCase()),
              if (employee.submittedAt != null)
                _buildDetailRow(
                  'Submitted',
                  DateFormat('dd MMM yyyy').format(employee.submittedAt!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('Closing application details dialog');
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logger.i('EmployeeDashboard disposed');
    super.dispose();
  }
}