import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Employee Hours View Screen
/// Allows employees (except Admins) to view their logged work hours
/// Shows:
/// - Monthly summary
/// - Daily breakdown with entry/exit times
/// - Hours logged by supervisor
class EmployeeHoursView extends StatefulWidget {
  const EmployeeHoursView({super.key});

  @override
  State<EmployeeHoursView> createState() => _EmployeeHoursViewState();
}

class _EmployeeHoursViewState extends State<EmployeeHoursView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  String? _employeeId;
  String? _employeeName;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEmployeeInfo();
  }

  Future<void> _loadEmployeeInfo() async {
    if (_currentUser == null) return;

    try {
      // Find employee in EmployeeDetails
      final query = await _firestore
          .collection('EmployeeDetails')
          .where('personalInfo.email', isEqualTo: _currentUser.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _employeeId = query.docs.first.id;
          _employeeName = data['personalInfo']?['fullName'] ?? 'Unknown';
          _isLoading = false;
        });
        _logger.i('Loaded employee: $_employeeName (ID: $_employeeId)');
      } else {
        setState(() => _isLoading = false);
        _logger.w('Employee not found in EmployeeDetails');
      }
    } catch (e) {
      _logger.e('Error loading employee info', error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_employeeId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Work Hours'),
          backgroundColor: const Color.fromARGB(255, 84, 4, 108),
        ),
        body: const Center(
          child: Text('Employee record not found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 250),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildEmployeeHeader(),
          _buildMonthSelector(),
          _buildMonthlySummary(),
          Expanded(child: _buildDailyHoursList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color.fromARGB(255, 84, 4, 108),
      title: const Text(
        'My Work Hours',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 84, 4, 108),
            Color.fromARGB(255, 120, 6, 152),
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
              Icons.person,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _employeeName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
            color: Color.fromARGB(255, 84, 4, 108),
            size: 20,
          ),
          const SizedBox(width: 12),
          const Text(
            'Viewing Month:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 84, 4, 108).withValues(alpha: 0.1),
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
                      color: Color.fromARGB(255, 84, 4, 108),
                    ),
                  ),
                  PopupMenuButton<DateTime>(
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color.fromARGB(255, 84, 4, 108),
                    ),
                    onSelected: (DateTime newMonth) {
                      setState(() => _selectedMonth = newMonth);
                    },
                    itemBuilder: (context) {
                      final List<DateTime> months = [];
                      final now = DateTime.now();
                      
                      for (int i = 0; i < 12; i++) {
                        months.add(DateTime(now.year, now.month - i, 1));
                      }
                      
                      return months.map((month) {
                        return PopupMenuItem<DateTime>(
                          value: month,
                          child: Text(DateFormat('MMMM yyyy').format(month)),
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

  Widget _buildMonthlySummary() {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore
          .collection('EmployeeDetails')
          .doc(_employeeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final hoursWorked = data?['hoursWorked'] as Map<String, dynamic>? ?? {};
        final monthlyTotal = (hoursWorked[monthKey] ?? 0).toDouble();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Hours This Month',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 84, 4, 108).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${monthlyTotal.toStringAsFixed(1)} hrs',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 84, 4, 108),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyHoursList() {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('EmployeeDetails')
          .doc(_employeeId)
          .collection('DailyHours')
          .where('monthKey', isEqualTo: monthKey)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final dailyEntries = snapshot.data!.docs;

        if (dailyEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hours logged for ${DateFormat('MMMM').format(_selectedMonth)}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: dailyEntries.length,
          itemBuilder: (context, index) {
            final entry = dailyEntries[index].data() as Map<String, dynamic>;
            final date = (entry['date'] as Timestamp).toDate();
            final entryTime = entry['entryTime'] ?? 'N/A';
            final exitTime = entry['exitTime'] ?? 'N/A';
            final hours = (entry['hours'] ?? 0).toDouble();
            final loggedBy = entry['loggedBy'] ?? 'Supervisor';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE').format(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(date),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 84, 4, 108).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${hours.toStringAsFixed(2)} hrs',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 84, 4, 108),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeDetail('Entry', entryTime),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildTimeDetail('Exit', exitTime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.supervisor_account,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Logged by: $loggedBy',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
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

  Widget _buildTimeDetail(String label, String time) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              time,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}