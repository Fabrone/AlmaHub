import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Enhanced Hours Entry Dialog for Supervisors
/// 
/// NEW FEATURES:
/// - Automatic meal break deduction
/// - Employment-type specific standard hours
/// - 12-hour daily overtime cap
/// - Work output quality rating (affects performance)
/// - Smart performance calculation combining hours + quality
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
  int _breakMinutes = 60; // Default 1 hour lunch break
  double _workQuality = 80.0; // Default work quality rating (0-100%)
  bool _isSaving = false;
  double _calculatedHours = 8.0; // After break deduction
  String _employmentType = 'Full-Time'; // Will be fetched

  @override
  void initState() {
    super.initState();
    _logger.i('=== 🚀 ENHANCED HOURS ENTRY DIALOG ===');
    _logger.i('Employee: ${widget.employeeName} (${widget.employeeId})');
    _logger.i('Department: ${widget.department}');
    _fetchEmploymentType();
    _syncOfflineData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calculateHours();
  }

  /// Fetch employee's employment type to set appropriate expectations
  Future<void> _fetchEmploymentType() async {
    try {
      _logger.d('🔍 Fetching employment type...');
      
      // Try EmployeeDetails first
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: widget.employeeId)
          .limit(1)
          .get();

      Map<String, dynamic>? data;
      
      if (employeeQuery.docs.isNotEmpty) {
        data = employeeQuery.docs.first.data();
      } else {
        // Try Draft
        final draftQuery = await _firestore
            .collection('Draft')
            .where('uid', isEqualTo: widget.employeeId)
            .limit(1)
            .get();
        
        if (draftQuery.docs.isNotEmpty) {
          data = draftQuery.docs.first.data();
        }
      }

      if (data != null) {
        setState(() {
          _employmentType = data?['employmentDetails']?['employmentType'] ?? 
                          data?['employmentInfo']?['employmentType'] ?? 
                          'Full-Time';
        });
        _logger.i('   ✅ Employment Type: $_employmentType');
      }
    } catch (e) {
      _logger.e('❌ Error fetching employment type', error: e);
    }
  }

  /// Calculate hours with break deduction and overtime cap
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
    final totalMinutes = difference.inMinutes;
    
    // Deduct break time
    final workMinutes = totalMinutes - _breakMinutes;
    final workHours = workMinutes / 60.0;
    
    // Cap at 12 hours per day (overtime limit)
    final cappedHours = workHours.clamp(0.0, 12.0);
    
    if (mounted) {
      setState(() {
        _calculatedHours = cappedHours;
      });

      _logger.d('⏱️ Time Calculation:');
      _logger.d('   Entry → Exit: $totalMinutes minutes');
      _logger.d('   Break: $_breakMinutes minutes');
      _logger.d('   Work Time: $workMinutes minutes ($workHours hrs)');
      if (workHours > 12.0) {
        _logger.w('   ⚠️ CAPPED: $workHours hrs → 12.0 hrs (overtime limit)');
      }
      _logger.d('   Final Hours: $_calculatedHours hrs');
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
            breakMinutes: entry['breakMinutes'] ?? 60,
            workQuality: entry['workQuality'] ?? 80.0,
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
    required int breakMinutes,
    required double workQuality,
  }) async {
    _logger.i('=== 💾 SAVING ENHANCED HOURS DATA ===');
    _logger.i('Employee UID: $employeeId');
    
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final monthKey = DateFormat('yyyy-MM').format(date);
    
    _logger.d('📅 Date: $dateKey, Month: $monthKey');
    _logger.d('⏰ Hours: $hours (after $breakMinutes min break)');
    _logger.d('🕐 Entry: $entryTime → Exit: $exitTime');
    _logger.d('⭐ Work Quality: $workQuality%');

    try {
      // STEP 1: Find employee document
      String? documentId;
      String? collectionName;
      
      _logger.i('🔍 STEP 1: Finding employee document...');
      
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (employeeQuery.docs.isNotEmpty) {
        documentId = employeeQuery.docs.first.id;
        collectionName = 'EmployeeDetails';
        _logger.i('   ✅ Found in EmployeeDetails (Doc ID: $documentId)');
      } else {
        final draftQuery = await _firestore
            .collection('Draft')
            .where('uid', isEqualTo: employeeId)
            .limit(1)
            .get();

        if (draftQuery.docs.isNotEmpty) {
          documentId = draftQuery.docs.first.id;
          collectionName = 'Draft';
          _logger.i('   ✅ Found in Draft (Doc ID: $documentId)');
        }
      }

      if (documentId == null || collectionName == null) {
        throw Exception('Employee not found for UID: $employeeId');
      }

      // STEP 2: Check for existing entry
      _logger.i('🔍 STEP 2: Checking existing entry for $dateKey...');
      final existingEntryRef = _firestore
          .collection(collectionName)
          .doc(documentId)
          .collection('DailyHours')
          .doc(dateKey);

      final existingEntry = await existingEntryRef.get();
      if (existingEntry.exists) {
        final oldHours = (existingEntry.data()?['hours'] ?? 0).toDouble();
        final oldQuality = (existingEntry.data()?['workQuality'] ?? 0).toDouble();
        _logger.i('   ⚠️ SAME-DAY UPDATE!');
        _logger.i('   Old: $oldHours hrs, $oldQuality% quality');
        _logger.i('   New: $hours hrs, $workQuality% quality');
      } else {
        _logger.i('   ✅ New entry for $dateKey');
      }

      // STEP 3: Save daily entry with enhanced data
      _logger.i('💾 STEP 3: Saving enhanced daily hours...');
      
      await existingEntryRef.set({
        'date': Timestamp.fromDate(date),
        'entryTime': entryTime,
        'exitTime': exitTime,
        'hours': hours,
        'breakMinutes': breakMinutes,
        'workQuality': workQuality, // NEW: Work output quality rating
        'monthKey': monthKey,
        'loggedBy': widget.department,
        'loggedAt': FieldValue.serverTimestamp(),
        'uid': employeeId,
      }, SetOptions(merge: false));

      _logger.i('   ✅ Daily hours saved with quality rating');

      // Verify
      final verify = await existingEntryRef.get();
      if (verify.exists) {
        final savedHours = (verify.data()?['hours'] ?? 0).toDouble();
        final savedQuality = (verify.data()?['workQuality'] ?? 0).toDouble();
        _logger.i('   ✅ Verified: $savedHours hrs, $savedQuality% quality');
      }

      // STEP 4: Update monthly totals
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
      _logger.i('🔄 STEP 4: Calculating monthly totals...');
      _logger.d('   Collection: $collectionName, Doc: $documentId');
      _logger.d('   Month: $monthKey');

      // Get all daily entries for the month
      final dailyEntries = await _firestore
          .collection(collectionName)
          .doc(documentId)
          .collection('DailyHours')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      _logger.i('   📊 Found ${dailyEntries.docs.length} daily entries');

      if (dailyEntries.docs.isEmpty) {
        _logger.w('   ⚠️ No daily entries!');
        return;
      }

      // Calculate totals
      double totalHours = 0;
      double totalQualityWeighted = 0;
      int daysWorked = 0;

      for (var doc in dailyEntries.docs) {
        final data = doc.data();
        final dayHours = (data['hours'] ?? 0).toDouble();
        final quality = (data['workQuality'] ?? 80.0).toDouble();
        
        totalHours += dayHours;
        totalQualityWeighted += (dayHours * quality); // Weight quality by hours
        daysWorked++;
        
        _logger.d('      ${doc.id}: $dayHours hrs @ $quality% quality');
      }

      // Calculate average work quality (weighted by hours)
      final avgWorkQuality = totalHours > 0 
          ? (totalQualityWeighted / totalHours) 
          : 80.0;

      _logger.i('   📈 MONTHLY TOTALS:');
      _logger.i('      Total Hours: $totalHours hrs');
      _logger.i('      Days Worked: $daysWorked days');
      _logger.i('      Avg Work Quality: ${avgWorkQuality.toStringAsFixed(1)}%');

      // Update main document
      final docRef = _firestore
          .collection(collectionName)
          .doc(documentId);

      await docRef.set({
        'hoursWorked': {
          monthKey: totalHours,
        },
        'workQuality': {
          monthKey: avgWorkQuality,
        },
        'daysWorked': {
          monthKey: daysWorked,
        },
        'lastHoursUpdate': FieldValue.serverTimestamp(),
        'uid': employeeUid,
      }, SetOptions(merge: true));

      _logger.i('   ✅ Monthly totals updated');

      // Verify
      final verify = await docRef.get();
      if (verify.exists) {
        final hoursWorked = verify.data()?['hoursWorked'];
        final quality = verify.data()?['workQuality'];
        _logger.i('   ✅ VERIFICATION:');
        _logger.i('      hoursWorked: $hoursWorked');
        _logger.i('      workQuality: $quality');
        
        if (hoursWorked is Map && hoursWorked[monthKey] == totalHours) {
          _logger.i('   ✅✅✅ SUCCESS: Data matches!');
        } else {
          _logger.e('   ❌ ERROR: Data mismatch!');
        }
      }

    } catch (e, stackTrace) {
      _logger.e('❌ Monthly total error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _saveHours() async {
    if (_calculatedHours <= 0) {
      _showError('Invalid hours. Exit time must be after entry time + break.');
      return;
    }

    _logger.i('=== 🚀 SAVE ENHANCED HOURS ===');
    _logger.i('Employee: ${widget.employeeName}');
    _logger.i('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
    _logger.i('Hours: $_calculatedHours (Break: $_breakMinutes min)');
    _logger.i('Work Quality: $_workQuality%');

    setState(() => _isSaving = true);

    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final entryTimeStr = '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}';
      final exitTimeStr = '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}';

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
            breakMinutes: _breakMinutes,
            workQuality: _workQuality,
          );

          _logger.i('✅✅✅ SUCCESS!');

          if (!mounted) return;

          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Hours logged successfully!\n'
                '${widget.employeeName}: $_calculatedHours hrs @ $_workQuality% quality\n'
                '${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (firestoreError) {
          _logger.e('❌ Firestore error - caching offline', error: firestoreError);
          await _cacheOffline(dateKey, entryTimeStr, exitTimeStr);

          if (!mounted) return;
          Navigator.pop(context, true);
          
          _showWarning('Save error. Hours cached offline and will sync later.');
        }
      } else {
        _logger.w('📴 OFFLINE - Caching');
        await _cacheOffline(dateKey, entryTimeStr, exitTimeStr);

        if (!mounted) return;
        Navigator.pop(context, true);
        _showWarning('Offline: Hours cached, will sync when online');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ CRITICAL ERROR', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showError('Critical error: ${e.toString()}');
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
      }

      cachedEntries.add({
        'employeeId': widget.employeeId,
        'date': dateKey,
        'hours': _calculatedHours,
        'entryTime': entryTime,
        'exitTime': exitTime,
        'breakMinutes': _breakMinutes,
        'workQuality': _workQuality,
        'cachedAt': DateTime.now().toIso8601String(),
      });

      await prefs.setString('pending_hours_entries', jsonEncode(cachedEntries));
      _logger.i('✅ Cached (total: ${cachedEntries.length})');
    } catch (e, stackTrace) {
      _logger.e('❌ Cache error', error: e, stackTrace: stackTrace);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ $message'), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
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
              const SizedBox(height: 20),
              _buildBreakSelector(),
              const SizedBox(height: 20),
              _buildWorkQualitySlider(),
              const SizedBox(height: 24),
              _buildHoursSummary(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.employeeName,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              Text(
                _employmentType,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 90)),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
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
            const Icon(Icons.calendar_today, color: Color.fromARGB(255, 46, 125, 50)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work Date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
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
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.access_time, color: Color.fromARGB(255, 46, 125, 50), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Meal Break',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBreakOption(30, '30 min'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakOption(60, '1 hour'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakOption(90, '1.5 hours'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakOption(int minutes, String label) {
    final isSelected = _breakMinutes == minutes;
    return InkWell(
      onTap: () {
        setState(() {
          _breakMinutes = minutes;
          _calculateHours();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkQualitySlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Work Output Quality',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getQualityColor(_workQuality),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_workQuality.toInt()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _workQuality,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: _getQualityColor(_workQuality),
            label: _getQualityLabel(_workQuality),
            onChanged: (value) {
              setState(() => _workQuality = value);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Poor', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text('Excellent', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(double quality) {
    if (quality >= 90) return Colors.green;
    if (quality >= 70) return Colors.blue;
    if (quality >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getQualityLabel(double quality) {
    if (quality >= 90) return 'Excellent';
    if (quality >= 70) return 'Good';
    if (quality >= 50) return 'Fair';
    return 'Poor';
  }

  Widget _buildHoursSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 46, 125, 50).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Hours:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
          if (_calculatedHours >= 12.0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maximum 12 hours/day cap applied (overtime limit)',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                : const Text('Save Hours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}