import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../models/employee_onboarding_models.dart';
import '../../services/excel_generation_service.dart';
import '../../services/excel_download_service.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all';
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
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
            label: Text(_isDownloading ? 'Generating...' : 'Download Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('employee_onboarding').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 100);
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final submitted = docs.where((d) => d['status'] == 'submitted').length;
        final approved = docs.where((d) => d['status'] == 'approved').length;
        final drafts = docs.where((d) => d['status'] == 'draft').length;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _buildStatCard('Total Applications', total, Colors.blue, Icons.people),
              const SizedBox(width: 16),
              _buildStatCard('Submitted', submitted, Colors.orange, Icons.pending),
              const SizedBox(width: 16),
              _buildStatCard('Approved', approved, Colors.green, Icons.check_circle),
              const SizedBox(width: 16),
              _buildStatCard('Drafts', drafts, Colors.grey, Icons.drafts),
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
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final employees = snapshot.data!.docs;

                if (employees.isEmpty) {
                  return const Center(
                    child: Text(
                      'No applications found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade100,
                    ),
                    columns: const [
                      DataColumn(label: Text('No.')),
                      DataColumn(label: Text('Full Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Job Title')),
                      DataColumn(label: Text('Department')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Submitted')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: employees.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;
                      
                      return DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(data['personalInfo']?['fullName'] ?? '-')),
                          DataCell(Text(data['personalInfo']?['email'] ?? '-')),
                          DataCell(Text(data['employmentDetails']?['jobTitle'] ?? '-')),
                          DataCell(Text(data['employmentDetails']?['department'] ?? '-')),
                          DataCell(_buildStatusBadge(data['status'] ?? 'draft')),
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
                                  onPressed: () => _viewEmployee(doc.id),
                                  tooltip: 'View Details',
                                ),
                                if (data['status'] == 'submitted')
                                  IconButton(
                                    icon: const Icon(Icons.check, size: 20, color: Colors.green),
                                    onPressed: () => _approveEmployee(doc.id),
                                    tooltip: 'Approve',
                                  ),
                                if (data['status'] == 'submitted')
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20, color: Colors.red),
                                    onPressed: () => _rejectEmployee(doc.id),
                                    tooltip: 'Reject',
                                  ),
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
              },
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'draft', child: Text('Drafts')),
              DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (value) {
              setState(() => _statusFilter = value!);
            },
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    Query query = _firestore.collection('employee_onboarding').orderBy('createdAt', descending: true);
    
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }
    
    return query.snapshots();
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
        color: color.withValues(alpha: 0.1),
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
    setState(() => _isDownloading = true);
    
    try {
      // Fetch all employee data
      final snapshot = await _firestore.collection('employee_onboarding').get();
      final employees = snapshot.docs
          .map((doc) => EmployeeOnboarding.fromMap(doc.data()))
          .toList();

      // Create excel with summary
      final excel = Excel.createExcel();
      
      // Add summary sheet first
      ExcelGenerationService.addSummarySheet(excel, employees);
      
      // Generate main data and get both filename and bytes
      final result = await ExcelGenerationService.generateEmployeeOnboardingExcel(employees);
      final fileName = result['fileName'] as String;
      final fileBytes = result['fileBytes'] as List<int>?;
      
      if (fileBytes != null) {
        // Use the download service to handle platform-specific download
        await ExcelDownloadService.downloadExcel(
          Uint8List.fromList(fileBytes),
          fileName,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel file downloaded successfully as $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to generate Excel file bytes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating Excel: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _viewEmployee(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Employee Details'),
        content: const Text('Detail view will be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: const Text('Are you sure you want to approve this application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('employee_onboarding').doc(id).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _rejectEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text('Are you sure you want to reject this application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('employee_onboarding').doc(id).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}