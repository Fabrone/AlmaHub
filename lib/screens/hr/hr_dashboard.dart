import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/services/excel_download_service.dart';
import 'package:almahub/services/excel_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'draft'; // Changed default to 'draft'
  bool _isDownloading = false;
  String? _downloadProgress;

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

  @override
  void initState() {
    super.initState();
    _logger.i('=== HR Dashboard Initialized ===');
    _logger.d('Initial status filter: $_statusFilter');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building HR Dashboard widget');
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildTopBar(),
          _buildStatsCards(),
          Expanded(
            child: _buildEmployeeTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'Employee Onboarding Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _downloadExcel,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _isDownloading
                  ? (_downloadProgress ?? 'Generating...')
                  : 'Download Excel',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              disabledBackgroundColor: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    _logger.d('Building stats cards with filter: $_statusFilter');
    return StreamBuilder<QuerySnapshot>(
      stream: _getStatsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error in stats stream', error: snapshot.error);
          return const SizedBox(height: 100);
        }

        if (!snapshot.hasData) {
          _logger.d('Stats data not yet available');
          return const SizedBox(height: 100);
        }

        final docs = snapshot.data!.docs;
        _logger.d('Stats loaded: ${docs.length} documents in current view');

        // Count based on current filter
        final total = docs.length;
        int submitted = 0;
        int approved = 0;
        int rejected = 0;
        int drafts = 0;

        if (_statusFilter == 'draft') {
          drafts = total;
          _logger.d('Draft view: $drafts drafts');
        } else if (_statusFilter == 'submitted') {
          // For submitted view, count by status in EmployeeDetails collection
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'submitted';
            
            if (status == 'submitted') {
              submitted++;
            } else if (status == 'approved') {
              approved++;
            } else if (status == 'rejected') {
              rejected++;
            }
          }
          _logger.d('Submitted view: $submitted submitted, $approved approved, $rejected rejected');
        }

        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _buildStatCard('Total in View', total, Colors.blue, Icons.people),
              const SizedBox(width: 16),
              if (_statusFilter == 'draft')
                _buildStatCard('Drafts', drafts, Colors.grey, Icons.drafts)
              else ...[
                _buildStatCard('Submitted', submitted, Colors.orange, Icons.pending),
                const SizedBox(width: 16),
                _buildStatCard('Approved', approved, Colors.green, Icons.check_circle),
                const SizedBox(width: 16),
                _buildStatCard('Rejected', rejected, Colors.red, Icons.cancel),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTableFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _logger.e('Error in employee table stream', error: snapshot.error);
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  _logger.d('Waiting for employee data...');
                  return const Center(child: CircularProgressIndicator());
                }

                final employees = snapshot.data!.docs;
                _logger.i('Loaded ${employees.length} employees from ${_getCollectionName()} collection');

                if (employees.isEmpty) {
                  _logger.w('No employees found in ${_getCollectionName()} collection');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _statusFilter == 'draft' ? Icons.drafts : Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusFilter == 'draft' 
                              ? 'No draft applications found'
                              : 'No submitted applications found',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade100,
                    ),
                    columns: [
                      const DataColumn(label: Text('No.')),
                      const DataColumn(label: Text('Full Name')),
                      const DataColumn(label: Text('Email')),
                      const DataColumn(label: Text('Job Title')),
                      const DataColumn(label: Text('Department')),
                      if (_statusFilter == 'submitted') 
                        const DataColumn(label: Text('Status')),
                      const DataColumn(label: Text('Created')),
                      if (_statusFilter == 'submitted')
                        const DataColumn(label: Text('Submitted')),
                      const DataColumn(label: Text('Actions')),
                    ],
                    rows: employees.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      
                      _logger.d('Row ${index + 1}: ${data['personalInfo']?['fullName'] ?? 'Unknown'} (ID: ${doc.id})');
                      
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(data['personalInfo']?['fullName'] ?? '-')),
                          DataCell(Text(data['personalInfo']?['email'] ?? '-')),
                          DataCell(Text(data['employmentDetails']?['jobTitle'] ?? '-')),
                          DataCell(Text(data['employmentDetails']?['department'] ?? '-')),
                          if (_statusFilter == 'submitted')
                            DataCell(_buildStatusBadge(data['status'] ?? 'submitted')),
                          DataCell(Text(
                            data['createdAt'] != null
                                ? DateFormat('dd/MM/yyyy').format(
                                    (data['createdAt'] as Timestamp).toDate(),
                                  )
                                : '-',
                          )),
                          if (_statusFilter == 'submitted')
                            DataCell(Text(
                              data['submittedAt'] != null
                                  ? DateFormat('dd/MM/yyyy').format(
                                      (data['submittedAt'] as Timestamp).toDate(),
                                    )
                                  : '-',
                            )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility, size: 20),
                                  onPressed: () {
                                    _logger.i('View button clicked for employee: ${doc.id}');
                                    _viewEmployee(doc.id);
                                  },
                                  tooltip: 'View Details',
                                ),
                                if (_statusFilter == 'submitted' && data['status'] == 'submitted') ...[
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
                                    onPressed: () {
                                      _logger.i('Approve button clicked for employee: ${doc.id}');
                                      _approveEmployee(doc.id);
                                    },
                                    tooltip: 'Approve',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                                    onPressed: () {
                                      _logger.i('Reject button clicked for employee: ${doc.id}');
                                      _rejectEmployee(doc.id);
                                    },
                                    tooltip: 'Reject',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFilters() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, email, or job title...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _logger.d('Search text changed: $value');
                // Todo: Implement search functionality
              },
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'draft',
                  child: Row(
                    children: [
                      Icon(Icons.drafts, size: 18, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Draft'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'submitted',
                  child: Row(
                    children: [
                      Icon(Icons.send, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Submitted'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                _logger.i('Filter changed from "$_statusFilter" to "$value"');
                setState(() => _statusFilter = value!);
                _logger.d('Now querying ${_getCollectionName()} collection');
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the Firestore collection name based on current filter
  String _getCollectionName() {
    return _statusFilter == 'draft' ? 'Draft' : 'EmployeeDetails';
  }

  /// Stream for stats cards - queries the appropriate collection
  Stream<QuerySnapshot> _getStatsStream() {
    final collectionName = _getCollectionName();
    _logger.d('Getting stats stream from $collectionName collection');
    
    try {
      return _firestore
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (e) {
      _logger.e('Error creating stats stream', error: e);
      rethrow;
    }
  }

  /// Stream for employee table - queries the appropriate collection
  Stream<QuerySnapshot> _getFilteredStream() {
    final collectionName = _getCollectionName();
    _logger.i('Creating filtered stream for $collectionName collection');
    
    try {
      Query query = _firestore
          .collection(collectionName)
          .orderBy('createdAt', descending: true);
      
      _logger.d('Query created successfully for $collectionName');
      return query.snapshots();
    } catch (e) {
      _logger.e('Error creating filtered stream', error: e);
      _logger.e('Collection: $collectionName, Filter: $_statusFilter');
      rethrow;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'submitted':
        color = Colors.orange;
        text = 'Submitted';
        break;
      case 'approved':
        color = Colors.green;
        text = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = 'Draft';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _downloadExcel() async {
    _logger.i('=== EXCEL DOWNLOAD INITIATED ===');
    _logger.d('Current filter: $_statusFilter');
    _logger.d('Collection: ${_getCollectionName()}');
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Fetching data...';
    });
    
    String? downloadedFilePath;
    
    try {
      // 1. Fetch data from appropriate collection
      final collectionName = _getCollectionName();
      _logger.i('Fetching data from $collectionName collection...');
      
      if (mounted) {
        setState(() => _downloadProgress = 'Loading employees...');
      }
      
      final snapshot = await _firestore.collection(collectionName).get();
      _logger.i('Fetched ${snapshot.docs.length} documents from $collectionName');
      
      if (snapshot.docs.isEmpty) {
        _logger.w('No data found in $collectionName collection');
        throw Exception('No employee data found in $collectionName');
      }
      
      // 2. Convert to EmployeeOnboarding objects
      if (mounted) {
        setState(() => _downloadProgress = 'Processing ${snapshot.docs.length} records...');
      }
      
      _logger.d('Converting documents to EmployeeOnboarding objects...');
      final employees = <EmployeeOnboarding>[];
      
      for (var doc in snapshot.docs) {
        try {
          final employee = EmployeeOnboarding.fromMap(doc.data());
          employees.add(employee);
          _logger.d('Converted employee: ${employee.personalInfo.fullName}');
        } catch (e) {
          _logger.e('Error converting document ${doc.id}', error: e);
        }
      }
      
      _logger.i('Successfully converted ${employees.length} employees');

      // 3. Generate Excel file
      if (mounted) {
        setState(() => _downloadProgress = 'Generating Excel...');
      }
      
      _logger.d('Calling Excel generation service...');
      final result = await ExcelGenerationService.generateEmployeeOnboardingExcel(employees);
      final fileName = result['fileName'] as String;
      final fileBytes = result['fileBytes'] as Uint8List;
      final fileSize = result['fileSize'] as int;
      
      _logger.i('Excel file generated: $fileName ($fileSize bytes)');
      
      // 4. Download the file using platform-specific service
      if (mounted) {
        setState(() => _downloadProgress = 'Downloading...');
      }
      
      _logger.d('Initiating download...');
      downloadedFilePath = await ExcelDownloadService.downloadExcel(
        fileBytes,
        fileName,
      );
      
      _logger.i('✅ Excel download completed successfully');
      _logger.d('File path: $downloadedFilePath');
      
      // 5. Show success message
      if (!mounted) return;
      
      final fileReadableSize = ExcelDownloadService.getReadableFileSize(fileSize);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Excel file downloaded successfully!\n$fileName ($fileReadableSize)'
                : 'Excel file downloaded successfully!\nLocation: $downloadedFilePath\nSize: $fileReadableSize',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () async {
                    if (downloadedFilePath != null) {
                      try {
                        _logger.d('Opening file: $downloadedFilePath');
                        await ExcelDownloadService.openFile(downloadedFilePath);
                      } catch (e) {
                        _logger.e('Error opening file', error: e);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open file: $e'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
        ),
      );
      
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR DOWNLOADING EXCEL', error: e, stackTrace: stackTrace);
      
      if (!mounted) return;
      
      String errorMessage = 'Error generating Excel: $e';
      SnackBarAction? action;
      
      if (e.toString().contains('permission')) {
        errorMessage = 'Storage permission denied. Please enable it in Settings.';
        action = SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            _logger.d('Opening app settings...');
            openAppSettings();
          },
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: action,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
      _logger.d('=== EXCEL DOWNLOAD COMPLETED ===');
    }
  }

  void _viewEmployee(String id) {
    _logger.i('=== VIEW EMPLOYEE DETAILS ===');
    _logger.d('Employee ID: $id');
    _logger.d('Collection: ${_getCollectionName()}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employee Details'),
        content: const Text('Detail view will be implemented here'),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('Closing employee details dialog');
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEmployee(String id) async {
    _logger.i('=== APPROVE EMPLOYEE INITIATED ===');
    _logger.d('Employee ID: $id');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: const Text('Are you sure you want to approve this application?'),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('User cancelled approval');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.d('User confirmed approval');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _logger.i('Updating employee status to approved...');
        _logger.d('Collection: EmployeeDetails, Document ID: $id');
        
        await _firestore.collection('EmployeeDetails').doc(id).update({
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _logger.i('✅ Employee approved successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.e('❌ ERROR APPROVING EMPLOYEE', error: e, stackTrace: stackTrace);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error approving application: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      _logger.d('Approval cancelled by user');
    }
  }

  Future<void> _rejectEmployee(String id) async {
    _logger.i('=== REJECT EMPLOYEE INITIATED ===');
    _logger.d('Employee ID: $id');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text('Are you sure you want to reject this application?'),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('User cancelled rejection');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.d('User confirmed rejection');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _logger.i('Updating employee status to rejected...');
        _logger.d('Collection: EmployeeDetails, Document ID: $id');
        
        await _firestore.collection('EmployeeDetails').doc(id).update({
          'status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        _logger.i('✅ Employee rejected successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application rejected'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.e('❌ ERROR REJECTING EMPLOYEE', error: e, stackTrace: stackTrace);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting application: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      _logger.d('Rejection cancelled by user');
    }
  }
}