import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Hours Entry Dialog for Supervisors to log employee daily hours
/// UPDATED: Properly handles same-day updates and multi-day accumulation
class HoursEntryDialog extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final String department;

  const HoursEntryDialog({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.department,
  });

  @override
  State<HoursEntryDialog> createState() => _HoursEntryDialogState();
}

class _HoursEntryDialogState extends State<HoursEntryDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
    ),
  );

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _entryTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _exitTime = const TimeOfDay(hour: 17, minute: 0);
  bool _isSaving = false;
  double _calculatedHours = 9.0;

  @override
  void initState() {
    super.initState();
    _logger.i('=== 🚀 HOURS ENTRY DIALOG INITIALIZED ===');
    _logger.i('Employee ID (UID): ${widget.employeeId}');
    _logger.i('Employee Name: ${widget.employeeName}');
    _logger.i('Department: ${widget.department}');
    _syncOfflineData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateHours();
  }

  void _calculateHours() {
    final entry = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _entryTime.hour,
      _entryTime.minute,
    );

    final exit = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _exitTime.hour,
      _exitTime.minute,
    );

    final difference = exit.difference(entry);
    
    if (mounted) {
      setState(() {
        _calculatedHours = difference.inMinutes / 60.0;
      });

      _logger.d('📊 Calculated hours: $_calculatedHours for ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    }
  }

  Future<void> _syncOfflineData() async {
    try {
      _logger.i('🔄 Checking offline entries...');
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString('pending_hours_entries');

      if (offlineDataJson == null) {
        _logger.d('✅ No offline entries');
        return;
      }

      final List<dynamic> offlineEntries = jsonDecode(offlineDataJson);
      _logger.i('📦 Found ${offlineEntries.length} offline entries to sync');

      int successCount = 0;
      int failCount = 0;

      for (var entry in offlineEntries) {
        try {
          _logger.d('🔄 Syncing: ${entry['employeeId']} - ${entry['date']}');
          await _saveToFirestore(
            employeeId: entry['employeeId'],
            date: DateTime.parse(entry['date']),
            hours: entry['hours'],
            entryTime: entry['entryTime'],
            exitTime: entry['exitTime'],
          );
          successCount++;
          _logger.i('   ✅ Synced');
        } catch (e) {
          failCount++;
          _logger.e('   ❌ Failed', error: e);
        }
      }

      if (failCount == 0) {
        await prefs.remove('pending_hours_entries');
        _logger.i('✅ All synced ($successCount)');
      } else {
        _logger.w('⚠️ Partial: $successCount synced, $failCount failed');
      }
    } catch (e) {
      _logger.e('❌ Sync error', error: e);
    }
  }

  Future<bool> _checkFirestoreConnectivity() async {
    try {
      _logger.d('🌐 Testing Firestore...');
      await _firestore
          .collection('Users')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));
      _logger.i('✅ Firestore ONLINE');
      return true;
    } catch (e) {
      _logger.e('❌ Firestore OFFLINE', error: e);
      return false;
    }
  }

  Future<void> _saveToFirestore({
    required String employeeId,
    required DateTime date,
    required double hours,
    required String entryTime,
    required String exitTime,
  }) async {
    _logger.i('=== 💾 SAVING TO FIRESTORE ===');
    _logger.i('Employee UID: $employeeId');
    
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final monthKey = DateFormat('yyyy-MM').format(date);
    
    _logger.d('📅 Date Key: $dateKey');
    _logger.d('📅 Month Key: $monthKey');
    _logger.d('⏰ Hours: $hours');
    _logger.d('🕐 Entry: $entryTime → Exit: $exitTime');

    try {
      // STEP 1: Find employee document
      String? documentId;
      String? collectionName;
      
      _logger.i('🔍 STEP 1: Finding employee document...');
      
      // Try EmployeeDetails first
      _logger.d('   Searching EmployeeDetails...');
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        documentId = employeeQuery.docs.first.id;
        collectionName = 'EmployeeDetails';
        _logger.i('   ✅ Found in EmployeeDetails');
        _logger.i('   📄 Doc ID: $documentId');
      } else {
        _logger.d('   Searching Draft...');
        final draftQuery = await _firestore
            .collection('Draft')
            .where('uid', isEqualTo: employeeId)
            .limit(1)
            .get();

        if (draftQuery.docs.isNotEmpty) {
          documentId = draftQuery.docs.first.id;
          collectionName = 'Draft';
          _logger.i('   ✅ Found in Draft');
          _logger.i('   📄 Doc ID: $documentId');
        }
      }

      if (documentId == null || collectionName == null) {
        final errorMsg = 'Employee not found for UID: $employeeId';
        _logger.e('❌ CRITICAL: $errorMsg');
        throw Exception(errorMsg);
      }

      // STEP 2: Check if this date already has an entry (same-day update)
      _logger.i('🔍 STEP 2: Checking for existing entry on $dateKey...');
      final existingEntryRef = _firestore
          .collection(collectionName)
          .doc(documentId)
          .collection('DailyHours')
          .doc(dateKey);

      final existingEntry = await existingEntryRef.get();
      if (existingEntry.exists) {
        final existingHours = (existingEntry.data()?['hours'] ?? 0).toDouble();
        _logger.i('   ⚠️ SAME-DAY UPDATE detected!');
        _logger.i('   Old hours: $existingHours → New hours: $hours');
        _logger.i('   This will REPLACE the old entry (not add to it)');
      } else {
        _logger.i('   ✅ New entry for $dateKey');
      }

      // STEP 3: Save/update daily entry
      _logger.i('💾 STEP 3: Saving daily hours...');
      _logger.d('   Path: $collectionName/$documentId/DailyHours/$dateKey');
      
      await existingEntryRef.set({
        'date': Timestamp.fromDate(date),
        'entryTime': entryTime,
        'exitTime': exitTime,
        'hours': hours,
        'monthKey': monthKey,
        'loggedBy': widget.department,
        'loggedAt': FieldValue.serverTimestamp(),
        'uid': employeeId,
      }, SetOptions(merge: false)); // merge: false = complete replacement

      _logger.i('   ✅ Daily hours saved');

      // Verify save
      final verify = await existingEntryRef.get();
      if (verify.exists) {
        final savedHours = (verify.data()?['hours'] ?? 0).toDouble();
        _logger.i('   ✅ Verified: $savedHours hrs saved');
        if (savedHours != hours) {
          _logger.e('   ❌ MISMATCH! Expected $hours, got $savedHours');
        }
      } else {
        _logger.e('   ❌ WARNING: Document not saved!');
      }

      // STEP 4: Recalculate monthly total from ALL daily entries
      await _updateMonthlyTotal(employeeId, documentId, collectionName, monthKey);
      
    } catch (e, stackTrace) {
      _logger.e('❌ Save error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _updateMonthlyTotal(
    String employeeUid,
    String documentId,
    String collectionName,
    String monthKey,
  ) async {
    try {
      _logger.i('🔄 STEP 4: Updating monthly total...');
      _logger.d('   Collection: $collectionName');
      _logger.d('   Doc ID: $documentId');
      _logger.d('   Month: $monthKey');

      // Get ALL daily entries for this month
      _logger.d('   Fetching all daily entries for $monthKey...');
      final dailyEntries = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .collection('DailyHours')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      _logger.i('   📊 Found ${dailyEntries.docs.length} daily entries');

      if (dailyEntries.docs.isEmpty) {
        _logger.w('   ⚠️ No daily entries found! This should not happen.');
        return;
      }

      // Calculate total by summing ALL days
      double totalHours = 0;
      for (var doc in dailyEntries.docs) {
        final dayHours = (doc.data()['hours'] ?? 0).toDouble();
        totalHours += dayHours;
        _logger.d('      ${doc.id}: $dayHours hrs');
      }

      _logger.i('   📈 TOTAL for $monthKey: $totalHours hrs');

      // Get current document state
      final docRef = _firestore
          .collection(collectionName)
          .doc(documentId);

      final currentDoc = await docRef.get();
      if (currentDoc.exists) {
        final existingHoursWorked = currentDoc.data()?['hoursWorked'];
        _logger.d('   📋 Current hoursWorked: $existingHoursWorked');
      }

      // Update the main document with the calculated total
      _logger.i('   💾 Updating main document...');
      
      await docRef.set({
        'hoursWorked': {
          monthKey: totalHours,
        },
        'lastHoursUpdate': FieldValue.serverTimestamp(),
        'uid': employeeUid,
      }, SetOptions(merge: true));

      _logger.i('   ✅ Monthly total updated');

      // Verify the update
      final verifyDoc = await docRef.get();
      if (verifyDoc.exists) {
        final hoursWorked = verifyDoc.data()?['hoursWorked'];
        _logger.i('   ✅ VERIFICATION:');
        _logger.i('      hoursWorked field: $hoursWorked');
        
        if (hoursWorked != null && hoursWorked is Map) {
          final savedTotal = hoursWorked[monthKey];
          _logger.i('      $monthKey value: $savedTotal');
          
          if (savedTotal == totalHours) {
            _logger.i('   ✅✅✅ SUCCESS: Total matches! ($totalHours hrs)');
          } else {
            _logger.e('   ❌ ERROR: Mismatch! Expected $totalHours, got $savedTotal');
          }
        } else {
          _logger.e('   ❌ ERROR: hoursWorked is not a Map!');
        }
      } else {
        _logger.e('   ❌ ERROR: Document doesn\'t exist after update!');
      }

    } catch (e, stackTrace) {
      _logger.e('❌ Monthly total error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _saveHours() async {
    if (_calculatedHours <= 0) {
      _logger.w('⚠️ Invalid hours: $_calculatedHours');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid hours. Exit time must be after entry time.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _logger.i('=== 🚀 SAVE HOURS INITIATED ===');
    _logger.i('Employee: ${widget.employeeName} (${widget.employeeId})');
    _logger.i('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    _logger.i('Hours: $_calculatedHours');

    setState(() => _isSaving = true);

    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final entryTimeStr = '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}';
      final exitTimeStr = '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}';

      _logger.d('📅 Date: $dateKey');
      _logger.d('🕐 Entry: $entryTimeStr → Exit: $exitTimeStr');

      // Check connectivity
      _logger.i('🌐 Checking connectivity...');
      final isOnline = await _checkFirestoreConnectivity();
      
      if (isOnline) {
        _logger.i('✅ ONLINE - Saving to Firestore');
        
        try {
          await _saveToFirestore(
            employeeId: widget.employeeId,
            date: _selectedDate,
            hours: _calculatedHours,
            entryTime: entryTimeStr,
            exitTime: exitTimeStr,
          );

          _logger.i('✅✅✅ SUCCESS: Hours saved!');

          if (!mounted) return;

          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Hours logged successfully!\n'
                '${widget.employeeName}: $_calculatedHours hrs\n'
                '${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (firestoreError) {
          _logger.e('❌ Firestore error (caching offline)', error: firestoreError);
          
          await _cacheOffline(dateKey, entryTimeStr, exitTimeStr);

          if (!mounted) return;

          Navigator.pop(context, true);
          
          // Get a shorter error message
          String errorMsg = firestoreError.toString();
          if (errorMsg.length > 100) {
            errorMsg = '${errorMsg.substring(0, 97)}...';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Save error: $errorMsg\n'
                'Hours cached offline, will sync later.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        _logger.w('📴 OFFLINE - Caching locally');
        await _cacheOffline(dateKey, entryTimeStr, exitTimeStr);

        if (!mounted) return;

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 Offline: Hours cached, will sync when online'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('❌ CRITICAL ERROR', error: e, stackTrace: stackTrace);

      if (!mounted) return;

      // Handle the error message safely
      String errorMsg = e.toString();
      if (errorMsg.length > 150) {
        errorMsg = '${errorMsg.substring(0, 147)}...';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cacheOffline(String dateKey, String entryTime, String exitTime) async {
    try {
      _logger.i('📦 Caching offline...');
      final prefs = await SharedPreferences.getInstance();
      
      List<dynamic> cachedEntries = [];
      final existingData = prefs.getString('pending_hours_entries');
      if (existingData != null) {
        cachedEntries = jsonDecode(existingData);
        _logger.d('   Existing: ${cachedEntries.length}');
      }

      cachedEntries.add({
        'employeeId': widget.employeeId,
        'date': dateKey,
        'hours': _calculatedHours,
        'entryTime': entryTime,
        'exitTime': exitTime,
        'cachedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString('pending_hours_entries', jsonEncode(cachedEntries));
      _logger.i('✅ Cached (total: ${cachedEntries.length})');
    } catch (e, stackTrace) {
      _logger.e('❌ Cache error', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Color.fromARGB(255, 46, 125, 50),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Work Hours',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.employeeName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _logger.d('❌ Dialog closed');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            _buildDateSelector(),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _buildTimeSelector('Entry Time', _entryTime, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeSelector('Exit Time', _exitTime, false)),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Hours:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_calculatedHours.toStringAsFixed(2)} hrs',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 46, 125, 50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () {
                      _logger.d('🚫 Cancelled');
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveHours,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 46, 125, 50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save Hours',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        _logger.d('📅 Opening date picker...');
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color.fromARGB(255, 46, 125, 50),
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          _logger.i('📅 Date: ${DateFormat('yyyy-MM-dd').format(picked)}');
          setState(() {
            _selectedDate = picked;
            _calculateHours();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: Color.fromARGB(255, 46, 125, 50),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, bool isEntry) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color.fromARGB(255, 46, 125, 50),
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          _logger.i('🕐 $label: ${picked.format(context)}');
          setState(() {
            if (isEntry) {
              _entryTime = picked;
            } else {
              _exitTime = picked;
            }
            _calculateHours();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(
                  Icons.access_time,
                  color: Color.fromARGB(255, 46, 125, 50),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}