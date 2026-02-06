import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

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
  String? _currentUserRole;
  String? _currentUserDocId;
  
  // Logger instance
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
    _logger.i('AssignRoleScreen initialized');
    _logger.i('initState: Starting initialization sequence');
    _checkFirestoreConnection();
    _loadCurrentUserRole();
    _logger.i('initState: Initialization sequence completed');
  }

  @override
  void dispose() {
    _logger.i('dispose: Starting cleanup');
    _searchController.dispose();
    _logger.i('dispose: Search controller disposed');
    _logger.i('AssignRoleScreen disposed');
    super.dispose();
  }

  /// Load current user's role to determine permissions
  Future<void> _loadCurrentUserRole() async {
    _logger.i('_loadCurrentUserRole: Method called');
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      _logger.i('_loadCurrentUserRole: Retrieved FirebaseAuth currentUser');
      
      if (currentUser == null) {
        _logger.i('_loadCurrentUserRole: No authenticated user found');
        return;
      }

      _logger.i('_loadCurrentUserRole: Current user UID: ${currentUser.uid}');
      _logger.i('_loadCurrentUserRole: Current user email: ${currentUser.email}');

      // Find user document by UID
      _logger.i('_loadCurrentUserRole: Querying Users collection for UID: ${currentUser.uid}');
      final userQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      _logger.i('_loadCurrentUserRole: Query completed. Docs found: ${userQuery.docs.length}');

      if (userQuery.docs.isNotEmpty) {
        final userDoc = userQuery.docs.first;
        final userData = userDoc.data();
        
        _logger.i('_loadCurrentUserRole: User document data: $userData');
        
        setState(() {
          _currentUserRole = userData['role'];
          _currentUserDocId = userDoc.id;
        });

        _logger.i('_loadCurrentUserRole: Current user role loaded successfully - Role: $_currentUserRole, DocId: $_currentUserDocId');
      } else {
        _logger.i('_loadCurrentUserRole: User document not found in Users collection');
      }
    } catch (e, stackTrace) {
      _logger.e('_loadCurrentUserRole: Exception occurred - $e', error: e, stackTrace: stackTrace);
    }
    _logger.i('_loadCurrentUserRole: Method completed');
  }

  /// Get available roles based on current user's permissions
  List<String> _getAvailableRoles() {
    _logger.i('_getAvailableRoles: Method called with current role: $_currentUserRole');
    
    List<String> roles = [];
    
    if (_currentUserRole == 'Admin') {
      roles = ['Admin', 'HR', 'Supervisor', 'Accountant'];
      _logger.i('_getAvailableRoles: Admin user - Returning all assignable roles: $roles');
    } else if (_currentUserRole == 'HR') {
      roles = ['Supervisor', 'Accountant'];
      _logger.i('_getAvailableRoles: HR user - Returning limited roles: $roles');
    } else {
      _logger.i('_getAvailableRoles: User role "$_currentUserRole" has no assignment permissions - Returning empty list');
    }
    
    return roles;
  }

  /// Get filter roles including 'All'
  List<String> _getFilterRoles() {
    _logger.i('_getFilterRoles: Method called');
    final filterRoles = ['All', ..._getAvailableRoles()];
    _logger.i('_getFilterRoles: Returning filter roles: $filterRoles');
    return filterRoles;
  }

  /// Check Firestore connection and log collection details
  Future<void> _checkFirestoreConnection() async {
    _logger.i('_checkFirestoreConnection: Starting Firestore connection check');
    try {
      _logger.i('_checkFirestoreConnection: Attempting to fetch first document from Users collection');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .limit(1)
          .get();
      
      _logger.i('_checkFirestoreConnection: Firestore connection successful. Collection exists: ${snapshot.docs.isNotEmpty}');
      
      if (snapshot.docs.isNotEmpty) {
        final sampleData = snapshot.docs.first.data();
        _logger.i('_checkFirestoreConnection: Sample document ID: ${snapshot.docs.first.id}');
        _logger.i('_checkFirestoreConnection: Sample document data: $sampleData');
        _logger.i('_checkFirestoreConnection: Available fields: ${sampleData.keys.toList()}');
      } else {
        _logger.i('_checkFirestoreConnection: Users collection is empty');
      }
      
      // Get total count
      _logger.i('_checkFirestoreConnection: Fetching all documents to count total users');
      final allDocs = await FirebaseFirestore.instance
          .collection('Users')
          .get();
      
      _logger.i('_checkFirestoreConnection: Total users in collection: ${allDocs.docs.length}');
    } catch (e, stackTrace) {
      _logger.e('_checkFirestoreConnection: Error checking Firestore connection - $e', error: e, stackTrace: stackTrace);
    }
    _logger.i('_checkFirestoreConnection: Firestore connection check completed');
  }

  /// Update user role in Firestore (and additional collections for Supervisor)
  Future<void> _updateUserRole(
    String docId,
    String currentRole,
    String newRole,
    String fullname,
    String email,
    String uid,
    {String? department}
  ) async {
    _logger.i('_updateUserRole: Method called - DocId: $docId, User: $fullname, Current Role: $currentRole, New Role: $newRole, Department: $department');
    
    if (currentRole == newRole) {
      _logger.i('_updateUserRole: Role is already $newRole, skipping update');
      _showSnackBar('User already has this role', Colors.orange);
      return;
    }

    _logger.i('_updateUserRole: Setting loading state to true');
    setState(() => _isLoading = true);

    try {
      _logger.i('_updateUserRole: Initiating Firestore batch write');
      
      // Use batch write for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update role in Users collection
      _logger.i('_updateUserRole: Step 1 - Updating Users collection');
      final userRef = FirebaseFirestore.instance.collection('Users').doc(docId);
      _logger.i('_updateUserRole: Preparing batch update - Collection: Users, DocId: $docId, Field: role, Value: $newRole');
      _logger.i('_updateUserRole: Full Firestore path: Users/$docId');
      
      batch.update(userRef, {'role': newRole});
      _logger.i('_updateUserRole: ✓ Added Users/$docId update to batch (role: $newRole)');

      // 2. If new role is Supervisor, add to Supervisors collection
      if (newRole == 'Supervisor' && department != null && department.isNotEmpty) {
        _logger.i('_updateUserRole: Step 2 - New role is Supervisor, calling _handleSupervisorAssignment');
        await _handleSupervisorAssignment(
          batch: batch,
          fullname: fullname,
          email: email,
          uid: uid,
          department: department,
        );
        _logger.i('_updateUserRole: _handleSupervisorAssignment completed');
      }
      
      // 3. If old role was Supervisor but new role is not, remove from Supervisors collection
      if (currentRole == 'Supervisor' && newRole != 'Supervisor') {
        _logger.i('_updateUserRole: Step 3 - Old role was Supervisor, calling _handleSupervisorRemoval');
        await _handleSupervisorRemoval(
          batch: batch,
          uid: uid,
          fullname: fullname,
        );
        _logger.i('_updateUserRole: _handleSupervisorRemoval completed');
      }

      // Commit all changes
      _logger.i('_updateUserRole: ====== BATCH SUMMARY BEFORE COMMIT ======');
      _logger.i('_updateUserRole: Total operations in batch:');
      _logger.i('_updateUserRole:   1. UPDATE Users/$docId (role: $newRole)');
      
      if (newRole == 'Supervisor' && department != null && department.isNotEmpty) {
        _logger.i('_updateUserRole:   2. SET Supervisors/${department}_$uid');
        _logger.i('_updateUserRole:   3. SET/UPDATE Departments/$department (add member: $uid)');
      }
      
      if (currentRole == 'Supervisor' && newRole != 'Supervisor') {
        _logger.i('_updateUserRole:   2. DELETE Supervisors/{docId} (for uid: $uid)');
        _logger.i('_updateUserRole:   3. UPDATE Departments/{dept} (remove member: $uid)');
      }
      
      _logger.i('_updateUserRole: ====== STARTING BATCH COMMIT ======');
      _logger.i('_updateUserRole: About to commit batch write to Firestore');
      
      try {
        await batch.commit();
        _logger.i('_updateUserRole: ====== BATCH COMMIT SUCCESSFUL ======');
      } catch (batchError, batchStackTrace) {
        _logger.i('_updateUserRole: ====== BATCH COMMIT FAILED ======');
        _logger.e('_updateUserRole: FIRESTORE BATCH ERROR - $batchError', error: batchError, stackTrace: batchStackTrace);
        _logger.i('_updateUserRole: Error type: ${batchError.runtimeType}');
        
        // Re-throw to be caught by outer catch block
        rethrow;
      }

      _logger.i('_updateUserRole: Successfully updated role for $fullname (UID: $uid) to $newRole');

      if (mounted) {
        _logger.i('_updateUserRole: Widget still mounted, showing success snackbar');
        _showSnackBar(
          'Successfully updated $fullname to $newRole',
          Colors.green,
        );
      } else {
        _logger.i('_updateUserRole: Widget not mounted, skipping snackbar');
      }
    } catch (e, stackTrace) {
      _logger.e('_updateUserRole: Exception occurred while updating role for $fullname - $e', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        _logger.i('_updateUserRole: Widget still mounted, showing error snackbar');
        _showSnackBar(
          'Error updating role: $e',
          Colors.red,
        );
      } else {
        _logger.i('_updateUserRole: Widget not mounted, skipping error snackbar');
      }
    } finally {
      _logger.i('_updateUserRole: Setting loading state to false');
      setState(() => _isLoading = false);
      _logger.i('_updateUserRole: Method completed');
    }
  }

  /// Handle Supervisor role assignment
  Future<void> _handleSupervisorAssignment({
    required WriteBatch batch,
    required String fullname,
    required String email,
    required String uid,
    required String department,
  }) async {
    _logger.i('_handleSupervisorAssignment: Method called - User: $fullname, UID: $uid, Department: $department');

    // Create supervisor document ID: Department_uid
    final supervisorDocId = '${department}_$uid';
    _logger.i('_handleSupervisorAssignment: Created supervisor document ID: $supervisorDocId');
    
    // Add supervisor to Supervisors collection
    final supervisorRef = FirebaseFirestore.instance
        .collection('Supervisors')
        .doc(supervisorDocId);
    
    final supervisorData = {
      'fullname': fullname,
      'email': email,
      'department': department,
      'uid': uid,
      'assignedAt': FieldValue.serverTimestamp(),
    };
    
    _logger.i('_handleSupervisorAssignment: Preparing batch set operation');
    _logger.i('_handleSupervisorAssignment: Collection: Supervisors, DocId: $supervisorDocId');
    _logger.i('_handleSupervisorAssignment: Full Firestore path: Supervisors/$supervisorDocId');
    _logger.i('_handleSupervisorAssignment: Data to be written: $supervisorData');
    
    batch.set(supervisorRef, supervisorData);
    
    _logger.i('_handleSupervisorAssignment: ✓ Successfully added Supervisors/$supervisorDocId to batch');

    // Add department to Departments collection
    _logger.i('_handleSupervisorAssignment: Calling _addToDepartmentCollection for department: $department');
    await _addToDepartmentCollection(
      batch: batch,
      department: department,
      fullname: fullname,
      email: email,
      uid: uid,
    );
    _logger.i('_handleSupervisorAssignment: _addToDepartmentCollection completed');
    _logger.i('_handleSupervisorAssignment: Method completed');
  }

  /// Handle Supervisor role removal
  Future<void> _handleSupervisorRemoval({
    required WriteBatch batch,
    required String uid,
    required String fullname,
  }) async {
    _logger.i('_handleSupervisorRemoval: Method called - User: $fullname, UID: $uid');

    try {
      // Find and delete the supervisor document
      _logger.i('_handleSupervisorRemoval: Querying Supervisors collection for UID: $uid');
      _logger.i('_handleSupervisorRemoval: Query: Supervisors.where(uid == $uid).limit(1)');
      
      final supervisorQuery = await FirebaseFirestore.instance
          .collection('Supervisors')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      _logger.i('_handleSupervisorRemoval: ✓ Query completed successfully');
      _logger.i('_handleSupervisorRemoval: Supervisor docs found: ${supervisorQuery.docs.length}');

      if (supervisorQuery.docs.isNotEmpty) {
        final supervisorDoc = supervisorQuery.docs.first;
        final supervisorData = supervisorDoc.data();
        final department = supervisorData['department'] as String?;

        _logger.i('_handleSupervisorRemoval: Found supervisor document');
        _logger.i('_handleSupervisorRemoval: Document ID: ${supervisorDoc.id}');
        _logger.i('_handleSupervisorRemoval: Full Firestore path: Supervisors/${supervisorDoc.id}');
        _logger.i('_handleSupervisorRemoval: Department extracted: $department');
        _logger.i('_handleSupervisorRemoval: Supervisor data: $supervisorData');

        // Delete from Supervisors collection
        _logger.i('_handleSupervisorRemoval: Preparing to delete Supervisors/${supervisorDoc.id}');
        
        batch.delete(supervisorDoc.reference);
        
        _logger.i('_handleSupervisorRemoval: ✓ Added Supervisors/${supervisorDoc.id} deletion to batch');

        // Remove from Departments collection
        if (department != null) {
          _logger.i('_handleSupervisorRemoval: Calling _removeFromDepartmentCollection for department: $department');
          await _removeFromDepartmentCollection(
            batch: batch,
            department: department,
            uid: uid,
          );
          _logger.i('_handleSupervisorRemoval: _removeFromDepartmentCollection completed');
        } else {
          _logger.i('_handleSupervisorRemoval: No department found in supervisor document, skipping department removal');
        }
      } else {
        _logger.i('_handleSupervisorRemoval: No supervisor document found for UID: $uid');
      }
    } catch (e, stackTrace) {
      _logger.e('_handleSupervisorRemoval: Exception occurred - $e', error: e, stackTrace: stackTrace);
    }
    _logger.i('_handleSupervisorRemoval: Method completed');
  }

  /// Add user to Departments collection
  Future<void> _addToDepartmentCollection({
    required WriteBatch batch,
    required String department,
    required String fullname,
    required String email,
    required String uid,
  }) async {
    _logger.i('_addToDepartmentCollection: Method called - Department: $department, User: $fullname, UID: $uid');

    final departmentRef = FirebaseFirestore.instance
        .collection('Departments')
        .doc(department);

    _logger.i('_addToDepartmentCollection: Checking if Departments/$department document exists');
    _logger.i('_addToDepartmentCollection: Full Firestore path: Departments/$department');

    // Check if department document exists
    DocumentSnapshot departmentDoc;
    try {
      departmentDoc = await departmentRef.get();
      _logger.i('_addToDepartmentCollection: ✓ Successfully read Departments/$department - Exists: ${departmentDoc.exists}');
    } catch (readError, readStackTrace) {
      _logger.e('_addToDepartmentCollection: ✗ ERROR reading Departments/$department - $readError', error: readError, stackTrace: readStackTrace);
      rethrow;
    }
    
    _logger.i('_addToDepartmentCollection: Department document exists: ${departmentDoc.exists}');

    if (!departmentDoc.exists) {
      // Create new department document
      final newDepartmentData = {
        'name': department,
        'createdAt': FieldValue.serverTimestamp(),
        'members': {
          uid: {
            'fullname': fullname,
            'email': email,
            'uid': uid,
            'addedAt': FieldValue.serverTimestamp(),
          }
        }
      };
      
      _logger.i('_addToDepartmentCollection: Creating new department document');
      _logger.i('_addToDepartmentCollection: Collection: Departments, DocId: $department');
      _logger.i('_addToDepartmentCollection: Full Firestore path: Departments/$department');
      _logger.i('_addToDepartmentCollection: Data to be written: $newDepartmentData');
      
      batch.set(departmentRef, newDepartmentData);
      
      _logger.i('_addToDepartmentCollection: ✓ Added new department creation to batch (Departments/$department)');
    } else {
      // Add member to existing department
      final memberData = {
        'members.$uid': {
          'fullname': fullname,
          'email': email,
          'uid': uid,
          'addedAt': FieldValue.serverTimestamp(),
        }
      };
      
      _logger.i('_addToDepartmentCollection: Adding member to existing department');
      _logger.i('_addToDepartmentCollection: Collection: Departments, DocId: $department');
      _logger.i('_addToDepartmentCollection: Full Firestore path: Departments/$department');
      _logger.i('_addToDepartmentCollection: Field to update: members.$uid');
      _logger.i('_addToDepartmentCollection: Data to be written: $memberData');
      
      batch.update(departmentRef, memberData);
      
      _logger.i('_addToDepartmentCollection: ✓ Added member update to batch (Departments/$department)');
    }
    
    _logger.i('_addToDepartmentCollection: Method completed');
  }

  /// Remove user from Departments collection
  Future<void> _removeFromDepartmentCollection({
    required WriteBatch batch,
    required String department,
    required String uid,
  }) async {
    _logger.i('_removeFromDepartmentCollection: Method called - Department: $department, UID: $uid');

    final departmentRef = FirebaseFirestore.instance
        .collection('Departments')
        .doc(department);

    _logger.i('_removeFromDepartmentCollection: Preparing to remove member from Departments/$department');
    _logger.i('_removeFromDepartmentCollection: Full Firestore path: Departments/$department');
    _logger.i('_removeFromDepartmentCollection: Field to delete: members.$uid');

    // Remove member from department
    batch.update(departmentRef, {
      'members.$uid': FieldValue.delete(),
    });

    _logger.i('_removeFromDepartmentCollection: ✓ Added member removal to batch (Departments/$department, field: members.$uid)');
    
    _logger.i('_removeFromDepartmentCollection: Method completed');
  }

  void _showSnackBar(String message, Color backgroundColor) {
    _logger.i('_showSnackBar: Showing snackbar - Message: "$message", Color: $backgroundColor');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    
    _logger.i('_showSnackBar: Snackbar displayed');
  }

  /// Show confirmation dialog before updating role
  Future<void> _confirmRoleUpdate(
    String docId,
    String currentRole,
    String newRole,
    String fullname,
    String email,
    String uid,
  ) async {
    _logger.i('_confirmRoleUpdate: Method called - User: $fullname, Current Role: $currentRole, New Role: $newRole');
    
    // If assigning Supervisor role, ask for department
    String? department;
    
    if (newRole == 'Supervisor') {
      _logger.i('_confirmRoleUpdate: New role is Supervisor, showing department input dialog');
      
      department = await _showDepartmentInputDialog(fullname);
      
      _logger.i('_confirmRoleUpdate: Department input dialog closed - Department: $department');
      
      if (department == null || department.isEmpty) {
        _logger.i('_confirmRoleUpdate: Department input cancelled or empty, aborting role update');
        return; // User cancelled or didn't enter department
      }
    }

    // Check if widget is still mounted after async operation
    if (!mounted) {
      _logger.i('_confirmRoleUpdate: Widget not mounted after async operation, aborting');
      return;
    }

    _logger.i('_confirmRoleUpdate: Showing confirmation dialog');
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Role Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to change $fullname\'s role from $currentRole to $newRole?',
            ),
            if (newRole == 'Supervisor' && department != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            department,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.i('_confirmRoleUpdate: User clicked Cancel');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.i('_confirmRoleUpdate: User clicked Confirm');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 66, 10, 113),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    _logger.i('_confirmRoleUpdate: Confirmation dialog closed - Confirmed: $confirmed');

    if (confirmed == true && mounted) {
      _logger.i('_confirmRoleUpdate: Role update confirmed, calling _updateUserRole');
      
      await _updateUserRole(
        docId,
        currentRole,
        newRole,
        fullname,
        email,
        uid,
        department: department,
      );
      
      _logger.i('_confirmRoleUpdate: _updateUserRole completed');
    } else if (confirmed != true) {
      _logger.i('_confirmRoleUpdate: Role update cancelled by user');
    } else if (!mounted) {
      _logger.i('_confirmRoleUpdate: Widget not mounted, skipping role update');
    }
    
    _logger.i('_confirmRoleUpdate: Method completed');
  }

  /// Show dialog to input department for Supervisor role
  Future<String?> _showDepartmentInputDialog(String fullname) async {
    _logger.i('_showDepartmentInputDialog: Method called for user: $fullname');
    
    final TextEditingController departmentController = TextEditingController();
    _logger.i('_showDepartmentInputDialog: Department controller created');
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.business,
              color: const Color.fromARGB(255, 46, 125, 50),
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Assign Department',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigning Supervisor role to:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fullname,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 66, 10, 113),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: departmentController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Department Name',
                hintText: 'e.g., Engineering, Sales, HR',
                prefixIcon: const Icon(Icons.domain),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color.fromARGB(255, 66, 10, 113),
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (value) {
                _logger.i('_showDepartmentInputDialog: TextField submitted with value: "$value"');
                if (value.trim().isNotEmpty) {
                  Navigator.pop(context, value.trim());
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.i('_showDepartmentInputDialog: User clicked Cancel');
              Navigator.pop(context, null);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final department = departmentController.text.trim();
              _logger.i('_showDepartmentInputDialog: User clicked Assign - Department: "$department"');
              
              if (department.isNotEmpty) {
                _logger.i('_showDepartmentInputDialog: Department is valid, closing dialog');
                Navigator.pop(context, department);
              } else {
                _logger.i('_showDepartmentInputDialog: Department is empty, showing validation snackbar');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a department name'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 66, 10, 113),
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    ).then((value) {
      _logger.i('_showDepartmentInputDialog: Dialog closed with value: $value');
      _logger.i('_showDepartmentInputDialog: Disposing department controller');
      departmentController.dispose();
      return value;
    });
  }

  /// Build role badge
  Widget _buildRoleBadge(String role) {
    _logger.i('_buildRoleBadge: Building badge for role: $role');
    
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

    _logger.i('_buildRoleBadge: Badge properties - Color: $badgeColor, Icon: $badgeIcon');

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
    _logger.i('build: Method called');
    _logger.i('build: Current user role: $_currentUserRole');
    
    // Show loading while determining user role
    if (_currentUserRole == null) {
      _logger.i('build: Current user role is null, showing loading screen');
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
        body: const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 66, 10, 113),
          ),
        ),
      );
    }

    // Check if user has permission to access this screen
    if (_currentUserRole != 'Admin' && _currentUserRole != 'HR') {
      _logger.i('build: User does not have permission to access this screen - Role: $_currentUserRole');
      
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 245, 245, 250),
        appBar: AppBar(
          title: const Text(
            'Access Denied',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 66, 10, 113),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Only Admin and HR users can access this screen.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _logger.i('build: User clicked Go Back button');
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 66, 10, 113),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    _logger.i('build: User has permission, building main UI');

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 250),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage User Roles',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              'Logged in as: $_currentUserRole',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
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
                          _logger.i('build: Search query changed to: "$value"');
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
                                    _logger.i('build: Clear search button clicked');
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

                      // Role Filter Chips (based on current user permissions)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _getFilterRoles().map((role) {
                            final isSelected = _selectedRoleFilter == role;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(role),
                                selected: isSelected,
                                onSelected: (selected) {
                                  _logger.i('build: Role filter chip selected - Role: $role, Selected: $selected');
                                  _logger.i('Role filter changed to: $role');
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
                _logger.i('StreamBuilder: Connection state: ${snapshot.connectionState}');
                
                if (snapshot.hasError) {
                  _logger.e(
                    'StreamBuilder: Error occurred - ${snapshot.error}',
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
                          onPressed: () {
                            _logger.i('StreamBuilder: Check Connection button clicked');
                            _checkFirestoreConnection();
                          },
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
                  _logger.i('StreamBuilder: Waiting for Firestore data');
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 66, 10, 113),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  _logger.i('StreamBuilder: No data received - Has data: ${snapshot.hasData}, Docs count: ${snapshot.data?.docs.length ?? 0}');
                  
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
                          onPressed: () {
                            _logger.i('StreamBuilder: Check Connection button clicked (no data state)');
                            _checkFirestoreConnection();
                          },
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

                _logger.i('StreamBuilder: Received ${snapshot.data!.docs.length} documents from Firestore');

                // Filter users based on search query and role filter
                _logger.i('StreamBuilder: Applying filters - Search: "$_searchQuery", Role: $_selectedRoleFilter');
                
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

                _logger.i('StreamBuilder: Filtered users count: ${users.length} (from ${snapshot.data!.docs.length} total)');

                if (users.isEmpty) {
                  _logger.i('StreamBuilder: No users match current filters');
                  
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

                _logger.i('StreamBuilder: Building user list UI with ${users.length} users');

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
                                    _logger.i('StreamBuilder: Clear Filters button clicked');
                                    setState(() {
                                      _searchQuery = '';
                                      _searchController.clear();
                                      _selectedRoleFilter = 'All';
                                    });
                                    _logger.i('Filters cleared');
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
                          final fullname = data['fullname'] ?? data['fullName'] ?? 'Unknown';
                          final email = data['email'] ?? 'No email';
                          final role = data['role'] ?? 'Employee';
                          final uid = data['uid'] ?? '';
                          final isCurrentUser = doc.id == _currentUserDocId;

                          // Get available roles for this user based on current user permissions
                          final availableRoles = _getAvailableRoles();

                          if (index < 3) {
                            _logger.i('StreamBuilder: User #$index - Name: $fullname, Email: $email, Role: $role, DocID: ${doc.id}, UID: $uid, IsCurrentUser: $isCurrentUser');
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

                                // Actions (Three-dot menu) - Only show roles user can assign
                                SizedBox(
                                  width: 60,
                                  child: PopupMenuButton<String>(
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey.shade600,
                                    ),
                                    tooltip: 'Update Role',
                                    enabled: availableRoles.isNotEmpty,
                                    onSelected: (newRole) {
                                      _logger.i('StreamBuilder: PopupMenu role selected - User: $fullname, New Role: $newRole');
                                      _confirmRoleUpdate(
                                        doc.id,
                                        role,
                                        newRole,
                                        fullname,
                                        email,
                                        uid,
                                      );
                                    },
                                    itemBuilder: (context) => availableRoles.map((roleOption) {
                                      IconData icon;
                                      Color color;

                                      switch (roleOption) {
                                        case 'Admin':
                                          icon = Icons.verified_user;
                                          color = const Color.fromARGB(255, 156, 39, 176);
                                          break;
                                        case 'HR':
                                          icon = Icons.admin_panel_settings;
                                          color = const Color.fromARGB(255, 98, 15, 153);
                                          break;
                                        case 'Supervisor':
                                          icon = Icons.supervisor_account;
                                          color = const Color.fromARGB(255, 46, 125, 50);
                                          break;
                                        case 'Accountant':
                                          icon = Icons.account_balance_wallet;
                                          color = const Color.fromARGB(255, 230, 81, 0);
                                          break;
                                        default:
                                          icon = Icons.person;
                                          color = const Color.fromARGB(255, 93, 4, 128);
                                      }

                                      return PopupMenuItem<String>(
                                        value: roleOption,
                                        child: Row(
                                          children: [
                                            Icon(icon, size: 18, color: color),
                                            const SizedBox(width: 12),
                                            Text(roleOption),
                                          ],
                                        ),
                                      );
                                    }).toList(),
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