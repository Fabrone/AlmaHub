import 'package:almahub/document_upload_widget.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
//import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
//import 'dart:math' as math;

/// AlmaHub - Comprehensive HR Management Dashboard
/// Features: Recruitment, Employee Management, Payroll, Leave Management, Analytics
/// Backend: Firebase Firestore & Storage

class AlmaHubDashboard extends StatefulWidget {
  const AlmaHubDashboard({super.key});

  @override
  State<AlmaHubDashboard> createState() => _AlmaHubDashboardState();
}

class _AlmaHubDashboardState extends State<AlmaHubDashboard> {
  int _selectedIndex = 0;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //final FirebaseStorage _storage = FirebaseStorage.instance;

  // Dashboard metrics
  Map<String, dynamic> dashboardMetrics = {
    'totalEmployees': 0,
    'activeRecruitments': 0,
    'pendingLeaves': 0,
    'monthlyPayroll': 0.0,
    'newApplications': 0,
    'attendanceRate': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardMetrics();
  }

  Future<void> _loadDashboardMetrics() async {
    try {
      // Load real-time metrics from Firebase
      final employeesSnapshot =
          await _firestore.collection('employees').where('status', isEqualTo: 'active').get();
      final recruitmentsSnapshot = await _firestore
          .collection('recruitments')
          .where('status', isEqualTo: 'open')
          .get();
      final leavesSnapshot = await _firestore
          .collection('leaves')
          .where('status', isEqualTo: 'pending')
          .get();
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('submittedDate',
              isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .get();

      setState(() {
        dashboardMetrics['totalEmployees'] = employeesSnapshot.docs.length;
        dashboardMetrics['activeRecruitments'] = recruitmentsSnapshot.docs.length;
        dashboardMetrics['pendingLeaves'] = leavesSnapshot.docs.length;
        dashboardMetrics['newApplications'] = applicationsSnapshot.docs.length;
        dashboardMetrics['attendanceRate'] = 94.5; // Calculate from attendance records
        dashboardMetrics['monthlyPayroll'] = 2450000.0; // Calculate from payroll records
      });
    } catch (e) {
      debugPrint('Error loading metrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          _buildSidebar(),
          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar Navigation with Modern Design
  Widget _buildSidebar() {
    final navigationItems = [
      {'icon': Icons.dashboard_rounded, 'title': 'Dashboard', 'index': 0},
      {'icon': Icons.person_add_rounded, 'title': 'Recruitment', 'index': 1},
      {'icon': Icons.people_rounded, 'title': 'Employees', 'index': 2},
      {'icon': Icons.payments_rounded, 'title': 'Payroll', 'index': 3},
      {'icon': Icons.calendar_today_rounded, 'title': 'Leave Management', 'index': 4},
      {'icon': Icons.access_time_rounded, 'title': 'Attendance', 'index': 5},
      {'icon': Icons.bar_chart_rounded, 'title': 'Reports', 'index': 6},
      {'icon': Icons.settings_rounded, 'title': 'Settings', 'index': 7},
    ];

    return Container(
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E), // Deep Indigo
            const Color(0xFF0D47A1), // Blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AlmaHub',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'HR MANAGER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            color: Colors.white24,
            thickness: 1,
            indent: 24,
            endIndent: 24,
          ),
          const SizedBox(height: 16),
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: navigationItems.length,
              itemBuilder: (context, index) {
                final item = navigationItems[index];
                final isSelected = _selectedIndex == item['index'];
                return _buildNavItem(
                  icon: item['icon'] as IconData,
                  title: item['title'] as String,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedIndex = item['index'] as int;
                    });
                  },
                );
              },
            ),
          ),
          // User Profile Section
          _buildUserProfile(),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade400,
                  Colors.orange.shade600,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text(
                'JD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'John Doe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'HR Manager',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.white70,
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Top Bar with Search and Notifications
  Widget _buildTopBar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Page Title
          const Text(
            'HR Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(width: 32),
          // Search Bar
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search employees, applications, documents...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Quick Actions
          _buildIconButton(
            icon: Icons.notifications_rounded,
            badge: 5,
            onTap: () {},
          ),
          const SizedBox(width: 16),
          _buildIconButton(
            icon: Icons.email_rounded,
            badge: 12,
            onTap: () {},
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A237E),
                  const Color(0xFF0D47A1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'New Employee',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    int? badge,
    required VoidCallback onTap,
  }) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: const Color(0xFF1A237E)),
            onPressed: onTap,
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  badge > 9 ? '9+' : badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Main Content Area - Dynamic based on selection
  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return _buildRecruitmentSection();
      case 2:
        return _buildEmployeesSection();
      case 3:
        return _buildPayrollSection();
      case 4:
        return _buildLeaveManagementSection();
      case 5:
        return _buildAttendanceSection();
      case 6:
        return _buildReportsSection();
      case 7:
        return _buildSettingsSection();
      default:
        return _buildDashboardOverview();
    }
  }

  // ==================== DASHBOARD OVERVIEW ====================
  Widget _buildDashboardOverview() {
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats Cards
            _buildQuickStatsGrid(),
            const SizedBox(height: 32),
            // Charts Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildEmployeeTrendChart(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildDepartmentDistributionChart(),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Recent Activities and Quick Access
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildRecentActivities(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildPendingActions(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final stats = [
      {
        'title': 'Total Employees',
        'value': dashboardMetrics['totalEmployees'].toString(),
        'change': '+12%',
        'icon': Icons.people_rounded,
        'color': const Color(0xFF1976D2),
        'bgColor': const Color(0xFFE3F2FD),
      },
      {
        'title': 'Active Recruitments',
        'value': dashboardMetrics['activeRecruitments'].toString(),
        'change': '+8%',
        'icon': Icons.work_rounded,
        'color': const Color(0xFF388E3C),
        'bgColor': const Color(0xFFE8F5E9),
      },
      {
        'title': 'Pending Leaves',
        'value': dashboardMetrics['pendingLeaves'].toString(),
        'change': '-5%',
        'icon': Icons.event_busy_rounded,
        'color': const Color(0xFFF57C00),
        'bgColor': const Color(0xFFFFF3E0),
      },
      {
        'title': 'Monthly Payroll',
        'value':
            'KES ${NumberFormat('#,###').format(dashboardMetrics['monthlyPayroll'])}',
        'change': '+3%',
        'icon': Icons.payments_rounded,
        'color': const Color(0xFF7B1FA2),
        'bgColor': const Color(0xFFF3E5F5),
      },
      {
        'title': 'New Applications',
        'value': dashboardMetrics['newApplications'].toString(),
        'change': '+25%',
        'icon': Icons.description_rounded,
        'color': const Color(0xFF00796B),
        'bgColor': const Color(0xFFE0F2F1),
      },
      {
        'title': 'Attendance Rate',
        'value': '${dashboardMetrics['attendanceRate']}%',
        'change': '+2%',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFFD32F2F),
        'bgColor': const Color(0xFFFFEBEE),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.8, // Increased height by reducing ratio from 2.5 to 1.8
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(
          title: stat['title'] as String,
          value: stat['value'] as String,
          change: stat['change'] as String,
          icon: stat['icon'] as IconData,
          color: stat['color'] as Color,
          bgColor: stat['bgColor'] as Color,
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String change,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    final isPositive = change.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(20), // Reduced from 24 to 20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Reduced from 12 to 10
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24), // Reduced from 28 to 24
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 12, // Reduced from 14 to 12
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      change,
                      style: TextStyle(
                        fontSize: 11, // Reduced from 12 to 11
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // Added spacing between rows
          Flexible( // Wrapped in Flexible to prevent overflow
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24, // Reduced from 28 to 24
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12, // Reduced from 13 to 12
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTrendChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Employee Growth Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Last 6 Months',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan',
                          'Feb',
                          'Mar',
                          'Apr',
                          'May',
                          'Jun'
                        ];
                        if (value.toInt() >= 0 &&
                            value.toInt() < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[value.toInt()],
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 120),
                      const FlSpot(1, 135),
                      const FlSpot(2, 142),
                      const FlSpot(3, 158),
                      const FlSpot(4, 165),
                      const FlSpot(5, 178),
                    ],
                    isCurved: true,
                    color: const Color(0xFF1A237E),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: const Color(0xFF1A237E),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A237E).withValues(alpha: 0.2),
                          const Color(0xFF1A237E).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Department Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: 35,
                    title: '35%',
                    color: const Color(0xFF1976D2),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 25,
                    title: '25%',
                    color: const Color(0xFF388E3C),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 20,
                    title: '20%',
                    color: const Color(0xFFF57C00),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 20,
                    title: '20%',
                    color: const Color(0xFF7B1FA2),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendItem('Engineering', const Color(0xFF1976D2), '35%'),
          const SizedBox(height: 8),
          _buildLegendItem('Sales', const Color(0xFF388E3C), '25%'),
          const SizedBox(height: 8),
          _buildLegendItem('Marketing', const Color(0xFFF57C00), '20%'),
          const SizedBox(height: 8),
          _buildLegendItem('Operations', const Color(0xFF7B1FA2), '20%'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String percentage) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          percentage,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A237E),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.person_add_rounded,
            iconColor: const Color(0xFF388E3C),
            title: 'New employee onboarded',
            subtitle: 'Jane Smith joined Engineering',
            time: '2 hours ago',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF1976D2),
            title: 'Application received',
            subtitle: 'Software Developer position',
            time: '4 hours ago',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.event_available_rounded,
            iconColor: const Color(0xFF7B1FA2),
            title: 'Leave approved',
            subtitle: 'Michael Brown - 3 days',
            time: '6 hours ago',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFFF57C00),
            title: 'Payroll processed',
            subtitle: 'January 2026 salary disbursed',
            time: '1 day ago',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildPendingActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 16),
          _buildPendingActionCard(
            title: 'Review Applications',
            count: 12,
            color: const Color(0xFF1976D2),
            icon: Icons.assignment_rounded,
          ),
          const SizedBox(height: 12),
          _buildPendingActionCard(
            title: 'Approve Leaves',
            count: 8,
            color: const Color(0xFFF57C00),
            icon: Icons.event_busy_rounded,
          ),
          const SizedBox(height: 12),
          _buildPendingActionCard(
            title: 'Document Verification',
            count: 5,
            color: const Color(0xFF7B1FA2),
            icon: Icons.verified_user_rounded,
          ),
          const SizedBox(height: 12),
          _buildPendingActionCard(
            title: 'Performance Reviews',
            count: 15,
            color: const Color(0xFF388E3C),
            icon: Icons.star_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActionCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== RECRUITMENT SECTION ====================
  Widget _buildRecruitmentSection() {
    return Container(
      color: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recruitment Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage job postings, applications, and candidate selection',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Open create job posting dialog
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Post New Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Recruitment Stats
            _buildRecruitmentStats(),
            const SizedBox(height: 24),
            // Tabs for different views
            DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      labelColor: const Color(0xFF1A237E),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF1A237E),
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Active Positions'),
                        Tab(text: 'Applications'),
                        Tab(text: 'Interview Schedule'),
                        Tab(text: 'Candidates'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      children: [
                        _buildActivePositionsTab(),
                        _buildApplicationsTab(),
                        _buildInterviewScheduleTab(),
                        _buildCandidatesTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruitmentStats() {
    return Row(
      children: [
        Expanded(
          child: _buildRecruitmentStatCard(
            'Open Positions',
            '8',
            Icons.work_outline_rounded,
            const Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRecruitmentStatCard(
            'Total Applications',
            '156',
            Icons.description_outlined,
            const Color(0xFF388E3C),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRecruitmentStatCard(
            'Interviews Scheduled',
            '24',
            Icons.event_available_outlined,
            const Color(0xFFF57C00),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRecruitmentStatCard(
            'Offers Sent',
            '5',
            Icons.send_outlined,
            const Color(0xFF7B1FA2),
          ),
        ),
      ],
    );
  }

  Widget _buildRecruitmentStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDocumentUploadDialog(String applicationId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 600,
          child: ApplicationDocumentUpload(
            applicationId: applicationId,
            onDocumentsUploaded: (documents) {
              // Handle uploaded documents
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Documents uploaded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // You can save the documents to Firestore here
              _saveApplicationDocuments(applicationId, documents);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveApplicationDocuments(
      String applicationId, Map<String, DocumentInfo> documents) async {
    try {
      final documentMap = documents.map(
        (key, value) => MapEntry(key, value.toMap()),
      );
      
      await _firestore
          .collection('applications')
          .doc(applicationId)
          .update({'documents': documentMap});
    } catch (e) {
      debugPrint('Error saving documents: $e');
    }
  }

  Widget _buildActivePositionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('job_postings')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final positions = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: positions.length,
          itemBuilder: (context, index) {
            final position = positions[index].data() as Map<String, dynamic>;
            return _buildPositionCard(position);
          },
        );
      },
    );
  }

  Widget _buildPositionCard(Map<String, dynamic> position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
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
                      position['title'] ?? 'Position Title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.business_rounded,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          position['department'] ?? 'Department',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.location_on_rounded,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          position['location'] ?? 'Location',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${position['applicants'] ?? 0} Applicants',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildChip('Full-time', Colors.blue),
                  const SizedBox(width: 8),
                  _buildChip('Mid-level', Colors.purple),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('View'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('applications')
          .orderBy('submittedDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data?.docs ?? [];

        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final applicationDoc = applications[index];
            final application = applicationDoc.data() as Map<String, dynamic>;
            final applicationId = applicationDoc.id;
            return _buildApplicationCard(application, applicationId);
          },
        );
      },
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application, String applicationId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1A237E),
            child: Text(
              (application['candidateName'] ?? 'N')
                  .toString()
                  .substring(0, 1)
                  .toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application['candidateName'] ?? 'Candidate Name',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  application['position'] ?? 'Position',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.email_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      application['email'] ?? 'email@example.com',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.phone_rounded,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      application['phone'] ?? '+254 XXX XXX XXX',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(application['status'] ?? 'pending')
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (application['status'] ?? 'pending').toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(application['status'] ?? 'pending'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      // View application details
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 20),
                    tooltip: 'View Application',
                  ),
                  IconButton(
                    onPressed: () => _showDocumentUploadDialog(applicationId),
                    icon: const Icon(Icons.upload_file, size: 20),
                    tooltip: 'Upload Documents',
                  ),
                  IconButton(
                    onPressed: () {
                      // Download documents
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Download Documents',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under review':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _buildInterviewScheduleTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('Interview Schedule Coming Soon'),
      ),
    );
  }

  Widget _buildCandidatesTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text('Candidates Database Coming Soon'),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ==================== EMPLOYEES SECTION ====================
  Widget _buildEmployeesSection() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'View and manage all employee records',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Import Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Employee'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Filter and search bar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search employees...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: 'All Departments',
                          items: const [
                            DropdownMenuItem(
                              value: 'All Departments',
                              child: Text('All Departments'),
                            ),
                            DropdownMenuItem(
                              value: 'Engineering',
                              child: Text('Engineering'),
                            ),
                            DropdownMenuItem(
                              value: 'Sales',
                              child: Text('Sales'),
                            ),
                          ],
                          onChanged: (value) {},
                        ),
                      ],
                    ),
                  ),
                  // Employee list
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('employees').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final employees = snapshot.data?.docs ?? [];

                        return ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: employees.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final employee = employees[index].data()
                                as Map<String, dynamic>;
                            return _buildEmployeeListItem(employee);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeListItem(Map<String, dynamic> employee) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFF1A237E),
        child: Text(
          (employee['name'] ?? 'N').toString().substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      title: Text(
        employee['name'] ?? 'Employee Name',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        '${employee['position'] ?? 'Position'} • ${employee['department'] ?? 'Department'}',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              employee['status'] ?? 'Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ==================== PAYROLL SECTION ====================
  Widget _buildPayrollSection() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'Payroll Management - Coming Soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==================== LEAVE MANAGEMENT SECTION ====================
  Widget _buildLeaveManagementSection() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'Leave Management - Coming Soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==================== ATTENDANCE SECTION ====================
  Widget _buildAttendanceSection() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'Attendance Tracking - Coming Soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==================== REPORTS SECTION ====================
  Widget _buildReportsSection() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'Reports & Analytics - Coming Soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==================== SETTINGS SECTION ====================
  Widget _buildSettingsSection() {
    return Container(
      color: Colors.grey.shade50,
      child: const Center(
        child: Text(
          'Settings - Coming Soon',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}