import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/models/user_model.dart';
import 'package:almahub/screens/employee/employee_onboarding_wizard.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'dart:async';

/// Employee dashboard for viewing and managing their onboarding application
class EmployeeDashboard extends StatefulWidget {
  final String? employeeEmail;

  const EmployeeDashboard({
    super.key,
    this.employeeEmail,
  });

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // ✅ NEW: Role monitoring
  StreamSubscription<DocumentSnapshot>? _roleListener;
  String? _currentUserRole;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _logger.i('EmployeeDashboard initialized with email: ${widget.employeeEmail}');

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
    
    // ✅ NEW: Setup role listener
    _setupRoleListener();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _roleListener?.cancel(); // ✅ NEW: Cancel listener
    _logger.i('EmployeeDashboard disposed');
    super.dispose();
  }

  // ✅ NEW: Setup realtime role monitoring
  void _setupRoleListener() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      _logger.e('No authenticated user found');
      if (mounted) {
        setState(() => _isCheckingRole = false);
      }
      return;
    }

    try {
      _logger.i('Setting up role listener for user: ${currentUser.uid}');
      
      // Find user document in Users collection by UID
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _logger.w('User not found in Users collection');
        if (mounted) {
          setState(() => _isCheckingRole = false);
        }
        return;
      }

      final userDocId = userQuery.docs.first.id;
      _logger.d('Found user document: $userDocId');

      // Set up realtime listener on the user document
      _roleListener = _firestore
          .collection('Users')
          .doc(userDocId)
          .snapshots()
          .listen((docSnapshot) {
        if (!mounted) return;

        if (!docSnapshot.exists) {
          _logger.e('User document no longer exists');
          return;
        }

        final userData = docSnapshot.data() as Map<String, dynamic>;
        final newRole = userData['role'] as String?;

        _logger.i('Role update detected: $newRole (previous: $_currentUserRole)');

        // Check if role has changed
        if (_currentUserRole != null && _currentUserRole != newRole) {
          _logger.i('Role changed from $_currentUserRole to $newRole');
          _handleRoleChange(newRole);
        }

        setState(() {
          _currentUserRole = newRole;
          _isCheckingRole = false;
        });
      }, onError: (error) {
        _logger.e('Error in role listener', error: error);
        if (mounted) {
          setState(() => _isCheckingRole = false);
        }
      });
    } catch (e, stackTrace) {
      _logger.e('Error setting up role listener', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isCheckingRole = false);
      }
    }
  }

  // ✅ NEW: Handle role changes
  void _handleRoleChange(String? newRole) {
    if (newRole == null) return;

    _logger.i('Handling role change to: $newRole');

    // Show notification about role change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your role has been updated to: $newRole'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );

    // If promoted to Admin, navigate to Role Selection Screen
    if (newRole == UserRoles.admin) {
      _logger.i('User promoted to Admin, navigating to RoleSelectionScreen');
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const RoleSelectionScreen(),
            ),
          );
        }
      });
    }
    
    // For other role changes (HR, Supervisor), just refresh the UI
    // The dashboard can show different features based on role
    else {
      _logger.d('Role changed to $newRole, refreshing UI');
      setState(() {
        // Trigger rebuild to show role-specific features
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building EmployeeDashboard widget');
    
    // ✅ NEW: Show loading while checking role
    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 245, 245, 250),
        appBar: _buildModernAppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color.fromARGB(255, 84, 4, 108),
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 250),
      appBar: _buildModernAppBar(),
      body: _buildApplicationsList(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color.fromARGB(255, 84, 4, 108),
      toolbarHeight: 70,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              // ✅ NEW: Show current role
              Text(
                _currentUserRole != null 
                    ? 'Role: $_currentUserRole' 
                    : 'Onboarding Application',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // ✅ NEW: Show Admin icon if user is Admin
        if (_currentUserRole == UserRoles.admin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.amber),
            onPressed: () {
              _logger.i('Admin navigating to RoleSelectionScreen');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
              );
            },
            tooltip: 'Admin Panel',
          ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {
            _logger.i('Notifications button clicked');
          },
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {
            _logger.i('Settings button clicked');
          },
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildApplicationsList() {
    _logger.d('Building applications list stream');

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _logger.e('No authenticated user found');
      return _buildEmptyState(
        icon: Icons.person_off,
        title: 'Not Logged In',
        message: 'Please log in to view your applications',
      );
    }

    final uid = currentUser.uid;
    _logger.i('Querying collections for user UID: $uid');

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('Draft')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, draftSnapshot) {
        if (draftSnapshot.hasError) {
          _logger.e('Error loading Draft collection', error: draftSnapshot.error);
        }

        if (draftSnapshot.connectionState == ConnectionState.waiting) {
          _logger.d('Waiting for Draft collection data...');
        } else if (draftSnapshot.hasData) {
          _logger.d('Draft collection loaded: ${draftSnapshot.data?.docs.length ?? 0} total documents');
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('EmployeeDetails')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, submittedSnapshot) {
            if (submittedSnapshot.hasError) {
              _logger.e('Error loading EmployeeDetails collection',
                  error: submittedSnapshot.error);
            }

            if (submittedSnapshot.connectionState == ConnectionState.waiting) {
              _logger.d('Waiting for EmployeeDetails collection data...');
            } else if (submittedSnapshot.hasData) {
              _logger.d('EmployeeDetails collection loaded: ${submittedSnapshot.data?.docs.length ?? 0} total documents');
            }

            if (draftSnapshot.hasError && submittedSnapshot.hasError) {
              _logger.e('Both collections failed to load');
              return _buildErrorState();
            }

            if (draftSnapshot.connectionState == ConnectionState.waiting ||
                submittedSnapshot.connectionState == ConnectionState.waiting) {
              _logger.d('Still waiting for data...');
              return const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 84, 4, 108),
                ),
              );
            }

            // Filter client-side for current user
            final List<QueryDocumentSnapshot> allApplications = [];
            bool hasDrafts = false;

            if (draftSnapshot.hasData) {
              final userDrafts = draftSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['uid'] == uid;
              }).toList();

              allApplications.addAll(userDrafts);
              hasDrafts = userDrafts.isNotEmpty;
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

            // Sort by creation date
            allApplications.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTimestamp = aData['createdAt'] as Timestamp?;
              final bTimestamp = bData['createdAt'] as Timestamp?;

              if (aTimestamp == null || bTimestamp == null) return 0;
              return bTimestamp.compareTo(aTimestamp);
            });

            _logger.i('Total applications for current user: ${allApplications.length}');

            if (allApplications.isEmpty) {
              _logger.w('No applications found for current user');
              return _buildEmptyStateWithAction(
                icon: Icons.description_outlined,
                title: 'No Applications Yet',
                message: 'Start your onboarding journey by creating your first application',
                actionLabel: 'Create Application',
                onAction: _startNewApplication,
              );
            }

            // User has at least one application - don't show create button
            return Column(
              children: [
                // ✅ NEW: Show role badge if not Employee
                if (_currentUserRole != null && _currentUserRole != UserRoles.employee)
                  _buildRoleBadge(_currentUserRole!),
                
                // Animated draft reminder if there are drafts
                if (hasDrafts) _buildDraftReminder(),
                
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      _logger.d('Applications list screen width: $screenWidth px');

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: 16,
                        ),
                        itemCount: allApplications.length,
                        itemBuilder: (context, index) {
                          final doc = allApplications[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final status = data['status'] ?? 'draft';

                          _logger.d('Rendering application ${index + 1}: ${data['personalInfo']?['fullName'] ?? 'Unknown'} (Status: $status)');

                          return _buildResponsiveApplicationCard(
                            doc: doc,
                            data: data,
                            status: status,
                            screenWidth: screenWidth,
                            index: index,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ NEW: Role badge widget
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData badgeIcon;
    
    switch (role) {
      case 'Admin':
        badgeColor = Colors.amber;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case 'HR':
        badgeColor = Colors.blue;
        badgeIcon = Icons.business_center;
        break;
      case 'Supervisor':
        badgeColor = Colors.green;
        badgeIcon = Icons.supervisor_account;
        break;
      case 'Accountant':
        badgeColor = Colors.orange;
        badgeIcon = Icons.account_balance_wallet;
        break;
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.person;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              badgeColor.withValues(alpha: 0.1),
              badgeColor.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badgeColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                badgeIcon,
                color: badgeColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$role Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have extended privileges in the system',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
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

  Widget _buildDraftReminder() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade900,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft Application',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete and submit your application to proceed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange.shade700,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveApplicationCard({
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String status,
    required double screenWidth,
    required int index,
  }) {
    // Adaptive sizing based on screen width
    final cardHorizontalPadding = (screenWidth * 0.05).clamp(16.0, 24.0);
    final cardVerticalPadding = (screenWidth * 0.04).clamp(14.0, 20.0);
    final titleSize = (screenWidth * 0.045).clamp(16.0, 20.0);
    final subtitleSize = (screenWidth * 0.035).clamp(12.0, 14.0);
    final metaSize = (screenWidth * 0.030).clamp(11.0, 13.0);
    final iconSize = (screenWidth * 0.04).clamp(14.0, 18.0);
    final spacing = (screenWidth * 0.03).clamp(12.0, 16.0);

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      child: Card(
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            _logger.i('Application card clicked: ${doc.id}');
            _logger.d('Opening application with status: $status');
            _openApplication(doc.id, status);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: cardHorizontalPadding,
              vertical: cardVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name and Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['personalInfo']?['fullName'] ?? 'Application',
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 84, 4, 108),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: spacing * 0.3),
                          Text(
                            data['employmentDetails']?['jobTitle'] ?? 'Position not specified',
                            style: TextStyle(
                              fontSize: subtitleSize,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing * 0.5),
                    _buildResponsiveStatusBadge(status, screenWidth),
                  ],
                ),

                SizedBox(height: spacing),

                // Divider
                Divider(
                  color: Colors.grey.shade200,
                  thickness: 1,
                  height: 1,
                ),

                SizedBox(height: spacing),

                // Metadata section
                Wrap(
                  spacing: spacing,
                  runSpacing: spacing * 0.5,
                  children: [
                    _buildMetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created',
                      value: _formatDate(data['createdAt']),
                      iconSize: iconSize,
                      textSize: metaSize,
                    ),
                    if (data['updatedAt'] != null)
                      _buildMetaChip(
                        icon: Icons.update_outlined,
                        label: 'Updated',
                        value: _formatDate(data['updatedAt']),
                        iconSize: iconSize,
                        textSize: metaSize,
                      ),
                    if (status == 'submitted' && data['submittedAt'] != null)
                      _buildMetaChip(
                        icon: Icons.send_outlined,
                        label: 'Submitted',
                        value: _formatDate(data['submittedAt']),
                        iconSize: iconSize,
                        textSize: metaSize,
                        color: Colors.green,
                      ),
                  ],
                ),

                // Additional info for submitted applications
                if (status != 'draft') ...[
                  SizedBox(height: spacing),
                  _buildApplicationProgress(data, screenWidth),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveStatusBadge(String status, double screenWidth) {
    final badgeTextSize = (screenWidth * 0.028).clamp(10.0, 12.0);
    final badgeIconSize = (screenWidth * 0.035).clamp(14.0, 16.0);
    final badgePadding = (screenWidth * 0.02).clamp(8.0, 12.0);

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
      padding: EdgeInsets.symmetric(
        horizontal: badgePadding,
        vertical: badgePadding * 0.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: badgeIconSize, color: color),
          SizedBox(width: badgePadding * 0.4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: badgeTextSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required String value,
    required double iconSize,
    required double textSize,
    Color? color,
  }) {
    final chipColor = color ?? Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: chipColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: textSize,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: textSize,
              color: chipColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationProgress(Map<String, dynamic> data, double screenWidth) {
    final progressTextSize = (screenWidth * 0.030).clamp(11.0, 13.0);

    // Calculate completion percentage based on filled fields
    final personalInfo = data['personalInfo'] as Map<String, dynamic>? ?? {};
    final employmentDetails = data['employmentDetails'] as Map<String, dynamic>? ?? {};
    final statutoryDocs = data['statutoryDocs'] as Map<String, dynamic>? ?? {};
    final payrollDetails = data['payrollDetails'] as Map<String, dynamic>? ?? {};

    int totalFields = 15; // Approximate total required fields
    int filledFields = 0;

    // Count filled personal info fields
    if (personalInfo['fullName']?.toString().isNotEmpty ?? false) filledFields++;
    if (personalInfo['email']?.toString().isNotEmpty ?? false) filledFields++;
    if (personalInfo['phoneNumber']?.toString().isNotEmpty ?? false) filledFields++;
    if (personalInfo['nationalIdOrPassport']?.toString().isNotEmpty ?? false) filledFields++;

    // Count employment details
    if (employmentDetails['jobTitle']?.toString().isNotEmpty ?? false) filledFields++;
    if (employmentDetails['department']?.toString().isNotEmpty ?? false) filledFields++;
    if (employmentDetails['employmentType']?.toString().isNotEmpty ?? false) filledFields++;
    if (employmentDetails['startDate'] != null) filledFields++;

    // Count statutory docs
    if (statutoryDocs['kraPinNumber']?.toString().isNotEmpty ?? false) filledFields++;
    if (statutoryDocs['nssfNumber']?.toString().isNotEmpty ?? false) filledFields++;
    if (statutoryDocs['nhifNumber']?.toString().isNotEmpty ?? false) filledFields++;

    // Count payroll details
    if (payrollDetails['basicSalary'] != null) filledFields++;
    if (payrollDetails['bankDetails']?['bankName']?.toString().isNotEmpty ?? false) filledFields++;
    if (payrollDetails['bankDetails']?['accountNumber']?.toString().isNotEmpty ?? false) filledFields++;
    if (payrollDetails['bankDetails']?['branchName']?.toString().isNotEmpty ?? false) filledFields++;

    final percentage = (filledFields / totalFields * 100).clamp(0, 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Application Progress',
              style: TextStyle(
                fontSize: progressTextSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: progressTextSize,
                fontWeight: FontWeight.bold,
                color: percentage == 100 ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage == 100 ? Colors.green : Colors.orange,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWithAction({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 84, 4, 108).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: const Color.fromARGB(255, 84, 4, 108),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 84, 4, 108),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_circle_outline, size: 24),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 84, 4, 108),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading applications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
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
              backgroundColor: const Color.fromARGB(255, 84, 4, 108),
            ),
          ),
        ],
      ),
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

    final collection = status == 'draft' ? 'Draft' : 'EmployeeDetails';
    _logger.d('Fetching from $collection collection');

    _firestore.collection(collection).doc(docId).get().then((docSnapshot) {
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

        _viewOrEditApplication(employee, docId);
      } catch (e, stackTrace) {
        _logger.e('Error parsing employee data', error: e, stackTrace: stackTrace);

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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading application: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
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
      setState(() {});
    });
  }

  void _viewOrEditApplication(EmployeeOnboarding employee, String docId) {
    _logger.i('Viewing/editing application for ${employee.personalInfo.fullName} '
        '(DocID: $docId, Status: ${employee.status})');

    if (employee.status == 'draft') {
      _logger.d('Opening application in edit mode');
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
      _showDetailedApplicationView(employee);
    }
  }

  void _showDetailedApplicationView(EmployeeOnboarding employee) {
    _logger.d('Showing detailed application view for ${employee.personalInfo.fullName}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color.fromARGB(255, 245, 245, 250),
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 84, 4, 108),
            elevation: 0,
            title: const Text(
              'Application Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection(
                  title: 'Personal Information',
                  icon: Icons.person,
                  children: [
                    _buildDetailRow('Full Name', employee.personalInfo.fullName),
                    _buildDetailRow('Email', employee.personalInfo.email),
                    _buildDetailRow('Phone', employee.personalInfo.phoneNumber),
                    _buildDetailRow('National ID', employee.personalInfo.nationalIdOrPassport),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailSection(
                  title: 'Employment Details',
                  icon: Icons.work,
                  children: [
                    _buildDetailRow('Job Title', employee.employmentDetails.jobTitle),
                    _buildDetailRow('Department', employee.employmentDetails.department),
                    _buildDetailRow('Employment Type', employee.employmentDetails.employmentType),
                    _buildDetailRow(
                      'Start Date',
                      employee.employmentDetails.startDate != null
                          ? DateFormat('dd MMM yyyy').format(employee.employmentDetails.startDate!)
                          : '-',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailSection(
                  title: 'Statutory Information',
                  icon: Icons.gavel,
                  children: [
                    _buildDetailRow('KRA PIN', employee.statutoryDocs.kraPinNumber),
                    _buildDetailRow('NSSF Number', employee.statutoryDocs.nssfNumber),
                    _buildDetailRow('NHIF Number', employee.statutoryDocs.nhifNumber),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailSection(
                  title: 'Payroll Details',
                  icon: Icons.account_balance,
                  children: [
                    _buildDetailRow(
                      'Basic Salary',
                      'KES ${NumberFormat('#,###').format(employee.payrollDetails.basicSalary)}',
                    ),
                    _buildDetailRow('Bank Name', employee.payrollDetails.bankDetails!.bankName),
                    _buildDetailRow('Account Number', employee.payrollDetails.bankDetails!.accountNumber),
                    _buildDetailRow('Branch', employee.payrollDetails.bankDetails!.branch),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailSection(
                  title: 'Application Status',
                  icon: Icons.info,
                  children: [
                    _buildDetailRow('Status', employee.status.toUpperCase()),
                    if (employee.submittedAt != null)
                      _buildDetailRow(
                        'Submitted On',
                        DateFormat('dd MMM yyyy, hh:mm a').format(employee.submittedAt!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                  color: const Color.fromARGB(255, 84, 4, 108).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color.fromARGB(255, 84, 4, 108),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 84, 4, 108),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}