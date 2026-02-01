import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/employee/employee_onboarding_wizard.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ ADD THIS IMPORT
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
    
    // ✅ Get current user's UID
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      _logger.e('No authenticated user found');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Please log in to view your applications',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    final uid = currentUser.uid;
    _logger.i('Querying collections for user UID: $uid');
    
    return StreamBuilder<QuerySnapshot>(
      // ✅ FIXED: Query ALL drafts, filter client-side
      stream: _firestore
          .collection('Draft')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, draftSnapshot) {
        // Log draft collection status
        if (draftSnapshot.hasError) {
          _logger.e('Error loading Draft collection', error: draftSnapshot.error);
        }
        
        if (draftSnapshot.connectionState == ConnectionState.waiting) {
          _logger.d('Waiting for Draft collection data...');
        } else if (draftSnapshot.hasData) {
          _logger.d('Draft collection loaded: ${draftSnapshot.data?.docs.length ?? 0} total documents');
        }
        
        return StreamBuilder<QuerySnapshot>(
          // ✅ FIXED: Query ALL submitted applications, filter client-side
          stream: _firestore
              .collection('EmployeeDetails')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, submittedSnapshot) {
            // Log submitted collection status
            if (submittedSnapshot.hasError) {
              _logger.e('Error loading EmployeeDetails collection', error: submittedSnapshot.error);
            }
            
            if (submittedSnapshot.connectionState == ConnectionState.waiting) {
              _logger.d('Waiting for EmployeeDetails collection data...');
            } else if (submittedSnapshot.hasData) {
              _logger.d('EmployeeDetails collection loaded: ${submittedSnapshot.data?.docs.length ?? 0} total documents');
            }
            
            // Handle errors from either stream
            if (draftSnapshot.hasError && submittedSnapshot.hasError) {
              _logger.e('Both collections failed to load');
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
                      'Please check your permissions or try again later',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        _logger.i('Retry button clicked - rebuilding widget');
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Show loading if either stream is still loading
            if (draftSnapshot.connectionState == ConnectionState.waiting ||
                submittedSnapshot.connectionState == ConnectionState.waiting) {
              _logger.d('Still waiting for data...');
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // ✅ FILTER CLIENT-SIDE: Only include documents that belong to current user
            final List<QueryDocumentSnapshot> allApplications = [];
            
            if (draftSnapshot.hasData) {
              final userDrafts = draftSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['uid'] == uid;
              }).toList();
              
              allApplications.addAll(userDrafts);
              _logger.d('Filtered ${userDrafts.length} drafts for user (from ${draftSnapshot.data!.docs.length} total)');
            }
            
            if (submittedSnapshot.hasData) {
              final userSubmissions = submittedSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['uid'] == uid;
              }).toList();
              
              allApplications.addAll(userSubmissions);
              _logger.d('Filtered ${userSubmissions.length} submissions for user (from ${submittedSnapshot.data!.docs.length} total)');
            }
            
            // Sort by creation date (most recent first)
            allApplications.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTimestamp = aData['createdAt'] as Timestamp?;
              final bTimestamp = bData['createdAt'] as Timestamp?;
              
              if (aTimestamp == null || bTimestamp == null) return 0;
              return bTimestamp.compareTo(aTimestamp); // Descending order
            });
            
            _logger.i('Total applications for current user: ${allApplications.length}');

            if (allApplications.isEmpty) {
              _logger.w('No applications found for current user');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No applications yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click the button below to start your onboarding',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: allApplications.length,
              itemBuilder: (context, index) {
                final doc = allApplications[index];
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'draft';
                
                _logger.d('Rendering application ${index + 1}: ${data['personalInfo']?['fullName'] ?? 'Unknown'} (Status: $status)');

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      _logger.i('Application card clicked: ${doc.id}');
                      _logger.d('Opening application with status: $status');
                      _openApplication(doc.id, status);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['personalInfo']?['fullName'] ?? 'Application',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A237E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['employmentDetails']?['jobTitle'] ?? 'Position not specified',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Created: ${_formatDate(data['createdAt'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 24),
                              if (data['updatedAt'] != null) ...[
                                Icon(Icons.update, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Updated: ${_formatDate(data['updatedAt'])}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (status == 'submitted' && data['submittedAt'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.send, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(
                                  'Submitted: ${_formatDate(data['submittedAt'])}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = (timestamp as Timestamp).toDate();
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      _logger.w('Error formatting date', error: e);
      return 'Invalid date';
    }
  }

  void _openApplication(String docId, String status) {
    _logger.i('Opening application: $docId (Status: $status)');
    
    // Determine which collection to query based on status
    final collection = status == 'draft' ? 'Draft' : 'EmployeeDetails';
    _logger.d('Fetching from $collection collection');
    
    // Fetch the full document data
    _firestore.collection(collection).doc(docId).get().then((docSnapshot) {
      // ✅ CHECK IF WIDGET IS STILL MOUNTED BEFORE USING CONTEXT
      if (!mounted) {
        _logger.w('Widget disposed before document fetch completed');
        return;
      }
      
      if (!docSnapshot.exists) {
        _logger.e('Document not found: $docId in $collection');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      try {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final employee = EmployeeOnboarding.fromMap(data);
        _logger.i('Successfully loaded employee data for: ${employee.personalInfo.fullName}');
        
        // Use the existing _viewOrEditApplication method
        _viewOrEditApplication(employee, docId);
      } catch (e, stackTrace) {
        _logger.e('Error parsing employee data', error: e, stackTrace: stackTrace);
        
        // ✅ CHECK IF WIDGET IS STILL MOUNTED BEFORE SHOWING SNACKBAR
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }).catchError((error) {
      _logger.e('Error fetching document', error: error);
      
      // ✅ CHECK IF WIDGET IS STILL MOUNTED BEFORE SHOWING SNACKBAR
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading application: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
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