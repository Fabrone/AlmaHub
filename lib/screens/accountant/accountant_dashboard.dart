import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/services/excel_download_service.dart';
import 'package:almahub/services/excel_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'dart:async';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'draft';
  bool _isDownloading = false;
  String? _downloadProgress;
  String _searchQuery = '';
  
  // Selected month for hours tracking
  DateTime _selectedMonth = DateTime.now();

  // Cache for department lookups
  final Map<String, String> _departmentCache = {};

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
    _logger.i('=== Accountant Dashboard Initialized ===');
    _logger.d('Initial status filter: $_statusFilter');
    _logger.i('Selected month: ${DateFormat('MMM yyyy').format(_selectedMonth)}');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building Accountant Dashboard widget');
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 92, 4, 126),
        elevation: 2,
        title: const Text(
          'Accountant Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 237, 236, 239),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Month selector
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: _showMonthPickerDialog,
            tooltip: 'Select Month',
          ),
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
            child: _buildPayrollTable(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingDownloadButton(),
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

  void _showSearchDialog() {
    _logger.d('Opening search dialog');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, email, department, or account...',
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
      onPressed: _isDownloading ? null : _downloadPayrollExcel,
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
            : 'Download Payroll',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStatsCards() {
    _logger.d('Building stats cards with filter: $_statusFilter');
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getMergedStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error in stats stream', error: snapshot.error);
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          _logger.d('Stats data not yet available');
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!;
        _logger.d('Stats loaded: ${docs.length} documents in current view');

        // Calculate totals
        double totalBasicSalary = 0;
        double totalAllowances = 0;
        double totalDeductions = 0;
        double totalNetPay = 0;
        double totalHours = 0;
        double totalOvertime = 0;
        int employeeCount = docs.length;
        final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final payrollData = data['payrollDetails'] as Map<String, dynamic>?;
          
          // Get hours and overtime for selected month
          final hoursWorked = data['hoursWorked'] as Map<String, dynamic>? ?? {};
          final daysWorked = data['daysWorked'] as Map<String, dynamic>? ?? {};
          
          final monthlyHours = (hoursWorked[monthKey] ?? 0).toDouble();
          final monthlyDays = (daysWorked[monthKey] ?? 0).toInt();
          
          totalHours += monthlyHours;
          
          // Calculate overtime
          if (monthlyHours > 0 && monthlyDays > 0) {
            final avgHoursPerDay = monthlyHours / monthlyDays;
            const standardHoursPerDay = 8.0;
            const maxHoursPerDay = 12.0;
            
            double overtimePerDay = 0.0;
            if (avgHoursPerDay > standardHoursPerDay) {
              if (avgHoursPerDay <= maxHoursPerDay) {
                overtimePerDay = avgHoursPerDay - standardHoursPerDay;
              } else {
                overtimePerDay = maxHoursPerDay - standardHoursPerDay;
              }
            }
            
            totalOvertime += (overtimePerDay * monthlyDays);
          }
          
          if (payrollData != null) {
            final basicSalary = (payrollData['basicSalary'] ?? 0).toDouble();
            totalBasicSalary += basicSalary;
            
            // Calculate allowances
            final allowances = payrollData['allowances'] as Map<String, dynamic>? ?? {};
            double empAllowances = 0;
            allowances.forEach((key, value) {
              empAllowances += (value ?? 0).toDouble();
            });
            totalAllowances += empAllowances;
            
            // Calculate deductions
            final deductions = payrollData['deductions'] as Map<String, dynamic>? ?? {};
            double empDeductions = 0;
            deductions.forEach((key, value) {
              empDeductions += (value ?? 0).toDouble();
            });
            totalDeductions += empDeductions;
            
            // Calculate net pay
            totalNetPay += (basicSalary + empAllowances - empDeductions);
          }
        }

        _logger.d('Payroll totals - Employees: $employeeCount, Hours: $totalHours, Overtime: $totalOvertime, Basic: $totalBasicSalary, Net: $totalNetPay');

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            _logger.d('Stats cards screen width: $screenWidth px');
            
            // Calculate card width - 7 stat cards across
            final cardWidth = (screenWidth - (screenWidth * 0.04 * 2) - (screenWidth * 0.015 * 6)) / 7;
            final spacing = screenWidth * 0.015;
            
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
                    _buildStatCard(
                      'Employees',
                      employeeCount.toString(),
                      const Color.fromARGB(255, 209, 72, 221),
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
                      'Overtime Hours',
                      NumberFormat('#,##0.0').format(totalOvertime),
                      const Color.fromARGB(255, 255, 152, 0),
                      Icons.schedule,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Basic Salary',
                      'KES ${NumberFormat('#,###').format(totalBasicSalary)}',
                      const Color.fromARGB(255, 46, 125, 50),
                      Icons.account_balance_wallet,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Allowances',
                      'KES ${NumberFormat('#,###').format(totalAllowances)}',
                      const Color.fromARGB(255, 76, 175, 80),
                      Icons.add_circle,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Deductions',
                      'KES ${NumberFormat('#,###').format(totalDeductions)}',
                      const Color.fromARGB(255, 211, 47, 47),
                      Icons.remove_circle,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Net Pay',
                      'KES ${NumberFormat('#,###').format(totalNetPay)}',
                      const Color.fromARGB(255, 123, 31, 162),
                      Icons.payments,
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
                    color: const Color.fromARGB(255, 86, 10, 119),
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

  Widget _buildPayrollTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        _logger.d('Payroll table screen width: $screenWidth px');
        
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
                child: StreamBuilder<List<DocumentSnapshot>>(
                  stream: _getMergedStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      _logger.e('Error in payroll table stream', error: snapshot.error);
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      _logger.d('Waiting for payroll data...');
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allEmployees = snapshot.data ?? [];
                    _logger.i('Loaded ${allEmployees.length} employees (Filter: $_statusFilter)');

                    // Apply search filter
                    final employees = _searchQuery.isEmpty
                        ? allEmployees
                        : allEmployees.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final fullName = (data['personalInfo']?['fullName'] ?? '').toString().toLowerCase();
                            final email = (data['personalInfo']?['email'] ?? '').toString().toLowerCase();
                            final uid = data['uid'] ?? '';
                            final cachedDept = _departmentCache[uid] ?? '';
                            final accountNumber = (data['payrollDetails']?['bankDetails']?['accountNumber'] ?? '').toString().toLowerCase();
                            final bankName = (data['payrollDetails']?['bankDetails']?['bankName'] ?? '').toString().toLowerCase();
                            
                            return fullName.contains(_searchQuery) ||
                                   email.contains(_searchQuery) ||
                                   cachedDept.toLowerCase().contains(_searchQuery) ||
                                   accountNumber.contains(_searchQuery) ||
                                   bankName.contains(_searchQuery);
                          }).toList();

                    // Sort employees by department alphabetically, then by name
                    employees.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      
                      final uidA = aData['uid'] ?? '';
                      final uidB = bData['uid'] ?? '';
                      
                      final deptA = (_departmentCache[uidA] ?? '-').toLowerCase();
                      final deptB = (_departmentCache[uidB] ?? '-').toLowerCase();
                      
                      // First sort by department
                      final deptCompare = deptA.compareTo(deptB);
                      if (deptCompare != 0) return deptCompare;
                      
                      // Then sort by name within same department
                      final nameA = (aData['personalInfo']?['fullName'] ?? '').toString().toLowerCase();
                      final nameB = (bData['personalInfo']?['fullName'] ?? '').toString().toLowerCase();
                      return nameA.compareTo(nameB);
                    });

                    if (_searchQuery.isNotEmpty) {
                      _logger.d('Search active: "$_searchQuery" - Found ${employees.length} matches');
                    }

                    _logger.d('Employees sorted by department, then by name');

                    if (employees.isEmpty) {
                      _logger.w('No employees found ${_searchQuery.isNotEmpty ? "matching search" : "in collection"}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found for "$_searchQuery"'
                                  : 'No employee payroll records found',
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

                    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

                    return FutureBuilder<List<DataRow>>(
                      future: _buildDataRows(employees, monthKey),
                      builder: (context, rowSnapshot) {
                        if (rowSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (rowSnapshot.hasError) {
                          return Center(child: Text('Error: ${rowSnapshot.error}'));
                        }

                        final rows = rowSnapshot.data ?? [];

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
                                color: Color.fromARGB(255, 86, 10, 119),
                              ),
                              dataTextStyle: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                              columns: const [
                                DataColumn(label: Text('No.')),
                                DataColumn(label: Text('Full Name')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Department')),
                                DataColumn(label: Text('Hours')),
                                DataColumn(label: Text('Overtime')),
                                DataColumn(label: Text('Basic Salary')),
                                DataColumn(label: Text('Housing')),
                                DataColumn(label: Text('Transport')),
                                DataColumn(label: Text('Other Allow.')),
                                DataColumn(label: Text('Total Allow.')),
                                DataColumn(label: Text('Loans')),
                                DataColumn(label: Text('SACCO')),
                                DataColumn(label: Text('Advances')),
                                DataColumn(label: Text('Total Deduc.')),
                                DataColumn(label: Text('Net Pay')),
                                DataColumn(label: Text('Bank Name')),
                                DataColumn(label: Text('Account Number')),
                                DataColumn(label: Text('Branch')),
                                DataColumn(label: Text('M-Pesa')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: rows,
                            ),
                          ),
                        );
                      },
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

  Future<List<DataRow>> _buildDataRows(List<DocumentSnapshot> employees, String monthKey) async {
    final List<DataRow> rows = [];

    for (int index = 0; index < employees.length; index++) {
      final doc = employees[index];
      final data = doc.data() as Map<String, dynamic>;
      final personalInfo = data['personalInfo'] as Map<String, dynamic>? ?? {};
      final payrollData = data['payrollDetails'] as Map<String, dynamic>? ?? {};
      final hoursWorked = data['hoursWorked'] as Map<String, dynamic>? ?? {};
      final daysWorked = data['daysWorked'] as Map<String, dynamic>? ?? {};
      
      // Extract employee information
      final fullName = personalInfo['fullName'] ?? '-';
      final email = personalInfo['email'] ?? '-';
      final uid = data['uid'] ?? '';
      
      // Get department from cache or fetch it
      String department = _departmentCache[uid] ?? '';
      if (department.isEmpty) {
        department = await _getEmployeeDepartment(uid);
        _departmentCache[uid] = department;
      }
      
      // Get current month's hours and days
      final monthlyHours = (hoursWorked[monthKey] ?? 0).toDouble();
      final monthlyDays = (daysWorked[monthKey] ?? 0).toInt();
      
      // Calculate overtime
      double overtimeHours = 0.0;
      if (monthlyHours > 0 && monthlyDays > 0) {
        final avgHoursPerDay = monthlyHours / monthlyDays;
        const standardHoursPerDay = 8.0;
        const maxHoursPerDay = 12.0;
        
        double overtimePerDay = 0.0;
        if (avgHoursPerDay > standardHoursPerDay) {
          if (avgHoursPerDay <= maxHoursPerDay) {
            overtimePerDay = avgHoursPerDay - standardHoursPerDay;
          } else {
            overtimePerDay = maxHoursPerDay - standardHoursPerDay;
          }
        }
        
        overtimeHours = overtimePerDay * monthlyDays;
      }
      
      // Extract payroll information
      final basicSalary = (payrollData['basicSalary'] ?? 0).toDouble();
      final allowances = payrollData['allowances'] as Map<String, dynamic>? ?? {};
      final deductions = payrollData['deductions'] as Map<String, dynamic>? ?? {};
      final bankDetails = payrollData['bankDetails'] as Map<String, dynamic>? ?? {};
      final mpesaDetails = payrollData['mpesaDetails'] as Map<String, dynamic>? ?? {};
      
      // Calculate totals
      final housingAllow = (allowances['housing'] ?? 0).toDouble();
      final transportAllow = (allowances['transport'] ?? 0).toDouble();
      final otherAllow = (allowances['other'] ?? 0).toDouble();
      final totalAllowances = housingAllow + transportAllow + otherAllow;
      
      final loans = (deductions['loans'] ?? 0).toDouble();
      final sacco = (deductions['sacco'] ?? 0).toDouble();
      final advances = (deductions['advances'] ?? 0).toDouble();
      final totalDeductions = loans + sacco + advances;
      
      final netPay = basicSalary + totalAllowances - totalDeductions;
      
      _logger.d('Row ${index + 1}: $fullName - Dept: $department, Hours: $monthlyHours, OT: $overtimeHours, Net Pay: $netPay');
      
      rows.add(
        DataRow(
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
            // Department cell - Color-coded badge
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getDepartmentColor(department).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getDepartmentColor(department).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  department,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: _getDepartmentColor(department),
                  ),
                ),
              ),
            ),
            // Hours cell
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: monthlyHours > 0
                      ? const Color.fromARGB(255, 2, 136, 209).withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: monthlyHours > 0
                          ? const Color.fromARGB(255, 2, 136, 209)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      monthlyHours > 0
                          ? '${NumberFormat('#,##0.0').format(monthlyHours)} hrs'
                          : 'Not logged',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: monthlyHours > 0
                            ? const Color.fromARGB(255, 2, 136, 209)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Overtime cell
            DataCell(_buildOvertimeBadge(overtimeHours)),
            DataCell(Text(
              basicSalary > 0
                  ? 'KES ${NumberFormat('#,###').format(basicSalary)}'
                  : '-',
            )),
            DataCell(Text(
              housingAllow > 0
                  ? 'KES ${NumberFormat('#,###').format(housingAllow)}'
                  : '-',
            )),
            DataCell(Text(
              transportAllow > 0
                  ? 'KES ${NumberFormat('#,###').format(transportAllow)}'
                  : '-',
            )),
            DataCell(Text(
              otherAllow > 0
                  ? 'KES ${NumberFormat('#,###').format(otherAllow)}'
                  : '-',
            )),
            DataCell(Text(
              totalAllowances > 0
                  ? 'KES ${NumberFormat('#,###').format(totalAllowances)}'
                  : '-',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 46, 125, 50),
              ),
            )),
            DataCell(Text(
              loans > 0
                  ? 'KES ${NumberFormat('#,###').format(loans)}'
                  : '-',
            )),
            DataCell(Text(
              sacco > 0
                  ? 'KES ${NumberFormat('#,###').format(sacco)}'
                  : '-',
            )),
            DataCell(Text(
              advances > 0
                  ? 'KES ${NumberFormat('#,###').format(advances)}'
                  : '-',
            )),
            DataCell(Text(
              totalDeductions > 0
                  ? 'KES ${NumberFormat('#,###').format(totalDeductions)}'
                  : '-',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 211, 47, 47),
              ),
            )),
            DataCell(Text(
              'KES ${NumberFormat('#,###').format(netPay)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 86, 10, 119),
                fontSize: 14,
              ),
            )),
            DataCell(Text(bankDetails['bankName'] ?? '-')),
            DataCell(Text(bankDetails['accountNumber'] ?? '-')),
            DataCell(Text(bankDetails['branch'] ?? '-')),
            DataCell(Text(mpesaDetails['phoneNumber'] ?? '-')),
            DataCell(_buildStatusBadge(data['status'] ?? 'draft')),
            // Actions cell - Only payslip generation
            DataCell(
              IconButton(
                icon: const Icon(Icons.receipt_long, size: 20, color: Color.fromARGB(255, 86, 10, 119)),
                onPressed: () {
                  _logger.i('Generate payslip for: ${doc.id}');
                  _generatePayslip(doc.id, data);
                },
                tooltip: 'Generate Payslip',
              ),
            ),
          ],
        ),
      );
    }

    return rows;
  }

  Widget _buildOvertimeBadge(double overtimeHours) {
    if (overtimeHours <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'No OT',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
    
    // Determine overtime severity
    Color color;
    IconData icon;
    
    if (overtimeHours >= 40) {
      // Excessive overtime (≥40 hours)
      color = Colors.red;
      icon = Icons.warning_amber;
    } else if (overtimeHours >= 20) {
      // High overtime (20-39 hours)
      color = const Color.fromARGB(255, 255, 152, 0);
      icon = Icons.access_time_filled;
    } else {
      // Moderate overtime (<20 hours)
      color = const Color.fromARGB(255, 2, 136, 209);
      icon = Icons.schedule;
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
            '${NumberFormat('#,##0.0').format(overtimeHours)} hrs',
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

  Widget _buildTableHeader(double screenWidth) {
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);
    final dropdownTextSize = (screenWidth * 0.009).clamp(11.0, 14.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 86, 10, 119),
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
                Icons.account_balance_wallet,
                size: logoSize * 0.6,
                color: const Color.fromARGB(255, 86, 10, 119),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JV Almacis Payroll - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Employee Payment, Hours & Allowance Records',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Dropdown filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: const Color.fromARGB(255, 86, 10, 119),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 20,
                ),
                style: TextStyle(
                  fontSize: dropdownTextSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'draft',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.drafts,
                          color: Color.fromARGB(255, 207, 113, 225),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DRAFT VIEW',
                          style: TextStyle(
                            fontSize: dropdownTextSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'APPROVED ONLY',
                          style: TextStyle(
                            fontSize: dropdownTextSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'all',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.list,
                          color: Colors.blue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ALL EMPLOYEES',
                          style: TextStyle(
                            fontSize: dropdownTextSize,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  _logger.i('Table header filter changed from "$_statusFilter" to "$value"');
                  setState(() => _statusFilter = value!);
                  _logger.d('Now querying with filter: $_statusFilter');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a merged stream of documents based on the current filter
  /// FILTERS OUT ADMIN USERS
  Stream<List<DocumentSnapshot>> _getMergedStream() {
    _logger.d('Getting merged stream for filter: $_statusFilter');
    
    if (_statusFilter == 'all') {
      // Merge both Draft and EmployeeDetails collections, excluding Admins
      _logger.i('Merging Draft and EmployeeDetails collections for ALL view (excluding Admins)');
      
      final controller = StreamController<List<DocumentSnapshot>>();
      
      final draftStream = _firestore.collection('Draft').snapshots();
      final employeeStream = _firestore.collection('EmployeeDetails').snapshots();
      
      StreamSubscription? draftSub;
      StreamSubscription? employeeSub;
      
      List<DocumentSnapshot> draftDocs = [];
      List<DocumentSnapshot> employeeDocs = [];
      
      draftSub = draftStream.listen(
        (snapshot) async {
          // Filter out Admins
          final filteredDocs = <DocumentSnapshot>[];
          for (var doc in snapshot.docs) {
            if (await _isNotAdmin(doc)) {
              filteredDocs.add(doc);
            }
          }
          draftDocs = filteredDocs;
          controller.add([...draftDocs, ...employeeDocs]);
        },
        onError: (error) {
          _logger.e('Error in Draft stream', error: error);
          controller.addError(error);
        },
      );
      
      employeeSub = employeeStream.listen(
        (snapshot) async {
          // Filter out Admins
          final filteredDocs = <DocumentSnapshot>[];
          for (var doc in snapshot.docs) {
            if (await _isNotAdmin(doc)) {
              filteredDocs.add(doc);
            }
          }
          employeeDocs = filteredDocs;
          controller.add([...draftDocs, ...employeeDocs]);
        },
        onError: (error) {
          _logger.e('Error in EmployeeDetails stream', error: error);
          controller.addError(error);
        },
      );
      
      controller.onCancel = () {
        draftSub?.cancel();
        employeeSub?.cancel();
      };
      
      return controller.stream;
      
    } else if (_statusFilter == 'approved') {
      // Only EmployeeDetails collection (approved employees), excluding Admins
      _logger.i('Fetching from EmployeeDetails collection for APPROVED view (excluding Admins)');
      return _firestore
          .collection('EmployeeDetails')
          .snapshots()
          .asyncMap((snapshot) async {
            final filteredDocs = <DocumentSnapshot>[];
            for (var doc in snapshot.docs) {
              if (await _isNotAdmin(doc)) {
                filteredDocs.add(doc);
              }
            }
            return filteredDocs;
          });
          
    } else {
      // Only Draft collection, excluding Admins
      _logger.i('Fetching from Draft collection for DRAFT view (excluding Admins)');
      return _firestore
          .collection('Draft')
          .snapshots()
          .asyncMap((snapshot) async {
            final filteredDocs = <DocumentSnapshot>[];
            for (var doc in snapshot.docs) {
              if (await _isNotAdmin(doc)) {
                filteredDocs.add(doc);
              }
            }
            return filteredDocs;
          });
    }
  }

  /// Get employee department from Departments collection
  Future<String> _getEmployeeDepartment(String uid) async {
    try {
      _logger.d('Fetching department for UID: $uid');
      
      // Query all departments to find which one contains this employee
      final departmentsSnapshot = await _firestore.collection('Departments').get();
      
      for (var deptDoc in departmentsSnapshot.docs) {
        final deptData = deptDoc.data();
        final members = deptData['members'] as Map<String, dynamic>? ?? {};
        
        if (members.containsKey(uid)) {
          final deptName = deptDoc.id;
          _logger.d('Found department for $uid: $deptName');
          return deptName;
        }
      }
      
      _logger.w('No department found for UID: $uid');
      return '-';
    } catch (e) {
      _logger.e('Error fetching department for UID: $uid', error: e);
      return '-';
    }
  }

  /// Check if user is NOT an Admin by querying Users collection
  Future<bool> _isNotAdmin(DocumentSnapshot employeeDoc) async {
    try {
      final data = employeeDoc.data() as Map<String, dynamic>;
      final uid = data['uid'];
      
      if (uid == null) {
        _logger.w('No UID found for employee document: ${employeeDoc.id}');
        return true; // Include if no UID (shouldn't happen)
      }
      
      // Query Users collection to get role
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) {
        _logger.d('User not found in Users collection for UID: $uid');
        return true; // Include if not found
      }
      
      final userData = userQuery.docs.first.data();
      final role = userData['role'] as String?;
      
      if (role == 'Admin') {
        _logger.d('Excluding Admin user: ${data['personalInfo']?['fullName'] ?? 'Unknown'}');
        return false; // Exclude Admins
      }
      
      return true; // Include all other roles
    } catch (e) {
      _logger.e('Error checking admin status', error: e);
      return true; // Include on error
    }
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

  Future<void> _downloadPayrollExcel() async {
    _logger.i('=== PAYROLL EXCEL DOWNLOAD INITIATED ===');
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Fetching payroll data...';
    });
    
    try {
      if (mounted) {
        setState(() => _downloadProgress = 'Loading employee records...');
      }
      
      List<QueryDocumentSnapshot> allDocs = [];
      
      if (_statusFilter == 'all') {
        _logger.i('Fetching from both Draft and EmployeeDetails collections...');
        
        final draftSnapshot = await _firestore.collection('Draft').get();
        final employeeSnapshot = await _firestore.collection('EmployeeDetails').get();
        
        // Filter out Admins
        for (var doc in draftSnapshot.docs) {
          if (await _isNotAdmin(doc)) {
            allDocs.add(doc);
          }
        }
        for (var doc in employeeSnapshot.docs) {
          if (await _isNotAdmin(doc)) {
            allDocs.add(doc);
          }
        }
        
        _logger.i('Fetched ${allDocs.length} non-admin employees');
      } else if (_statusFilter == 'approved') {
        _logger.i('Fetching from EmployeeDetails collection...');
        final snapshot = await _firestore.collection('EmployeeDetails').get();
        
        for (var doc in snapshot.docs) {
          if (await _isNotAdmin(doc)) {
            allDocs.add(doc);
          }
        }
      } else {
        _logger.i('Fetching from Draft collection...');
        final snapshot = await _firestore.collection('Draft').get();
        
        for (var doc in snapshot.docs) {
          if (await _isNotAdmin(doc)) {
            allDocs.add(doc);
          }
        }
      }
      
      _logger.i('Total fetched: ${allDocs.length} employee records (excluding Admins)');
      
      if (allDocs.isEmpty) {
        throw Exception('No employee payroll data found');
      }
      
      if (mounted) {
        setState(() => _downloadProgress = 'Processing ${allDocs.length} records...');
      }
      
      final employees = <EmployeeOnboarding>[];
      
      for (var doc in allDocs) {
        try {
          final employee = EmployeeOnboarding.fromMap(doc.data() as Map<String, dynamic>);
          employees.add(employee);
        } catch (e) {
          _logger.e('Error converting document ${doc.id}', error: e);
        }
      }
      
      _logger.i('Successfully converted ${employees.length} employee records');

      if (mounted) {
        setState(() => _downloadProgress = 'Generating Excel...');
      }
      
      final result = await ExcelGenerationService.generateEmployeeOnboardingExcel(employees);
      final fileName = result['fileName'] as String;
      final fileBytes = result['fileBytes'] as Uint8List;
      final fileSize = result['fileSize'] as int;
      
      _logger.i('Excel file generated: $fileName ($fileSize bytes)');
      
      if (mounted) {
        setState(() => _downloadProgress = 'Downloading...');
      }
      
      final downloadedFilePath = await ExcelDownloadService.downloadExcel(
        fileBytes,
        'Payroll_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx',
      );
      
      _logger.i('✅ Payroll Excel download completed successfully');
      
      if (!mounted) return;
      
      final fileReadableSize = ExcelDownloadService.getReadableFileSize(fileSize);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Payroll Excel downloaded successfully!\n$fileName ($fileReadableSize)'
                : 'Payroll Excel downloaded!\nLocation: $downloadedFilePath\nSize: $fileReadableSize',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
      
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR DOWNLOADING PAYROLL EXCEL', error: e, stackTrace: stackTrace);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating payroll Excel: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  /// Get color for department badge
  Color _getDepartmentColor(String department) {
    final normalizedDept = department.toLowerCase();
    
    if (normalizedDept.contains('account') || normalizedDept.contains('finance')) {
      return const Color.fromARGB(255, 255, 152, 0); // Orange
    } else if (normalizedDept.contains('hr') || normalizedDept.contains('human')) {
      return const Color.fromARGB(255, 2, 136, 209); // Blue
    } else if (normalizedDept.contains('engineering') || normalizedDept.contains('tech')) {
      return const Color.fromARGB(255, 46, 125, 50); // Green
    } else if (normalizedDept.contains('marketing') || normalizedDept.contains('sales')) {
      return const Color.fromARGB(255, 211, 47, 47); // Red
    } else if (normalizedDept.contains('operations') || normalizedDept.contains('ops')) {
      return const Color.fromARGB(255, 123, 31, 162); // Purple
    } else if (normalizedDept.contains('it') || normalizedDept.contains('information')) {
      return const Color.fromARGB(255, 3, 169, 244); // Light Blue
    } else {
      return Colors.grey; // Default
    }
  }

  void _generatePayslip(String id, Map<String, dynamic> data) {
    _logger.i('=== GENERATE PAYSLIP ===');
    _logger.d('Employee ID: $id');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payslip generation feature coming soon!'),
        backgroundColor: Color.fromARGB(255, 86, 10, 119),
        duration: Duration(seconds: 2),
      ),
    );
  }
}