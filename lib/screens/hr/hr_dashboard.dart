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
  String _searchQuery = '';

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
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 92, 4, 126),
        elevation: 2,
        title: const Text(
          'HR Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900, // Extra bold
            color: Color.fromARGB(255, 237, 236, 239),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Search icon button
          IconButton(
            icon: const Icon(Icons.search, color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('Search button clicked');
              _showSearchDialog();
            },
            tooltip: 'Search Employees',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCards(),
          Expanded(
            child: _buildEmployeeTable(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingDownloadButton(),
    );
  }

  void _showSearchDialog() {
    _logger.d('Opening search dialog');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, email, or ID...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _logger.d('Search query changed: $value');
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: (value) {
            _logger.i('Search submitted: $value');
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('Search cleared');
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.i('Search applied: $_searchQuery');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 81, 3, 130),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingDownloadButton() {
    return FloatingActionButton.extended(
      onPressed: _isDownloading ? null : _downloadExcel,
      backgroundColor: _isDownloading ? Colors.grey.shade400 : const Color.fromARGB(255, 86, 10, 119),
      foregroundColor: Colors.white,
      icon: _isDownloading
          ? const SizedBox(
              width: 20,
              height: 20,
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
        style: const TextStyle(fontWeight: FontWeight.w600),
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
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          _logger.d('Stats data not yet available');
          return const SizedBox.shrink();
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            _logger.d('Stats cards screen width: $screenWidth px');
            
            // Calculate card width as 30% of screen width
            final cardWidth = screenWidth * 0.30;
            // Calculate spacing dynamically (5% total spacing divided by gaps)
            final spacing = screenWidth * 0.025;
            
            _logger.d('Card width: $cardWidth px, Spacing: $spacing px');
            
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Total in View', total, const Color.fromARGB(255, 209, 72, 221), Icons.people, cardWidth),
                    SizedBox(width: spacing),
                    if (_statusFilter == 'draft')
                      _buildStatCard('Drafts', drafts, const Color.fromARGB(255, 213, 97, 217), Icons.drafts, cardWidth)
                    else
                      _buildStatCard('Submitted', submitted, Colors.orange, Icons.pending, cardWidth),
                    SizedBox(width: spacing),
                    _buildFilterCard(cardWidth),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon, double cardWidth) {
    // Adaptive sizing based on card width - reduced sizes for compact cards
    final iconSize = (cardWidth * 0.08).clamp(16.0, 22.0);
    final valueSize = (cardWidth * 0.07).clamp(14.0, 20.0);
    final titleSize = (cardWidth * 0.045).clamp(10.0, 12.0);
    final horizontalPadding = cardWidth * 0.05;
    final verticalPadding = 8.0; // Fixed smaller vertical padding
    
    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(cardWidth * 0.04),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
          SizedBox(width: cardWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 86, 10, 119)
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(double cardWidth) {
    final iconSize = (cardWidth * 0.06).clamp(14.0, 18.0);
    final textSize = (cardWidth * 0.05).clamp(11.0, 13.0);
    final horizontalPadding = cardWidth * 0.05;
    final verticalPadding = 8.0; // Fixed smaller vertical padding to match stat cards
    
    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _statusFilter,
        decoration: InputDecoration(
          labelText: 'Filter',
          labelStyle: TextStyle(
            fontSize: textSize,
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 6,
            horizontal: horizontalPadding * 0.8,
          ),
          isDense: true,
        ),
        style: TextStyle(fontSize: textSize, color: Colors.black87),
        icon: Icon(Icons.arrow_drop_down, size: iconSize + 2),
        items: [
          DropdownMenuItem(
            value: 'draft',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drafts, size: iconSize, color: const Color.fromARGB(255, 207, 113, 225)),
                SizedBox(width: horizontalPadding * 0.4),
                Flexible(
                  child: Text(
                    'Draft',
                    style: TextStyle(fontSize: textSize),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'submitted',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, size: iconSize, color: Colors.orange),
                SizedBox(width: horizontalPadding * 0.4),
                Flexible(
                  child: Text(
                    'Submitted',
                    style: TextStyle(fontSize: textSize),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
    );
  }

  Widget _buildEmployeeTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        _logger.d('Employee table screen width: $screenWidth px');
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTableHeader(screenWidth),
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

                    final allEmployees = snapshot.data!.docs;
                    _logger.i('Loaded ${allEmployees.length} employees from ${_getCollectionName()} collection');

                    // Apply search filter
                    final employees = _searchQuery.isEmpty
                        ? allEmployees
                        : allEmployees.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final fullName = (data['personalInfo']?['fullName'] ?? '').toString().toLowerCase();
                            final email = (data['personalInfo']?['email'] ?? '').toString().toLowerCase();
                            final nationalId = (data['personalInfo']?['nationalIdOrPassport'] ?? '').toString().toLowerCase();
                            final docId = doc.id.toLowerCase();
                            
                            return fullName.contains(_searchQuery) ||
                                   email.contains(_searchQuery) ||
                                   nationalId.contains(_searchQuery) ||
                                   docId.contains(_searchQuery);
                          }).toList();

                    if (_searchQuery.isNotEmpty) {
                      _logger.d('Search active: "$_searchQuery" - Found ${employees.length} matches');
                    }

                    if (employees.isEmpty) {
                      _logger.w('No employees found ${_searchQuery.isNotEmpty ? "matching search" : "in ${_getCollectionName()} collection"}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : (_statusFilter == 'draft' ? Icons.drafts : Icons.inbox),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found for "$_searchQuery"'
                                  : (_statusFilter == 'draft' 
                                      ? 'No draft applications found'
                                      : 'No submitted applications found'),
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  _logger.d('Clearing search filter');
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    // Always show table with horizontal and vertical scrolling
                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 50,
                          dataRowMinHeight: 45,
                          dataRowMaxHeight: 45,
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey.shade100,
                          ),
                          columnSpacing: 24,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color.fromARGB(255, 86, 10, 119)
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          columns: [
                            const DataColumn(label: Text('No.')),
                            const DataColumn(label: Text('Full Name')),
                            const DataColumn(label: Text('Email')),
                            const DataColumn(label: Text('Phone')),
                            const DataColumn(label: Text('National ID')),
                            const DataColumn(label: Text('Job Title')),
                            const DataColumn(label: Text('Department')),
                            const DataColumn(label: Text('Employment Type')),
                            const DataColumn(label: Text('Start Date')),
                            const DataColumn(label: Text('KRA PIN')),
                            const DataColumn(label: Text('NSSF Number')),
                            const DataColumn(label: Text('NHIF Number')),
                            const DataColumn(label: Text('Basic Salary')),
                            const DataColumn(label: Text('Bank Name')),
                            const DataColumn(label: Text('Account Number')),
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
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      data['personalInfo']?['fullName'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      data['personalInfo']?['email'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(data['personalInfo']?['phoneNumber'] ?? '-')),
                                DataCell(Text(data['personalInfo']?['nationalIdOrPassport'] ?? '-')),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      data['employmentDetails']?['jobTitle'] ?? '-',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(data['employmentDetails']?['department'] ?? '-')),
                                DataCell(Text(data['employmentDetails']?['employmentType'] ?? '-')),
                                DataCell(Text(
                                  data['employmentDetails']?['startDate'] != null
                                      ? DateFormat('dd/MM/yyyy').format(
                                          (data['employmentDetails']['startDate'] as Timestamp).toDate(),
                                        )
                                      : '-',
                                )),
                                DataCell(Text(data['statutoryDocs']?['kraPinNumber'] ?? '-')),
                                DataCell(Text(data['statutoryDocs']?['nssfNumber'] ?? '-')),
                                DataCell(Text(data['statutoryDocs']?['nhifNumber'] ?? '-')),
                                DataCell(Text(
                                  data['payrollDetails']?['basicSalary'] != null
                                      ? 'KES ${NumberFormat('#,###').format(data['payrollDetails']['basicSalary'])}'
                                      : '-',
                                )),
                                DataCell(Text(data['payrollDetails']?['bankDetails']?['bankName'] ?? '-')),
                                DataCell(Text(data['payrollDetails']?['bankDetails']?['accountNumber'] ?? '-')),
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
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(double screenWidth) {
    // Adaptive sizing based on actual screen width
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);
    final badgeTextSize = (screenWidth * 0.009).clamp(11.0, 14.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color:  Color.fromARGB(255, 86, 10, 119),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'JV',
                style: TextStyle(
                  fontSize: logoSize * 0.45,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 86, 10, 119),
                ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JV Almacis',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Employee Onboarding Records',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusFilter == 'draft' ? 'DRAFT VIEW' : 'SUBMITTED VIEW',
              style: TextStyle(
                fontSize: badgeTextSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
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