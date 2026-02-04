import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

/// Screen for admins to view and manage user roles
class AssignRoleScreen extends StatefulWidget {
  const AssignRoleScreen({super.key});

  @override
  State<AssignRoleScreen> createState() => _AssignRoleScreenState();
}

class _AssignRoleScreenState extends State<AssignRoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  bool _isLoading = false;

  final List<String> _roles = [
    'All',
    'Admin',
    'HR',
    'Supervisor',
    'Accountant',
    'Employee',
  ];

  @override
  void initState() {
    super.initState();
    developer.log('AssignRoleScreen initialized', name: 'AssignRoleScreen');
    _checkFirestoreConnection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    developer.log('AssignRoleScreen disposed', name: 'AssignRoleScreen');
    super.dispose();
  }

  /// Check Firestore connection and log collection details
  Future<void> _checkFirestoreConnection() async {
    try {
      developer.log('Checking Firestore connection...', name: 'AssignRoleScreen.Firestore');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .limit(1)
          .get();
      
      developer.log(
        'Firestore connection successful. Collection exists: ${snapshot.docs.isNotEmpty}',
        name: 'AssignRoleScreen.Firestore',
      );
      
      if (snapshot.docs.isNotEmpty) {
        final sampleData = snapshot.docs.first.data();
        developer.log(
          'Sample document data: $sampleData',
          name: 'AssignRoleScreen.Firestore',
        );
        developer.log(
          'Available fields: ${sampleData.keys.toList()}',
          name: 'AssignRoleScreen.Firestore',
        );
      }
      
      // Get total count
      final allDocs = await FirebaseFirestore.instance
          .collection('Users')
          .get();
      
      developer.log(
        'Total users in collection: ${allDocs.docs.length}',
        name: 'AssignRoleScreen.Firestore',
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error checking Firestore connection: $e',
        name: 'AssignRoleScreen.Firestore',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update user role in Firestore
  Future<void> _updateUserRole(String docId, String currentRole, String newRole, String fullname) async {
    developer.log(
      'Attempting to update role for user: $fullname (docId: $docId) from $currentRole to $newRole',
      name: 'AssignRoleScreen.UpdateRole',
    );
    
    if (currentRole == newRole) {
      developer.log('Role is already $newRole, skipping update', name: 'AssignRoleScreen.UpdateRole');
      _showSnackBar('User already has this role', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      developer.log('Updating Firestore document...', name: 'AssignRoleScreen.UpdateRole');
      
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(docId)
          .update({'role': newRole});

      developer.log(
        'Successfully updated role for $fullname to $newRole',
        name: 'AssignRoleScreen.UpdateRole',
      );

      if (mounted) {
        _showSnackBar(
          'Successfully updated $fullname to $newRole',
          Colors.green,
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error updating role for $fullname: $e',
        name: 'AssignRoleScreen.UpdateRole',
        error: e,
        stackTrace: stackTrace,
      );
      
      if (mounted) {
        _showSnackBar(
          'Error updating role: $e',
          Colors.red,
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show confirmation dialog before updating role
  Future<void> _confirmRoleUpdate(
    String docId,
    String currentRole,
    String newRole,
    String fullname,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Role Update'),
        content: Text(
          'Are you sure you want to change $fullname\'s role from $currentRole to $newRole?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 66, 10, 113),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateUserRole(docId, currentRole, newRole, fullname);
    }
  }

  /// Build role badge
  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    IconData badgeIcon;

    switch (role) {
      case 'Admin':
        badgeColor = const Color.fromARGB(255, 156, 39, 176);
        badgeIcon = Icons.verified_user;
        break;
      case 'HR':
        badgeColor = const Color.fromARGB(255, 98, 15, 153);
        badgeIcon = Icons.admin_panel_settings;
        break;
      case 'Supervisor':
        badgeColor = const Color.fromARGB(255, 46, 125, 50);
        badgeIcon = Icons.supervisor_account;
        break;
      case 'Accountant':
        badgeColor = const Color.fromARGB(255, 230, 81, 0);
        badgeIcon = Icons.account_balance_wallet;
        break;
      case 'Employee':
      default:
        badgeColor = const Color.fromARGB(255, 93, 4, 128);
        badgeIcon = Icons.person;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 250),
      appBar: AppBar(
        title: const Text(
          'Manage User Roles',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 66, 10, 113),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header with gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 66, 10, 113),
                  Color.fromARGB(255, 132, 69, 161),
                ],
              ),
            ),
            child: Column(
              children: [
                // Search and Filter Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _searchQuery = value.toLowerCase());
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search by full name or email...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Role Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _roles.map((role) {
                            final isSelected = _selectedRoleFilter == role;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(role),
                                selected: isSelected,
                                onSelected: (selected) {
                                  developer.log(
                                    'Role filter changed to: $role',
                                    name: 'AssignRoleScreen.Filter',
                                  );
                                  setState(() => _selectedRoleFilter = role);
                                },
                                backgroundColor: Colors.white.withValues(alpha: 0.95),
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color.fromARGB(255, 66, 10, 113)
                                      : const Color.fromARGB(255, 66, 10, 113),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                                checkmarkColor: const Color.fromARGB(255, 66, 10, 113),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color.fromARGB(255, 66, 10, 113)
                                      : Colors.white.withValues(alpha: 0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Table
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .snapshots(),
              builder: (context, snapshot) {
                developer.log(
                  'StreamBuilder state: ${snapshot.connectionState}',
                  name: 'AssignRoleScreen.StreamBuilder',
                );
                
                if (snapshot.hasError) {
                  developer.log(
                    'StreamBuilder error: ${snapshot.error}',
                    name: 'AssignRoleScreen.StreamBuilder',
                    error: snapshot.error,
                  );
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading users',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _checkFirestoreConnection,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 66, 10, 113),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  developer.log(
                    'Waiting for data from Firestore...',
                    name: 'AssignRoleScreen.StreamBuilder',
                  );
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 66, 10, 113),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  developer.log(
                    'No data received. Has data: ${snapshot.hasData}, Docs count: ${snapshot.data?.docs.length ?? 0}',
                    name: 'AssignRoleScreen.StreamBuilder',
                  );
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found in Users collection',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please check your Firestore database',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _checkFirestoreConnection,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 66, 10, 113),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                developer.log(
                  'Received ${snapshot.data!.docs.length} documents from Firestore',
                  name: 'AssignRoleScreen.StreamBuilder',
                );

                // Log sample document structure
                if (snapshot.data!.docs.isNotEmpty) {
                  final sampleDoc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  developer.log(
                    'Sample document structure: ${sampleDoc.keys.toList()}',
                    name: 'AssignRoleScreen.StreamBuilder',
                  );
                  developer.log(
                    'Sample document data: $sampleDoc',
                    name: 'AssignRoleScreen.StreamBuilder',
                  );
                }

                // Filter users based on search query and role filter
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullname = (data['fullname'] ?? data['fullName'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final role = data['role'] ?? 'Employee';

                  final matchesSearch = _searchQuery.isEmpty ||
                      fullname.contains(_searchQuery) ||
                      email.contains(_searchQuery);

                  final matchesRole = _selectedRoleFilter == 'All' ||
                      role == _selectedRoleFilter;

                  return matchesSearch && matchesRole;
                }).toList();

                developer.log(
                  'After filtering: ${users.length} users (Search: "$_searchQuery", Role: $_selectedRoleFilter)',
                  name: 'AssignRoleScreen.StreamBuilder',
                );

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users match your filters',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Debug Info Panel
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Showing ${users.length} of ${snapshot.data!.docs.length} total users',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty || _selectedRoleFilter != 'All')
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                      _selectedRoleFilter = 'All';
                                    });
                                    developer.log('Filters cleared', name: 'AssignRoleScreen.Filter');
                                  },
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear Filters', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue.shade700,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Table Header Card
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 66, 10, 113),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'FULL NAME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'EMAIL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'ROLE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  'ACTIONS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Rows
                        ...users.asMap().entries.map((entry) {
                          final index = entry.key;
                          final doc = entry.value;
                          final data = doc.data() as Map<String, dynamic>;
                          // Support both 'fullname' and 'fullName' field names
                          final fullname = data['fullname'] ?? data['fullName'] ?? 'Unknown';
                          final email = data['email'] ?? 'No email';
                          final role = data['role'] ?? 'Employee';
                          final isCurrentUser =
                              data['uid'] == FirebaseAuth.instance.currentUser?.uid;

                          // Log first few users for debugging
                          if (index < 3) {
                            developer.log(
                              'User #$index - Full Name: $fullname, Email: $email, Role: $role, DocID: ${doc.id}',
                              name: 'AssignRoleScreen.UserData',
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              borderRadius: index == users.length - 1
                                  ? const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    )
                                  : null,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                // Full Name
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            const Color.fromARGB(255, 66, 10, 113)
                                                .withValues(alpha: 0.1),
                                        child: Text(
                                          fullname.isNotEmpty ? fullname[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            color: Color.fromARGB(255, 66, 10, 113),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (isCurrentUser)
                                              Text(
                                                '(You)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Email
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Role Badge
                                Expanded(
                                  flex: 2,
                                  child: _buildRoleBadge(role),
                                ),

                                // Actions (Three-dot menu)
                                SizedBox(
                                  width: 60,
                                  child: PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey.shade600,
                                    ),
                                    tooltip: 'Update Role',
                                    onSelected: (newRole) {
                                      _confirmRoleUpdate(
                                        doc.id,
                                        role,
                                        newRole,
                                        fullname,
                                      );
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem<String>(
                                        value: 'Admin',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.verified_user,
                                              size: 18,
                                              color: Color.fromARGB(255, 156, 39, 176),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Admin'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'HR',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.admin_panel_settings,
                                              size: 18,
                                              color: Color.fromARGB(255, 98, 15, 153),
                                            ),
                                            SizedBox(width: 12),
                                            Text('HR'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Supervisor',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.supervisor_account,
                                              size: 18,
                                              color: Color.fromARGB(255, 46, 125, 50),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Supervisor'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Accountant',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 18,
                                              color: Color.fromARGB(255, 230, 81, 0),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Accountant'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'Employee',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Color.fromARGB(255, 93, 4, 128),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Employee'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                    // Loading overlay
                    if (_isLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}