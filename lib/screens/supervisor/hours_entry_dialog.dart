import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Hours Entry Dialog for Supervisors to log employee daily hours
/// Features:
/// - Select date
/// - Entry and exit time pickers
/// - Automatic hours calculation
/// - Offline caching with sync when online
/// - Monthly aggregation
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
  double _calculatedHours = 8.0;

  @override
  void initState() {
    super.initState();
    _calculateHours();
    _syncOfflineData(); // Sync any pending offline data
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
    setState(() {
      _calculatedHours = difference.inMinutes / 60.0;
    });

    _logger.d('Calculated hours: $_calculatedHours for date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');
  }

  Future<void> _syncOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString('pending_hours_entries');

      if (offlineDataJson == null) return;

      final List<dynamic> offlineEntries = jsonDecode(offlineDataJson);
      _logger.i('Found ${offlineEntries.length} offline entries to sync');

      for (var entry in offlineEntries) {
        try {
          await _saveToFirestore(
            employeeId: entry['employeeId'],
            date: DateTime.parse(entry['date']),
            hours: entry['hours'],
            entryTime: entry['entryTime'],
            exitTime: entry['exitTime'],
          );
          _logger.d('Synced offline entry for ${entry['employeeId']} on ${entry['date']}');
        } catch (e) {
          _logger.e('Failed to sync entry', error: e);
        }
      }

      // Clear synced data
      await prefs.remove('pending_hours_entries');
      _logger.i('✅ All offline data synced successfully');
    } catch (e) {
      _logger.e('Error during offline sync', error: e);
    }
  }

  Future<void> _saveToFirestore({
    required String employeeId,
    required DateTime date,
    required double hours,
    required String entryTime,
    required String exitTime,
  }) async {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final monthKey = DateFormat('yyyy-MM').format(date);

    // Save to DailyHours subcollection
    await _firestore
        .collection('EmployeeDetails')
        .doc(employeeId)
        .collection('DailyHours')
        .doc(dateKey)
        .set({
      'date': Timestamp.fromDate(date),
      'entryTime': entryTime,
      'exitTime': exitTime,
      'hours': hours,
      'monthKey': monthKey,
      'loggedBy': widget.department, // Supervisor's department
      'loggedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update monthly total
    await _updateMonthlyTotal(employeeId, monthKey);
  }

  Future<void> _updateMonthlyTotal(String employeeId, String monthKey) async {
    // Get all daily entries for the month
    final dailyEntries = await _firestore
        .collection('EmployeeDetails')
        .doc(employeeId)
        .collection('DailyHours')
        .where('monthKey', isEqualTo: monthKey)
        .get();

    double totalHours = 0;
    for (var doc in dailyEntries.docs) {
      totalHours += (doc.data()['hours'] ?? 0).toDouble();
    }

    _logger.d('Updating monthly total for $monthKey: $totalHours hours');

    // Update the monthly total in the main document
    await _firestore.collection('EmployeeDetails').doc(employeeId).update({
      'hoursWorked.$monthKey': totalHours,
      'lastHoursUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveHours() async {
    if (_calculatedHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid hours. Exit time must be after entry time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final entryTimeStr = '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}';
      final exitTimeStr = '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}';

      // Try to save online first
      try {
        await _saveToFirestore(
          employeeId: widget.employeeId,
          date: _selectedDate,
          hours: _calculatedHours,
          entryTime: entryTimeStr,
          exitTime: exitTimeStr,
        );

        _logger.i('✅ Hours saved online for ${widget.employeeName} on $dateKey');

        if (!mounted) return;

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hours logged: $_calculatedHours hrs for ${widget.employeeName}'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // If online save fails, cache offline
        _logger.w('Online save failed, caching offline', error: e);
        await _cacheOffline(dateKey, entryTimeStr, exitTimeStr);

        if (!mounted) return;

        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline: Hours cached and will sync when online'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error saving hours', error: e);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cacheOffline(String dateKey, String entryTime, String exitTime) async {
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
      'cachedAt': DateTime.now().toIso8601String(),
    });

    await prefs.setString('pending_hours_entries', jsonEncode(cachedEntries));
    _logger.i('📦 Cached hours entry offline');
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
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Date Selector
            _buildDateSelector(),
            const SizedBox(height: 20),

            // Time Selectors
            Row(
              children: [
                Expanded(child: _buildTimeSelector('Entry Time', _entryTime, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTimeSelector('Exit Time', _exitTime, false)),
              ],
            ),
            const SizedBox(height: 24),

            // Calculated Hours Display
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
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