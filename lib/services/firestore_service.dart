import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:logger/logger.dart';

class FirestoreService {
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

  /// Constructor - Configure Firestore settings for better performance
  FirestoreService() {
    _configureFirestore();
  }

  /// Configure Firestore settings
  void _configureFirestore() {
    try {
      // Enable offline persistence (helps with connectivity issues)
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _logger.i('✅ Firestore configured successfully');
    } catch (e) {
      _logger.w('Firestore settings already configured or error: $e');
    }
  }

  /// Test Firestore connectivity
  Future<bool> testConnection() async {
    try {
      _logger.i('Testing Firestore connectivity...');
      
      // Try to read a non-existent document (lightweight operation)
      await _firestore
          .collection('Draft')
          .doc('_connection_test_')
          .get()
          .timeout(const Duration(seconds: 5));
      
      _logger.i('✅ Firestore connection successful');
      return true;
    } catch (e) {
      _logger.e('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Generates a document ID from employee name
  /// Replaces spaces with underscores and makes it lowercase for consistency
  String _generateDocIdFromName(String fullName) {
    if (fullName.isEmpty) {
      _logger.w('Empty name provided, generating temp ID');
      return 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    // Replace spaces with underscores and convert to lowercase
    final docId = fullName.trim().replaceAll(' ', '_').toLowerCase();
    _logger.d('Generated document ID: $docId from name: $fullName');
    return docId;
  }

  /// Determines the collection name based on employee status
  /// - 'draft' status → 'Draft' collection
  /// - 'submitted', 'approved', 'rejected' → 'EmployeeDetails' collection
  String _getCollectionName(String status) {
    if (status == 'draft') {
      return 'Draft';
    }
    return 'EmployeeDetails';
  }

  /// Saves or updates employee onboarding data to Firestore
  /// Returns the document ID
  Future<String> saveEmployeeOnboarding(EmployeeOnboarding employee) async {
    _logger.i('=== FIRESTORE SAVE INITIATED ===');
    _logger.d('Employee status: ${employee.status}');
    _logger.d('Employee name: ${employee.personalInfo.fullName}');
    _logger.d('Existing ID: ${employee.id}');

    try {
      // Test connection first
      _logger.d('Testing Firestore connection...');
      final isConnected = await testConnection();
      if (!isConnected) {
        throw Exception('No Firestore connection. Please check your internet and Firebase configuration.');
      }

      // Generate document ID from employee name
      final docId = employee.id.isNotEmpty 
          ? employee.id 
          : _generateDocIdFromName(employee.personalInfo.fullName);
      
      // Determine collection based on status
      final collectionName = _getCollectionName(employee.status);
      
      _logger.i('Target collection: $collectionName');
      _logger.i('Document ID: $docId');

      // Create the employee object with the correct ID
      final employeeToSave = EmployeeOnboarding(
        id: docId,
        status: employee.status,
        createdAt: employee.createdAt,
        updatedAt: employee.updatedAt ?? DateTime.now(),
        submittedAt: employee.submittedAt,
        personalInfo: employee.personalInfo,
        employmentDetails: employee.employmentDetails,
        statutoryDocs: employee.statutoryDocs,
        payrollDetails: employee.payrollDetails,
        academicDocs: employee.academicDocs,
        contractsForms: employee.contractsForms,
        benefitsInsurance: employee.benefitsInsurance,
        workTools: employee.workTools,
      );

      // Convert to map for Firestore
      _logger.d('Converting employee data to map...');
      final data = employeeToSave.toMap();
      
      _logger.d('Converted to map - keys: ${data.keys.join(", ")}');
      _logger.d('Sample data - status: ${data['status']}, id: ${data['id']}');

      // Check if this is a status change (draft → submitted)
      if (employee.id.isNotEmpty && employee.status != 'draft') {
        _logger.i('Status changed - checking for existing draft to delete');
        try {
          // Delete from Draft collection if it exists
          await _firestore
              .collection('Draft')
              .doc(docId)
              .delete()
              .timeout(const Duration(seconds: 10));
          _logger.i('Deleted old draft document');
        } catch (e) {
          _logger.w('No draft to delete or error deleting: $e');
        }
      }

      // Save to the appropriate collection with timeout
      _logger.d('Writing to Firestore: $collectionName/$docId');
      _logger.d('Data size: ${data.length} fields');
      
      try {
        // Use set with merge option and add timeout
        await _firestore
            .collection(collectionName)
            .doc(docId)
            .set(data, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('Firestore write operation timed out after 15 seconds');
              },
            );
        
        _logger.i('✅ Successfully saved to Firestore!');
        _logger.d('Collection: $collectionName');
        _logger.d('Document ID: $docId');

        // Verify the write by reading it back
        _logger.d('Verifying write...');
        final verifyDoc = await _firestore
            .collection(collectionName)
            .doc(docId)
            .get()
            .timeout(const Duration(seconds: 5));
        
        if (verifyDoc.exists) {
          _logger.i('✅ Write verified - document exists in Firestore');
        } else {
          _logger.w('⚠️ Write completed but verification failed - document not found');
        }

        return docId;
      } catch (writeError) {
        _logger.e('❌ WRITE ERROR: ${writeError.runtimeType}');
        _logger.e('Error details: $writeError');
        
        // Provide more specific error messages
        if (writeError.toString().contains('PERMISSION_DENIED')) {
          throw Exception('Permission denied. Check your Firestore security rules.');
        } else if (writeError.toString().contains('timeout')) {
          throw Exception('Network timeout. Check your internet connection.');
        } else if (writeError.toString().contains('UNAVAILABLE')) {
          throw Exception('Firestore service unavailable. Please try again.');
        }
        
        rethrow;
      }
    } catch (e, stackTrace) {
      _logger.e('❌ FIRESTORE SAVE ERROR', error: e, stackTrace: stackTrace);
      
      // Provide user-friendly error message
      if (e.toString().contains('No Firestore connection')) {
        rethrow;
      } else if (e.toString().contains('Permission denied')) {
        rethrow;
      } else {
        throw Exception('Failed to save: ${e.toString()}');
      }
    }
  }

  /// Retrieves employee onboarding data by ID
  /// Searches in both Draft and EmployeeDetails collections
  Future<EmployeeOnboarding?> getEmployeeOnboarding(String docId) async {
    _logger.i('=== FETCHING EMPLOYEE ONBOARDING ===');
    _logger.d('Document ID: $docId');

    try {
      // First, try to fetch from Draft collection
      _logger.d('Checking Draft collection...');
      DocumentSnapshot draftDoc = await _firestore
          .collection('Draft')
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (draftDoc.exists) {
        _logger.i('✅ Found in Draft collection');
        final data = draftDoc.data() as Map<String, dynamic>;
        return EmployeeOnboarding.fromMap(data);
      }

      // If not in Draft, check EmployeeDetails collection
      _logger.d('Not in Draft, checking EmployeeDetails collection...');
      DocumentSnapshot employeeDoc = await _firestore
          .collection('EmployeeDetails')
          .doc(docId)
          .get()
          .timeout(const Duration(seconds: 10));
      
      if (employeeDoc.exists) {
        _logger.i('✅ Found in EmployeeDetails collection');
        final data = employeeDoc.data() as Map<String, dynamic>;
        return EmployeeOnboarding.fromMap(data);
      }

      _logger.w('⚠️ Document not found in either collection');
      return null;
    } catch (e, stackTrace) {
      _logger.e('❌ FIRESTORE FETCH ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Retrieves all draft employees
  Future<List<EmployeeOnboarding>> getAllDrafts() async {
    _logger.i('=== FETCHING ALL DRAFTS ===');

    try {
      final snapshot = await _firestore
          .collection('Draft')
          .orderBy('updatedAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 15));

      _logger.i('Found ${snapshot.docs.length} draft(s)');

      return snapshot.docs
          .map((doc) => EmployeeOnboarding.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR FETCHING DRAFTS', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Retrieves all submitted/approved employees
  Future<List<EmployeeOnboarding>> getAllEmployees({String? status}) async {
    _logger.i('=== FETCHING ALL EMPLOYEES ===');
    _logger.d('Filter status: ${status ?? "all"}');

    try {
      Query query = _firestore.collection('EmployeeDetails');
      
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }
      
      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 15));

      _logger.i('Found ${snapshot.docs.length} employee(s)');

      return snapshot.docs
          .map((doc) => EmployeeOnboarding.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR FETCHING EMPLOYEES', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Deletes an employee onboarding record
  Future<void> deleteEmployeeOnboarding(String docId, String status) async {
    _logger.i('=== DELETING EMPLOYEE ONBOARDING ===');
    _logger.d('Document ID: $docId');
    _logger.d('Status: $status');

    try {
      final collectionName = _getCollectionName(status);
      
      await _firestore
          .collection(collectionName)
          .doc(docId)
          .delete()
          .timeout(const Duration(seconds: 10));
      
      _logger.i('✅ Successfully deleted from $collectionName');
    } catch (e, stackTrace) {
      _logger.e('❌ DELETE ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Updates the status of an employee (e.g., from submitted to approved)
  Future<void> updateEmployeeStatus(String docId, String newStatus) async {
    _logger.i('=== UPDATING EMPLOYEE STATUS ===');
    _logger.d('Document ID: $docId');
    _logger.d('New status: $newStatus');

    try {
      // Get current document
      final employee = await getEmployeeOnboarding(docId);
      
      if (employee == null) {
        throw Exception('Employee not found with ID: $docId');
      }

      final oldStatus = employee.status;
      final oldCollection = _getCollectionName(oldStatus);
      final newCollection = _getCollectionName(newStatus);

      _logger.d('Old status: $oldStatus → New status: $newStatus');
      _logger.d('Old collection: $oldCollection → New collection: $newCollection');

      // Create updated employee
      final updatedEmployee = EmployeeOnboarding(
        id: employee.id,
        status: newStatus,
        createdAt: employee.createdAt,
        updatedAt: DateTime.now(),
        submittedAt: newStatus == 'submitted' ? DateTime.now() : employee.submittedAt,
        personalInfo: employee.personalInfo,
        employmentDetails: employee.employmentDetails,
        statutoryDocs: employee.statutoryDocs,
        payrollDetails: employee.payrollDetails,
        academicDocs: employee.academicDocs,
        contractsForms: employee.contractsForms,
        benefitsInsurance: employee.benefitsInsurance,
        workTools: employee.workTools,
      );

      // If collection changes, move the document
      if (oldCollection != newCollection) {
        _logger.i('Moving document from $oldCollection to $newCollection');
        
        // Save to new collection
        await _firestore
            .collection(newCollection)
            .doc(docId)
            .set(updatedEmployee.toMap())
            .timeout(const Duration(seconds: 15));
        
        // Delete from old collection
        await _firestore
            .collection(oldCollection)
            .doc(docId)
            .delete()
            .timeout(const Duration(seconds: 10));
        
        _logger.i('✅ Document moved successfully');
      } else {
        // Just update in the same collection
        _logger.i('Updating in same collection: $oldCollection');
        await _firestore
            .collection(oldCollection)
            .doc(docId)
            .update({
              'status': newStatus,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
              if (newStatus == 'submitted') 'submittedAt': Timestamp.fromDate(DateTime.now()),
            })
            .timeout(const Duration(seconds: 10));
        
        _logger.i('✅ Status updated successfully');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ STATUS UPDATE ERROR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Stream of all drafts for real-time updates
  Stream<List<EmployeeOnboarding>> streamDrafts() {
    _logger.i('Starting stream for drafts');
    
    return _firestore
        .collection('Draft')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          _logger.d('Stream update: ${snapshot.docs.length} draft(s)');
          return snapshot.docs
              .map((doc) => EmployeeOnboarding.fromMap(doc.data()))
              .toList();
        });
  }

  /// Stream of all employees for real-time updates
  Stream<List<EmployeeOnboarding>> streamEmployees({String? status}) {
    _logger.i('Starting stream for employees (status: ${status ?? "all"})');
    
    Query query = _firestore.collection('EmployeeDetails');
    
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }
    
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          _logger.d('Stream update: ${snapshot.docs.length} employee(s)');
          return snapshot.docs
              .map((doc) => EmployeeOnboarding.fromMap(doc.data() as Map<String, dynamic>))
              .toList();
        });
  }
}