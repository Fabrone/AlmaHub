import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

class RecruitmentStatusScreen extends StatefulWidget {
  final String recruiteeEmail;
  final String sanitizedEmail;

  const RecruitmentStatusScreen({
    super.key,
    required this.recruiteeEmail,
    required this.sanitizedEmail,
  });

  @override
  State<RecruitmentStatusScreen> createState() =>
      _RecruitmentStatusScreenState();
}

class _RecruitmentStatusScreenState extends State<RecruitmentStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDeleting = false;

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
    _logger.i('RecruitmentStatusScreen initialized for: ${widget.recruiteeEmail}');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteApplication() async {
    _logger.i('User requested to delete application');

    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) {
      _logger.d('User cancelled deletion');
      return;
    }

    setState(() => _isDeleting = true);

    try {
      _logger.i('Starting application deletion process');

      // Get the recruitee document to retrieve CV URL
      final doc = await FirebaseFirestore.instance
          .collection('Recruitees')
          .doc(widget.sanitizedEmail)
          .get();

      if (!doc.exists) {
        _logger.w('Recruitee document not found');
        throw Exception('Application not found');
      }

      final cvUrl = doc.data()?['cvUrl'] as String?;
      _logger.d('CV URL to delete: $cvUrl');

      // Delete from Firebase Storage if CV exists
      if (cvUrl != null && cvUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(cvUrl);
          await ref.delete();
          _logger.i('✅ CV deleted from Firebase Storage');
        } catch (e) {
          _logger.w('Failed to delete CV from storage (may not exist)', error: e);
        }
      }

      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('Recruitees')
          .doc(widget.sanitizedEmail)
          .delete();

      _logger.i('✅ Application deleted successfully');

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application removed from system'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting application', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                SizedBox(width: 12),
                Text('Confirm Deletion'),
              ],
            ),
            content: const Text(
              'Are you sure you want to permanently delete your application? This action cannot be undone.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleKeepForFuture() async {
    _logger.i('User chose to keep application for future consideration');

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application saved for future opportunities'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          // Prevent back button, force user to make a decision
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for status update or choose an action'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Recruitees')
                .doc(widget.sanitizedEmail)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorView(snapshot.error.toString());
              }

              if (!snapshot.hasData) {
                return _buildLoadingView();
              }

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              if (data == null) {
                return _buildErrorView('Application not found');
              }

              final status = data['status'] as String? ?? 'pending';
              final fullName = data['fullName'] as String? ?? 'Applicant';

              return _buildStatusView(status, fullName, data);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7B2CBF),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your application status...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Status',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('Return Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView(String status, String fullName, Map<String, dynamic> data) {
    switch (status) {
      case 'pending':
        return _buildPendingView(fullName);
      case 'under_review':
        return _buildUnderReviewView(fullName);
      case 'shortlisted':
        return _buildShortlistedView(fullName);
      case 'not_shortlisted':
        return _buildNotShortlistedView(fullName);
      case 'accepted':
        return _buildAcceptedView(fullName);
      case 'rejected':
        return _buildRejectedView(fullName);
      default:
        return _buildPendingView(fullName);
    }
  }

  // Status: pending - Just submitted
  Widget _buildPendingView(String fullName) {
    return _buildStatusCard(
      icon: Icons.send_rounded,
      iconColor: const Color(0xFF3B82F6),
      title: 'Application Submitted!',
      subtitle: 'Hi $fullName, we have received your application',
      description:
          'Your CV and details are now in our system. Our recruitment team will review your application shortly.',
      statusBadge: 'Pending Review',
      statusColor: const Color(0xFF3B82F6),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Under Review', false, null),
        TimelineStep('Decision', false, null),
      ],
      showPulse: true,
    );
  }

  // Status: under_review - Being reviewed by HR
  Widget _buildUnderReviewView(String fullName) {
    return _buildStatusCard(
      icon: Icons.pending_actions_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: 'Application Under Review',
      subtitle: 'Your application is being evaluated',
      description:
          'Our recruitment team is currently reviewing your qualifications and experience. We\'ll update you on the next steps soon.',
      statusBadge: 'Under Review',
      statusColor: const Color(0xFFF59E0B),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Under Review', true, DateTime.now()),
        TimelineStep('Decision', false, null),
      ],
      showPulse: true,
    );
  }

  // Status: shortlisted - Moved to next round
  Widget _buildShortlistedView(String fullName) {
    return _buildStatusCard(
      icon: Icons.stars_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Congratulations!',
      subtitle: 'You\'ve been shortlisted',
      description:
          'Great news! Your profile matches our requirements. We\'ll be in touch soon to discuss the next steps in the recruitment process.',
      statusBadge: 'Shortlisted',
      statusColor: const Color(0xFF10B981),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Under Review', true, DateTime.now()),
        TimelineStep('Shortlisted ✓', true, DateTime.now()),
      ],
      showPulse: false,
      additionalInfo:
          'Check your email for further instructions. Our team will contact you within 2-3 business days.',
    );
  }

  // Status: not_shortlisted - Not selected for this round
  Widget _buildNotShortlistedView(String fullName) {
    return _buildStatusCard(
      icon: Icons.info_outline,
      iconColor: const Color(0xFFF59E0B),
      title: 'Application Update',
      subtitle: 'Not shortlisted for current opening',
      description:
          'Thank you for your interest. While you weren\'t selected for this position, we\'d like to keep your profile for future opportunities.',
      statusBadge: 'Not Shortlisted',
      statusColor: const Color(0xFFF59E0B),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Under Review', true, DateTime.now()),
        TimelineStep('Not Selected', true, DateTime.now()),
      ],
      showPulse: false,
      actions: [
        _buildActionButton(
          label: 'Keep for Future Opportunities',
          icon: Icons.bookmark_add_outlined,
          color: const Color(0xFF7B2CBF),
          onPressed: _handleKeepForFuture,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Remove Application',
          icon: Icons.delete_outline,
          color: const Color(0xFFDC2626),
          onPressed: _handleDeleteApplication,
          isDestructive: true,
        ),
      ],
    );
  }

  // Status: accepted - Final acceptance
  Widget _buildAcceptedView(String fullName) {
    return _buildStatusCard(
      icon: Icons.celebration_rounded,
      iconColor: const Color(0xFF10B981),
      title: 'Welcome to JV Almacis!',
      subtitle: 'Your application has been accepted',
      description:
          'Congratulations! You\'re now part of our team. Please check your email for onboarding instructions.',
      statusBadge: 'Accepted',
      statusColor: const Color(0xFF10B981),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Shortlisted', true, DateTime.now()),
        TimelineStep('Accepted ✓', true, DateTime.now()),
      ],
      showPulse: false,
      additionalInfo:
          'Next Steps:\n• Check your email for onboarding details\n• Complete required documentation\n• Prepare for your start date',
      actions: [
        _buildActionButton(
          label: 'View Onboarding Guide',
          icon: Icons.arrow_forward,
          color: const Color(0xFF7B2CBF),
          onPressed: () {
            // Future: Navigate to onboarding screen
            // This will be implemented when onboarding module is ready
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Onboarding process will be available soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }

  // Status: rejected - Final rejection → Changed to "Application Unsuccessful"
  Widget _buildRejectedView(String fullName) {
    return _buildStatusCard(
      icon: Icons.info_outline,
      iconColor: const Color(0xFF64748B),
      title: 'Application Update',
      subtitle: 'Application was not successful',
      description:
          'Thank you for your interest in JV Almacis. While this particular role wasn\'t the right match, we encourage you to explore future openings that align with your expertise.',
      statusBadge: 'Not Selected',
      statusColor: const Color(0xFF64748B),
      timeline: [
        TimelineStep('Application Submitted', true, DateTime.now()),
        TimelineStep('Reviewed', true, DateTime.now()),
        TimelineStep('Decision Made', true, DateTime.now()),
      ],
      showPulse: false,
      actions: [
        _buildActionButton(
          label: 'Keep for Future Opportunities',
          icon: Icons.bookmark_add_outlined,
          color: const Color(0xFF7B2CBF),
          onPressed: _handleKeepForFuture,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Remove Application',
          icon: Icons.delete_outline,
          color: const Color(0xFF64748B),
          onPressed: _handleDeleteApplication,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
    required String statusBadge,
    required Color statusColor,
    required List<TimelineStep> timeline,
    required bool showPulse,
    String? additionalInfo,
    List<Widget>? actions,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main status card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        // Icon with pulse animation
                        showPulse
                            ? ScaleTransition(
                                scale: _pulseAnimation,
                                child: _buildIconCircle(icon, iconColor),
                              )
                            : _buildIconCircle(icon, iconColor),

                        const SizedBox(height: 24),

                        // Status badge
                        _buildStatusBadge(statusBadge, statusColor),

                        const SizedBox(height: 16),

                        // Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Description
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF475569),
                              height: 1.6,
                            ),
                          ),
                        ),

                        // Additional info if provided
                        if (additionalInfo != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: statusColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    additionalInfo,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: const Color(0xFF475569),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Timeline
                _buildTimeline(timeline),

                // Actions if provided
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ...actions,
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconCircle(IconData icon, Color color) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 50,
        color: color,
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimeline(List<TimelineStep> steps) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            'Application Timeline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            return _buildTimelineItem(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineStep step, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: step.completed
                    ? const Color(0xFF7B2CBF)
                    : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.completed
                      ? const Color(0xFF7B2CBF)
                      : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: step.completed
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.completed
                    ? const Color(0xFF7B2CBF)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: step.completed
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFF94A3B8),
                  ),
                ),
                if (step.timestamp != null)
                  Text(
                    _formatTimestamp(step.timestamp!),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDeleting ? null : onPressed,
        icon: _isDeleting && isDestructive
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class TimelineStep {
  final String label;
  final bool completed;
  final DateTime? timestamp;

  TimelineStep(this.label, this.completed, this.timestamp);
}