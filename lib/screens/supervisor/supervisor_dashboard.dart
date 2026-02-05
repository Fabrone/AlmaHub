import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Supervisor Dashboard
/// Allows supervisors to:
/// - View employees under their supervision/department
/// - Monitor employee details and monthly hours worked
/// - Forward approved hours to the Accountant for payroll processing
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
    _loadSupervisorInfo();
  }

  /// Load supervisor information from Firestore
  Future<void> _loadSupervisorInfo() async {
    if (_currentUser == null) {
      _logger.e('No current user found');
      setState(() => _isLoadingSupervisorInfo = false);
      return;
    }

    _logger.i('Loading supervisor info for: ${_currentUser.email}');

    try {
      // Try to find supervisor in EmployeeDetails collection
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('personalInfo.email', isEqualTo: _currentUser.email)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        final data = employeeQuery.docs.first.data();
        final employmentInfo = data['employmentInfo'] as Map<String, dynamic>?;
        final personalInfo = data['personalInfo'] as Map<String, dynamic>?;

        setState(() {
          _supervisorDepartment = employmentInfo?['department'] ?? 'Unknown';
          _supervisorName = personalInfo?['fullName'] ?? 'Unknown';
          _isLoadingSupervisorInfo = false;
        });

        _logger.i('Supervisor loaded: $_supervisorName, Department: $_supervisorDepartment');
        return;
      }

      // If not found, try Draft collection
      final draftQuery = await _firestore
          .collection('Draft')
          .where('personalInfo.email', isEqualTo: _currentUser.email)
          .limit(1)
          .get();

      if (draftQuery.docs.isNotEmpty) {
        final data = draftQuery.docs.first.data();
        final employmentInfo = data['employmentInfo'] as Map<String, dynamic>?;
        final personalInfo = data['personalInfo'] as Map<String, dynamic>?;

        setState(() {
          _supervisorDepartment = employmentInfo?['department'] ?? 'Unknown';
          _supervisorName = personalInfo?['fullName'] ?? 'Unknown';
          _isLoadingSupervisorInfo = false;
        });

        _logger.i('Supervisor loaded from Draft: $_supervisorName, Department: $_supervisorDepartment');
        return;
      }

      // Supervisor not found in either collection
      _logger.w('Supervisor not found in any collection');
      setState(() => _isLoadingSupervisorInfo = false);

    } catch (e) {
      _logger.e('Error loading supervisor info', error: e);
      setState(() => _isLoadingSupervisorInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSupervisorInfo) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_supervisorDepartment == null) {
      return _buildErrorScreen('Unable to load supervisor information');
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 232, 245, 233),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildDepartmentHeader(),
          _buildMonthSelector(),
          _buildStatsCards(),
          Expanded(child: _buildEmployeeTable()),
        ],
      ),
      floatingActionButton: _selectedEmployees.isNotEmpty
          ? _buildForwardButton()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 46, 125, 50),
      elevation: 2,
      title: const Text(
        'Supervisor Dashboard',
        style: TextStyle(
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
            _logger.i('Refreshing supervisor dashboard');
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
            Color.fromARGB(255, 46, 125, 50),
            Color.fromARGB(255, 67, 160, 71),
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
            child: const Icon(
              Icons.supervisor_account,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department Supervisor',
                  style: TextStyle(
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
                        _supervisorDepartment ?? 'Unknown',
                        style: const TextStyle(
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

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month,
            color: Color.fromARGB(255, 46, 125, 50),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'Viewing Hours For:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 46, 125, 50),
                    ),
                  ),
                  PopupMenuButton<DateTime>(
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color.fromARGB(255, 46, 125, 50),
                    ),
                    onSelected: (DateTime newMonth) {
                      _logger.i('Month changed to: ${DateFormat('MMMM yyyy').format(newMonth)}');
                      setState(() {
                        _selectedMonth = newMonth;
                        _selectedEmployees.clear(); // Clear selections when month changes
                      });
                    },
                    itemBuilder: (context) {
                      final List<DateTime> months = [];
                      final now = DateTime.now();
                      
                      // Generate last 12 months
                      for (int i = 0; i < 12; i++) {
                        months.add(DateTime(now.year, now.month - i, 1));
                      }
                      
                      return months.map((month) {
                        return PopupMenuItem<DateTime>(
                          value: month,
                          child: Text(
                            DateFormat('MMMM yyyy').format(month),
                            style: TextStyle(
                              fontWeight: month.month == _selectedMonth.month &&
                                          month.year == _selectedMonth.year
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    _logger.d('Building stats cards for department: $_supervisorDepartment');
    
    return StreamBuilder<QuerySnapshot>(
      stream: _getEmployeesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final employees = snapshot.data!.docs;
        final totalEmployees = employees.length;
        
        // Calculate total hours for selected month
        double totalHours = 0;
        int employeesWithHours = 0;
        
        for (var doc in employees) {
          final data = doc.data() as Map<String, dynamic>;
          final hoursWorked = _getMonthlyHours(data);
          if (hoursWorked > 0) {
            totalHours += hoursWorked;
            employeesWithHours++;
          }
        }

        final avgHours = totalEmployees > 0 ? totalHours / totalEmployees : 0;

        return Container(
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Team Members',
                  totalEmployees.toString(),
                  const Color.fromARGB(255, 46, 125, 50),
                  Icons.people,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Hours',
                  NumberFormat('#,##0.0').format(totalHours),
                  const Color.fromARGB(255, 2, 136, 209),
                  Icons.access_time,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Hours/Employee',
                  NumberFormat('#,##0.0').format(avgHours),
                  const Color.fromARGB(255, 123, 31, 162),
                  Icons.timeline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Employees Logged',
                  employeesWithHours.toString(),
                  const Color.fromARGB(255, 255, 152, 0),
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          _buildTableHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getEmployeesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  _logger.e('Error in employee stream', error: snapshot.error);
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allEmployees = snapshot.data!.docs;
                _logger.i('Loaded ${allEmployees.length} employees in department: $_supervisorDepartment');

                // Apply search filter
                final employees = _searchQuery.isEmpty
                    ? allEmployees
                    : allEmployees.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final fullName = (data['personalInfo']?['fullName'] ?? '').toString().toLowerCase();
                        final email = (data['personalInfo']?['email'] ?? '').toString().toLowerCase();
                        final jobTitle = (data['employmentInfo']?['jobTitle'] ?? '').toString().toLowerCase();
                        
                        return fullName.contains(_searchQuery) ||
                               email.contains(_searchQuery) ||
                               jobTitle.contains(_searchQuery);
                      }).toList();

                if (employees.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 50,
                      dataRowMinHeight: 55,
                      dataRowMaxHeight: 55,
                      showCheckboxColumn: true,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.grey.shade100,
                      ),
                      columnSpacing: 24,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color.fromARGB(255, 46, 125, 50),
                      ),
                      dataTextStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      columns: const [
                        DataColumn(label: Text('No.')),
                        DataColumn(label: Text('Full Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Job Title')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Employment Type')),
                        DataColumn(label: Text('Hours Worked')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: employees.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final data = doc.data() as Map<String, dynamic>;
                        final personalInfo = data['personalInfo'] as Map<String, dynamic>? ?? {};
                        final employmentInfo = data['employmentInfo'] as Map<String, dynamic>? ?? {};
                        
                        final fullName = personalInfo['fullName'] ?? '-';
                        final email = personalInfo['email'] ?? '-';
                        final jobTitle = employmentInfo['jobTitle'] ?? '-';
                        final department = employmentInfo['department'] ?? '-';
                        final employmentType = employmentInfo['employmentType'] ?? '-';
                        final hoursWorked = _getMonthlyHours(data);
                        final status = data['status'] ?? 'draft';

                        final isSelected = _selectedEmployees.contains(doc.id);

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedEmployees.add(doc.id);
                              } else {
                                _selectedEmployees.remove(doc.id);
                              }
                            });
                            _logger.d('Employee ${selected == true ? "selected" : "deselected"}: $fullName');
                          },
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  jobTitle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(department)),
                            DataCell(_buildEmploymentTypeBadge(employmentType)),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: hoursWorked > 0
                                      ? const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.1)
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
                                        ? const Color.fromARGB(255, 46, 125, 50)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(_buildStatusBadge(status)),
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility,
                                  size: 20,
                                  color: Color.fromARGB(255, 46, 125, 50),
                                ),
                                onPressed: () {
                                  _logger.i('View details for: ${doc.id}');
                                  _viewEmployeeDetails(doc.id, data);
                                },
                                tooltip: 'View Details',
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
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 46, 125, 50),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.people,
              size: 28,
              color: Color.fromARGB(255, 46, 125, 50),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Department Employees',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage hours and employee information for ${_supervisorDepartment ?? "your department"}',
                  style: const TextStyle(
                    fontSize: 13,
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
          : const Color.fromARGB(255, 46, 125, 50),
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

  /// Get stream of employees in supervisor's department
  Stream<QuerySnapshot> _getEmployeesStream() {
    _logger.d('Getting employees stream for department: $_supervisorDepartment');
    
    // Query both EmployeeDetails and Draft collections for employees in this department
    return _firestore
        .collection('EmployeeDetails')
        .where('employmentInfo.department', isEqualTo: _supervisorDepartment)
        .snapshots();
  }

  /// Get monthly hours worked for an employee
  double _getMonthlyHours(Map<String, dynamic> employeeData) {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final hoursData = employeeData['hoursWorked'] as Map<String, dynamic>?;
    
    if (hoursData == null || !hoursData.containsKey(monthKey)) {
      return 0.0;
    }
    
    return (hoursData[monthKey] ?? 0).toDouble();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, email, or job title...',
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
              backgroundColor: const Color.fromARGB(255, 46, 125, 50),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _viewEmployeeDetails(String employeeId, Map<String, dynamic> data) {
    _logger.i('=== VIEW EMPLOYEE DETAILS ===');
    _logger.d('Employee ID: $employeeId');
    
    final personalInfo = data['personalInfo'] as Map<String, dynamic>? ?? {};
    final employmentInfo = data['employmentInfo'] as Map<String, dynamic>? ?? {};
    final hoursWorked = _getMonthlyHours(data);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Employee Details - ${personalInfo['fullName'] ?? 'Unknown'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection('Personal Information', [
                _buildDetailRow('Full Name', personalInfo['fullName'] ?? '-'),
                _buildDetailRow('Email', personalInfo['email'] ?? '-'),
                _buildDetailRow('Phone', personalInfo['phoneNumber'] ?? '-'),
              ]),
              const Divider(height: 24),
              _buildDetailSection('Employment Information', [
                _buildDetailRow('Job Title', employmentInfo['jobTitle'] ?? '-'),
                _buildDetailRow('Department', employmentInfo['department'] ?? '-'),
                _buildDetailRow('Employment Type', employmentInfo['employmentType'] ?? '-'),
                _buildDetailRow('Start Date', employmentInfo['startDate'] ?? '-'),
              ]),
              const Divider(height: 24),
              _buildDetailSection(
                'Hours Worked - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                [
                  _buildDetailRow(
                    'Total Hours',
                    hoursWorked > 0
                        ? '${NumberFormat('#,##0.0').format(hoursWorked)} hours'
                        : 'No hours logged',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color.fromARGB(255, 46, 125, 50),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black54),
            ),
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
      // Get employee data for selected employees
      final employeeData = <Map<String, dynamic>>[];
      
      for (final employeeId in _selectedEmployees) {
        final doc = await _firestore
            .collection('EmployeeDetails')
            .doc(employeeId)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final hoursWorked = _getMonthlyHours(data);
          
          employeeData.add({
            'employeeId': employeeId,
            'fullName': data['personalInfo']?['fullName'] ?? 'Unknown',
            'email': data['personalInfo']?['email'] ?? 'Unknown',
            'department': data['employmentInfo']?['department'] ?? 'Unknown',
            'jobTitle': data['employmentInfo']?['jobTitle'] ?? 'Unknown',
            'hoursWorked': hoursWorked,
            'month': DateFormat('yyyy-MM').format(_selectedMonth),
            'monthDisplay': DateFormat('MMMM yyyy').format(_selectedMonth),
          });
        }
      }

      // Create forwarding record in Firestore
      await _firestore.collection('HoursForwarded').add({
        'supervisorId': _currentUser!.uid,
        'supervisorName': _supervisorName,
        'supervisorEmail': _currentUser.email,
        'department': _supervisorDepartment,
        'month': DateFormat('yyyy-MM').format(_selectedMonth),
        'monthDisplay': DateFormat('MMMM yyyy').format(_selectedMonth),
        'employees': employeeData,
        'forwardedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, approved, processed
        'totalEmployees': employeeData.length,
        'totalHours': employeeData.fold<double>(
          0,
          (sum, emp) => sum + (emp['hoursWorked'] as double),
        ),
      });

      _logger.i('✅ Hours forwarded successfully to Accountant');

      if (!mounted) return;

      // Clear selections
      setState(() {
        _selectedEmployees.clear();
        _isForwarding = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully forwarded hours for ${employeeData.length} employees to Accountant',
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

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 46, 125, 50),
              Color.fromARGB(255, 102, 187, 106),
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
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                      foregroundColor: const Color.fromARGB(255, 46, 125, 50),
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