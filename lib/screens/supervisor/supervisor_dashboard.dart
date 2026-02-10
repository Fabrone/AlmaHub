import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'hours_entry_dialog.dart';
import 'dart:async';

/// Supervisor Dashboard
/// Allows supervisors to:
/// - View employees under their supervision/department
/// - Monitor employee details and monthly hours worked
/// - Forward approved hours to the Accountant for payroll processing
/// 
/// For Admin/HR/Accountant roles:
/// - View all employees across all departments
/// - Additional "Department" column in the table
class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  String? _supervisorDepartment;
  String? _supervisorName;
  String? _currentUserRole;
  bool _isLoadingSupervisorInfo = true;
  String _searchQuery = '';
  
  // Selected month and year for hours tracking
  DateTime _selectedMonth = DateTime.now();
  
  // Track selected employees for forwarding
  final Set<String> _selectedEmployees = {};
  bool _isForwarding = false;

  // Logger for debugging
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
    _logger.i('=== SUPERVISOR DASHBOARD INITIALIZED ===');
    _loadCurrentUserRoleAndInfo();
  }

  /// Load current user's role and information
  Future<void> _loadCurrentUserRoleAndInfo() async {
    if (_currentUser == null) {
      _logger.e('No current user found');
      setState(() => _isLoadingSupervisorInfo = false);
      return;
    }

    _logger.i('Loading user info for: ${_currentUser.email}');

    try {
      // Find user document by UID in Users collection
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: _currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _logger.w('User not found in Users collection');
        setState(() => _isLoadingSupervisorInfo = false);
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      
      _currentUserRole = userData['role'] ?? 'Employee';

      _logger.i('Current user role: $_currentUserRole');

      // If user is Supervisor, load their department
      if (_currentUserRole == 'Supervisor') {
        await _loadSupervisorDepartment();
      } else {
        // For Admin/HR/Accountant, set name from user data
        _supervisorName = userData['fullname'] ?? userData['fullName'] ?? 'Unknown';
      }

      setState(() => _isLoadingSupervisorInfo = false);

    } catch (e, stackTrace) {
      _logger.e('Error loading user info', error: e, stackTrace: stackTrace);
      setState(() => _isLoadingSupervisorInfo = false);
    }
  }

  /// Load supervisor's department from Supervisors collection
  Future<void> _loadSupervisorDepartment() async {
    try {
      _logger.i('Loading supervisor department for UID: ${_currentUser!.uid}');

      // Query Supervisors collection by UID
      final supervisorQuery = await _firestore
          .collection('Supervisors')
          .where('uid', isEqualTo: _currentUser.uid)
          .limit(1)
          .get();

      if (supervisorQuery.docs.isEmpty) {
        _logger.w('Supervisor document not found');
        return;
      }

      final supervisorData = supervisorQuery.docs.first.data();
      
      setState(() {
        _supervisorDepartment = supervisorData['department'];
        _supervisorName = supervisorData['fullname'];
      });

      _logger.i('Supervisor loaded: $_supervisorName, Department: $_supervisorDepartment');

    } catch (e, stackTrace) {
      _logger.e('Error loading supervisor department', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if current user can access this dashboard
  bool _canAccessDashboard() {
    return _currentUserRole != null && 
           (_currentUserRole == 'Supervisor' || 
            _currentUserRole == 'Admin' || 
            _currentUserRole == 'HR' || 
            _currentUserRole == 'Accountant');
  }

  /// Check if current user should see all departments
  bool _shouldShowAllDepartments() {
    return _currentUserRole == 'Admin' || 
           _currentUserRole == 'HR' || 
           _currentUserRole == 'Accountant';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSupervisorInfo) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 123, 31, 162),
          ),
        ),
      );
    }

    if (!_canAccessDashboard()) {
      return _buildAccessDeniedScreen();
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 235, 245),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDepartmentHeader(),
                  _buildStatsCards(),
                  _buildEmployeeTable(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedEmployees.isNotEmpty
          ? _buildForwardButton()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 123, 31, 162),
      elevation: 2,
      title: Text(
        _shouldShowAllDepartments() 
            ? '$_currentUserRole Dashboard - All Departments'
            : 'Supervisor Dashboard',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: _showSearchDialog,
          tooltip: 'Search Employees',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            _logger.i('Refreshing dashboard');
            setState(() {});
          },
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDepartmentHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 123, 31, 162),
            Color.fromARGB(255, 156, 39, 176),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _shouldShowAllDepartments() ? Icons.admin_panel_settings : Icons.supervisor_account,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shouldShowAllDepartments() ? '$_currentUserRole View' : 'Department Supervisor',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _supervisorName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (!_shouldShowAllDepartments() && _supervisorDepartment != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.business,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _supervisorDepartment!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_shouldShowAllDepartments())
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.domain,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'All Departments',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectorCard(double cardWidth) {
    return GestureDetector(
      onTap: _showMonthPickerDialog,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.symmetric(
          horizontal: cardWidth * 0.05,
          vertical: 8.0,
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
                color: const Color.fromARGB(255, 156, 39, 176).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.calendar_month,
                color: const Color.fromARGB(255, 156, 39, 176),
                size: (cardWidth * 0.08).clamp(16.0, 22.0),
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
                    DateFormat('MMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                      fontSize: (cardWidth * 0.055).clamp(12.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 123, 31, 162),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Viewing Period',
                    style: TextStyle(
                      fontSize: (cardWidth * 0.045).clamp(10.0, 12.0),
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: const Color.fromARGB(255, 123, 31, 162),
              size: (cardWidth * 0.08).clamp(18.0, 24.0),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPickerDialog() {
    final List<DateTime> months = [];
    final now = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: Color.fromARGB(255, 123, 31, 162),
            ),
            SizedBox(width: 12),
            Text('Select Viewing Period'),
          ],
        ),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final isSelected = month.month == _selectedMonth.month &&
                  month.year == _selectedMonth.year;
              
              return ListTile(
                selected: isSelected,
                selectedTileColor: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.calendar_today,
                  color: isSelected
                      ? const Color.fromARGB(255, 123, 31, 162)
                      : Colors.grey,
                ),
                title: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? const Color.fromARGB(255, 123, 31, 162)
                        : Colors.black87,
                  ),
                ),
                onTap: () {
                  _logger.i('Month changed to: ${DateFormat('MMMM yyyy').format(month)}');
                  setState(() {
                    _selectedMonth = month;
                    _selectedEmployees.clear();
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    _logger.d('Building stats cards for month: ${DateFormat('MMM yyyy').format(_selectedMonth)}');
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getEmployeesDataStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          if (snapshot.hasError) {
            _logger.e('Error in stats stream', error: snapshot.error);
          }
          return const SizedBox.shrink();
        }

        final employees = snapshot.data!;
        final totalEmployees = employees.length;
        
        // Calculate total hours for selected month
        double totalHours = 0;
        int employeesWithHours = 0;
        
        for (var employee in employees) {
          final hoursWorked = _getMonthlyHours(employee);
          if (hoursWorked > 0) {
            totalHours += hoursWorked;
            employeesWithHours++;
          }
        }

        final avgHours = totalEmployees > 0 ? totalHours / totalEmployees : 0;

        _logger.d('Stats: Total=$totalEmployees, TotalHours=$totalHours, AvgHours=$avgHours, WithHours=$employeesWithHours');

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final cardWidth = (screenWidth - (screenWidth * 0.04 * 2) - (screenWidth * 0.015 * 4)) / 5;
            final spacing = screenWidth * 0.015;
            
            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMonthSelectorCard(cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Team Members',
                      totalEmployees.toString(),
                      const Color.fromARGB(255, 123, 31, 162),
                      Icons.people,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Hours',
                      NumberFormat('#,##0.0').format(totalHours),
                      const Color.fromARGB(255, 2, 136, 209),
                      Icons.access_time,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Avg Hours/Employee',
                      NumberFormat('#,##0.0').format(avgHours),
                      const Color.fromARGB(255, 46, 125, 50),
                      Icons.timeline,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Employees Logged',
                      employeesWithHours.toString(),
                      const Color.fromARGB(255, 255, 152, 0),
                      Icons.check_circle,
                      cardWidth,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, double cardWidth) {
    final iconSize = (cardWidth * 0.08).clamp(16.0, 22.0);
    final valueSize = (cardWidth * 0.055).clamp(12.0, 16.0);
    final titleSize = (cardWidth * 0.045).clamp(10.0, 12.0);
    final horizontalPadding = cardWidth * 0.05;
    final verticalPadding = 8.0;
    
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
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 123, 31, 162),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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

  Widget _buildEmployeeTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
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
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTableHeader(screenWidth),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getEmployeesDataStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _logger.e('Error in employee stream', error: snapshot.error);
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Color.fromARGB(255, 123, 31, 162),
                      ),
                    );
                  }

                  final allEmployees = snapshot.data ?? [];
                  _logger.i('Loaded ${allEmployees.length} employees');

                  // Apply search filter
                  final employees = _searchQuery.isEmpty
                      ? allEmployees
                      : allEmployees.where((employee) {
                          final fullName = (employee['fullName'] ?? '').toString().toLowerCase();
                          final email = (employee['email'] ?? '').toString().toLowerCase();
                          final jobTitle = (employee['jobTitle'] ?? '').toString().toLowerCase();
                          final department = (employee['department'] ?? '').toString().toLowerCase();
                          
                          return fullName.contains(_searchQuery) ||
                                 email.contains(_searchQuery) ||
                                 jobTitle.contains(_searchQuery) ||
                                 department.contains(_searchQuery);
                        }).toList();

                  if (employees.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No results found for "$_searchQuery"'
                                : _shouldShowAllDepartments()
                                    ? 'No employees found in any department'
                                    : 'No employees in your department',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
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

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 50,
                      dataRowMinHeight: 45,
                      dataRowMaxHeight: 45,
                      showCheckboxColumn: true,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      columnSpacing: 24,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color.fromARGB(255, 123, 31, 162),
                      ),
                      dataTextStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      columns: [
                        const DataColumn(label: Text('No.')),
                        const DataColumn(label: Text('Full Name')),
                        const DataColumn(label: Text('Email')),
                        const DataColumn(label: Text('Job Title')),
                        if (_shouldShowAllDepartments())
                          const DataColumn(label: Text('Department')),
                        const DataColumn(label: Text('Employment Type')),
                        const DataColumn(label: Text('Hours Worked')),
                        const DataColumn(label: Text('Performance %')),
                        const DataColumn(label: Text('Status')),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: employees.asMap().entries.map((entry) {
                        final index = entry.key;
                        final employee = entry.value;
                        
                        final uid = employee['uid'] ?? '';
                        final fullName = employee['fullName'] ?? '-';
                        final email = employee['email'] ?? '-';
                        final jobTitle = employee['jobTitle'] ?? '-';
                        final department = employee['department'] ?? '-';
                        final employmentType = employee['employmentType'] ?? '-';
                        final hoursWorked = _getMonthlyHours(employee);
                        final status = employee['status'] ?? 'draft';
                        final performancePercent = _calculatePerformancePercentage(hoursWorked);

                        final isSelected = _selectedEmployees.contains(uid);

                        _logger.d('Row $index: $fullName - Hours: $hoursWorked, Status: $status');

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedEmployees.add(uid);
                              } else {
                                _selectedEmployees.remove(uid);
                              }
                            });
                            _logger.d('Employee ${selected == true ? "selected" : "deselected"}: $fullName');
                          },
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Text(
                                  jobTitle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (_shouldShowAllDepartments())
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    department,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Color.fromARGB(255, 123, 31, 162),
                                    ),
                                  ),
                                ),
                              ),
                            DataCell(_buildEmploymentTypeBadge(employmentType)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: hoursWorked > 0
                                      ? const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hoursWorked > 0
                                      ? '${NumberFormat('#,##0.0').format(hoursWorked)} hrs'
                                      : 'Not logged',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: hoursWorked > 0
                                        ? const Color.fromARGB(255, 123, 31, 162)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(_buildPerformanceBadge(performancePercent)),
                            DataCell(_buildStatusBadge(status)),
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  size: 20,
                                  color: Color.fromARGB(255, 123, 31, 162),
                                ),
                                onPressed: () {
                                  _logger.i('Log hours for: $uid ($fullName)');
                                  _showHoursEntryDialog(uid, fullName, department);
                                },
                                tooltip: 'Log Hours',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(double screenWidth) {
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 123, 31, 162),
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
              child: Icon(
                Icons.people,
                size: logoSize * 0.6,
                color: const Color.fromARGB(255, 123, 31, 162),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shouldShowAllDepartments() 
                      ? 'All Department Employees'
                      : 'Department Employees',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shouldShowAllDepartments()
                      ? 'Manage hours and employee information across all departments'
                      : 'Manage hours and employee information for $_supervisorDepartment',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedEmployees.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedEmployees.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTypeBadge(String type) {
    Color color;
    IconData icon;
    
    switch (type.toLowerCase()) {
      case 'permanent':
      case 'full-time':
        color = const Color.fromARGB(255, 46, 125, 50);
        icon = Icons.work;
        break;
      case 'part-time':
        color = const Color.fromARGB(255, 2, 136, 209);
        icon = Icons.access_time;
        break;
      case 'contract':
        color = const Color.fromARGB(255, 255, 152, 0);
        icon = Icons.description;
        break;
      case 'casual':
      case 'intern':
        color = const Color.fromARGB(255, 123, 31, 162);
        icon = Icons.school;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            type,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceBadge(double percentage) {
    Color color;
    IconData icon;
    
    if (percentage >= 90) {
      color = const Color.fromARGB(255, 46, 125, 50);
      icon = Icons.trending_up;
    } else if (percentage >= 70) {
      color = const Color.fromARGB(255, 2, 136, 209);
      icon = Icons.trending_flat;
    } else if (percentage >= 50) {
      color = const Color.fromARGB(255, 255, 152, 0);
      icon = Icons.trending_down;
    } else {
      color = Colors.red;
      icon = Icons.warning;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Approved';
        break;
      case 'submitted':
        color = Colors.orange;
        text = 'Pending';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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

  Widget _buildForwardButton() {
    return FloatingActionButton.extended(
      onPressed: _isForwarding ? null : _forwardHoursToAccountant,
      backgroundColor: _isForwarding
          ? Colors.grey.shade400
          : const Color.fromARGB(255, 123, 31, 162),
      foregroundColor: Colors.white,
      icon: _isForwarding
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.send),
      label: Text(
        _isForwarding
            ? 'Forwarding...'
            : 'Forward to Accountant (${_selectedEmployees.length})',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Get employees data stream - fetches from Departments collection
  Stream<List<Map<String, dynamic>>> _getEmployeesDataStream() async* {
    _logger.i('=== Getting Employees Data Stream ===');
    _logger.i('Selected month: ${DateFormat('MMM yyyy').format(_selectedMonth)}');
    
    try {
      if (_shouldShowAllDepartments()) {
        // Admin/HR/Accountant: Get all departments
        _logger.i('Fetching all departments for $_currentUserRole');
        
        await for (final deptSnapshot in _firestore.collection('Departments').snapshots()) {
          final List<Map<String, dynamic>> allEmployees = [];
          
          for (final deptDoc in deptSnapshot.docs) {
            final deptData = deptDoc.data();
            final deptName = deptDoc.id;
            final members = deptData['members'] as Map<String, dynamic>? ?? {};
            
            _logger.d('Processing department: $deptName with ${members.length} members');
            
            for (final memberEntry in members.entries) {
              final uid = memberEntry.key;
              final memberData = memberEntry.value as Map<String, dynamic>?;
              
              if (memberData == null) continue;
              
              // Fetch additional employee details from EmployeeDetails
              final employeeDetails = await _getEmployeeDetails(uid);
              
              allEmployees.add({
                'uid': uid,
                'fullName': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
                'email': memberData['email'] ?? 'Unknown',
                'department': deptName,
                ...employeeDetails,
              });
            }
          }
          
          _logger.i('Total employees across all departments: ${allEmployees.length}');
          yield allEmployees;
        }
      } else {
        // Supervisor: Get only their department
        if (_supervisorDepartment == null) {
          _logger.w('Supervisor department is null');
          yield [];
          return;
        }
        
        _logger.i('Fetching department: $_supervisorDepartment');
        
        await for (final deptSnapshot in _firestore
            .collection('Departments')
            .doc(_supervisorDepartment)
            .snapshots()) {
          
          if (!deptSnapshot.exists) {
            _logger.w('Department document does not exist: $_supervisorDepartment');
            yield [];
            continue;
          }
          
          final deptData = deptSnapshot.data()!;
          final members = deptData['members'] as Map<String, dynamic>? ?? {};
          
          _logger.d('Department $_supervisorDepartment has ${members.length} members');
          
          final List<Map<String, dynamic>> employees = [];
          
          for (final memberEntry in members.entries) {
            final uid = memberEntry.key;
            final memberData = memberEntry.value as Map<String, dynamic>?;
            
            if (memberData == null) continue;
            
            // Fetch additional employee details
            final employeeDetails = await _getEmployeeDetails(uid);
            
            employees.add({
              'uid': uid,
              'fullName': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
              'email': memberData['email'] ?? 'Unknown',
              'department': _supervisorDepartment!,
              ...employeeDetails,
            });
          }
          
          _logger.i('Loaded ${employees.length} employees for department: $_supervisorDepartment');
          yield employees;
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error in getEmployeesDataStream', error: e, stackTrace: stackTrace);
      yield [];
    }
  }

  Future<Map<String, dynamic>> _getEmployeeDetails(String uid) async {
    _logger.d('=== 🔍 GETTING EMPLOYEE DETAILS ===');
    _logger.d('UID: $uid');
    
    try {
      // Try EmployeeDetails first
      _logger.d('   Searching EmployeeDetails collection...');
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      String? documentId;
      String? collectionName;
      Map<String, dynamic>? data;

      if (employeeQuery.docs.isNotEmpty) {
        documentId = employeeQuery.docs.first.id;
        collectionName = 'EmployeeDetails';
        data = employeeQuery.docs.first.data();
        _logger.i('   ✅ Found in EmployeeDetails, Doc ID: $documentId');
      } else {
        // Try Draft collection
        _logger.d('   Not in EmployeeDetails, searching Draft collection...');
        final draftQuery = await _firestore
            .collection('Draft')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();

        if (draftQuery.docs.isNotEmpty) {
          documentId = draftQuery.docs.first.id;
          collectionName = 'Draft';
          data = draftQuery.docs.first.data();
          _logger.i('   ✅ Found in Draft, Doc ID: $documentId');
        }
      }

      if (data == null) {
        _logger.w('   ⚠️ Employee not found in either collection for UID: $uid');
        return {
          'jobTitle': '-',
          'employmentType': '-',
          'status': 'draft',
          'hoursWorked': {},
        };
      }

      // Extract hours worked with proper type handling
      Map<String, dynamic> hoursWorked = {};
      final hoursWorkedRaw = data['hoursWorked'];
      
      _logger.d('   📊 Hours Worked Raw Type: ${hoursWorkedRaw.runtimeType}');
      _logger.d('   📊 Hours Worked Raw Value: $hoursWorkedRaw');
      
      if (hoursWorkedRaw != null) {
        if (hoursWorkedRaw is Map<String, dynamic>) {
          hoursWorked = hoursWorkedRaw;
          _logger.d('   ✅ Hours worked is Map<String, dynamic>');
        } else if (hoursWorkedRaw is Map) {
          hoursWorked = Map<String, dynamic>.from(hoursWorkedRaw);
          _logger.d('   🔄 Converted hours worked to Map<String, dynamic>');
        }
      }

      _logger.d('   📊 Final Hours Worked: $hoursWorked');
      _logger.d('   📊 Hours Worked Keys: ${hoursWorked.keys.toList()}');

      final details = {
        'jobTitle': data['employmentDetails']?['jobTitle'] ?? 
                  data['employmentInfo']?['jobTitle'] ?? '-',
        'employmentType': data['employmentDetails']?['employmentType'] ?? 
                        data['employmentInfo']?['employmentType'] ?? '-',
        'status': data['status'] ?? (collectionName == 'Draft' ? 'draft' : 'submitted'),
        'hoursWorked': hoursWorked,
        'documentId': documentId,
        'collectionName': collectionName,
      };

      _logger.i('   ✅ Employee details retrieved successfully');
      _logger.d('   Details: $details');
      return details;

    } catch (e, stackTrace) {
      _logger.e('❌ Error fetching employee details for UID: $uid', error: e, stackTrace: stackTrace);
      return {
        'jobTitle': '-',
        'employmentType': '-',
        'status': 'unknown',
        'hoursWorked': {},
      };
    }
  }

  double _getMonthlyHours(Map<String, dynamic> employeeData) {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final hoursData = employeeData['hoursWorked'];
    
    _logger.d('=== 📊 GETTING MONTHLY HOURS ===');
    _logger.d('Employee: ${employeeData['fullName']}');
    _logger.d('Month Key: $monthKey');
    _logger.d('Hours Data Type: ${hoursData.runtimeType}');
    _logger.d('Hours Data: $hoursData');
    
    // Handle null or non-map hoursData
    if (hoursData == null) {
      _logger.d('   ℹ️ Hours data is null, returning 0.0');
      return 0.0;
    }
    
    // Convert to proper Map type
    final Map<String, dynamic> hoursMap;
    if (hoursData is Map<String, dynamic>) {
      hoursMap = hoursData;
      _logger.d('   ✅ Hours data is Map<String, dynamic>');
    } else if (hoursData is Map) {
      // Convert LinkedMap or other Map types to Map<String, dynamic>
      hoursMap = Map<String, dynamic>.from(hoursData);
      _logger.d('   🔄 Converted Map to Map<String, dynamic>');
    } else {
      _logger.w('   ⚠️ Hours data is not a Map (type: ${hoursData.runtimeType}), returning 0.0');
      return 0.0;
    }
    
    _logger.d('   📋 Hours Map Keys: ${hoursMap.keys.toList()}');
    
    if (!hoursMap.containsKey(monthKey)) {
      _logger.d('   ℹ️ Month key "$monthKey" not found in hours map');
      _logger.d('   Available months: ${hoursMap.keys.join(", ")}');
      return 0.0;
    }
    
    final value = hoursMap[monthKey];
    _logger.d('   ✅ Found value for $monthKey: $value (type: ${value.runtimeType})');
    
    if (value is num) {
      final hours = value.toDouble();
      _logger.i('   ✅✅ Returning hours: $hours for ${employeeData['fullName']}');
      return hours;
    }
    
    _logger.w('   ⚠️ Value is not a number (type: ${value.runtimeType}), returning 0.0');
    return 0.0;
  }

  /// Calculate performance percentage based on hours worked
  /// Assumes 160 hours/month as 100% (standard full-time)
  double _calculatePerformancePercentage(double hoursWorked) {
    const standardMonthlyHours = 160.0; // 40 hours/week * 4 weeks
    if (hoursWorked <= 0) return 0.0;
    return (hoursWorked / standardMonthlyHours * 100).clamp(0.0, 100.0);
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
            hintText: 'Enter name, email, job title, or department...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 123, 31, 162),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardHoursToAccountant() async {
    if (_selectedEmployees.isEmpty) {
      _logger.w('No employees selected for forwarding');
      return;
    }

    _logger.i('=== FORWARDING HOURS TO ACCOUNTANT ===');
    _logger.i('Selected employees: ${_selectedEmployees.length}');
    _logger.i('Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}');

    setState(() => _isForwarding = true);

    try {
      final employeeDataList = <Map<String, dynamic>>[];
      
      // Get current employees data
      final currentEmployees = await _getEmployeesDataStream().first;
      
      for (final uid in _selectedEmployees) {
        final employee = currentEmployees.firstWhere(
          (e) => e['uid'] == uid,
          orElse: () => <String, dynamic>{},
        );
        
        if (employee.isNotEmpty) {
          final hoursWorked = _getMonthlyHours(employee);
          
          _logger.d('Forwarding employee: ${employee['fullName']} - Hours: $hoursWorked');
          
          employeeDataList.add({
            'employeeId': uid,
            'fullName': employee['fullName'] ?? 'Unknown',
            'email': employee['email'] ?? 'Unknown',
            'department': employee['department'] ?? 'Unknown',
            'jobTitle': employee['jobTitle'] ?? 'Unknown',
            'hoursWorked': hoursWorked,
            'month': DateFormat('yyyy-MM').format(_selectedMonth),
            'monthDisplay': DateFormat('MMMM yyyy').format(_selectedMonth),
          });
        }
      }

      _logger.i('Forwarding ${employeeDataList.length} employees to HoursForwarded collection');

      await _firestore.collection('HoursForwarded').add({
        'supervisorId': _currentUser!.uid,
        'supervisorName': _supervisorName,
        'supervisorEmail': _currentUser.email,
        'supervisorRole': _currentUserRole,
        'department': _supervisorDepartment ?? 'All Departments',
        'month': DateFormat('yyyy-MM').format(_selectedMonth),
        'monthDisplay': DateFormat('MMMM yyyy').format(_selectedMonth),
        'employees': employeeDataList,
        'forwardedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'totalEmployees': employeeDataList.length,
        'totalHours': employeeDataList.fold<double>(
          0,
          (total, emp) => total + (emp['hoursWorked'] as double),
        ),
      });

      _logger.i('✅ Hours forwarded successfully to Accountant');

      if (!mounted) return;

      setState(() {
        _selectedEmployees.clear();
        _isForwarding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully forwarded hours for ${employeeDataList.length} employees to Accountant',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

    } catch (e, stackTrace) {
      _logger.e('❌ Error forwarding hours', error: e, stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _isForwarding = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error forwarding hours: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showHoursEntryDialog(String uid, String employeeName, String department) {
    _logger.i('Opening hours entry dialog for: $employeeName (UID: $uid)');
    
    showDialog(
      context: context,
      builder: (context) => HoursEntryDialog(
        employeeId: uid,
        employeeName: employeeName,
        department: department,
      ),
    ).then((saved) {
      if (saved == true) {
        _logger.i('Hours saved, refreshing dashboard');
        setState(() {});
      } else {
        _logger.d('Hours dialog closed without saving');
      }
    });
  }

  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 123, 31, 162),
              Color.fromARGB(255, 156, 39, 176),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Only Supervisors, Admins, HR, and Accountants can access this dashboard.\n\nYour current role: ${_currentUserRole ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromARGB(255, 123, 31, 162),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}