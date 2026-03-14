import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/admin_submission_model.dart';
import '../../services/admin_service.dart';
import '../../services/field_officer_location_service.dart';
import '../../services/push_notification_service.dart';
import '../../utils/app_colors.dart';
import 'admin_submissions_screen.dart';
import 'admin_messages_screen.dart';
import 'admin_analytics_screen.dart';
import 'office_chat_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Admin? admin;
  final FieldOfficer? fieldOfficer;

  const AdminDashboardScreen({
    super.key,
    this.admin,
    this.fieldOfficer,
  }) : assert(admin != null || fieldOfficer != null,
            'Either admin or fieldOfficer must be provided');

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, int> _stats = {};
  List<AdminSubmission> _recentSubmissions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _locationUpdateTimer; // Auto-send GPS every 30s (field officer)
  Timer? _locationCountdownTimer; // 1s tick to show "Next update in: Xs"
  int _locationCountdownSecs = 30; // Countdown 30→0, reset when location sent
  RealtimeChannel?
      _jobAssignmentChannel; // Realtime: notify when assigned a job
  FieldOfficer?
      _currentFieldOfficer; // Store current field officer data with location
  bool get isFieldOfficer => widget.fieldOfficer != null;

  @override
  void initState() {
    super.initState();
    // Initialize with widget's field officer if available
    if (isFieldOfficer && widget.fieldOfficer != null) {
      _currentFieldOfficer = widget.fieldOfficer;
    }
    _loadDashboardData();
    // Auto-refresh every 5 seconds for field officers, every 10 seconds for admins
    _refreshTimer = Timer.periodic(
      Duration(seconds: isFieldOfficer ? 5 : 10),
      (_) => _loadDashboardData(silent: true),
    );
    // Global location updates: keep running even after logout (FieldOfficerLocationService)
    if (isFieldOfficer) {
      FieldOfficerLocationService.start(widget.fieldOfficer!.id);
      PushNotificationService.registerToken(
          fieldOfficerId: widget.fieldOfficer!.id);
      _locationCountdownSecs = 30;
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _locationCountdownSecs = 30);
      });
      _locationCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_locationCountdownSecs > 0) {
          setState(() => _locationCountdownSecs--);
        }
      });
      Future.delayed(
          const Duration(seconds: 2), () => _refreshOfficerLocationForUi());
      _subscribeToJobAssignments();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _locationCountdownTimer?.cancel();
    _jobAssignmentChannel?.unsubscribe();
    super.dispose();
  }

  /// Realtime: when this officer is assigned a job, show in-app notification.
  void _subscribeToJobAssignments() {
    if (!isFieldOfficer || widget.fieldOfficer == null) return;
    final officerId = widget.fieldOfficer!.id;
    _jobAssignmentChannel = Supabase.instance.client
        .channel('job-assignments-$officerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'scrap_submissions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_officer_id',
            value: officerId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final oldRecord = payload.oldRecord;
            final newlyAssigned =
                oldRecord['assigned_officer_id']?.toString() != officerId;
            if (newlyAssigned) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('You have been assigned a new job'),
                  backgroundColor: AppColors.primaryGreen,
                  action: SnackBarAction(
                    label: 'View',
                    textColor: Colors.white,
                    onPressed: () => _loadDashboardData(silent: true),
                  ),
                ),
              );
            }
          },
        )
        .subscribe();
  }

  /// Refreshes officer data from API so "Last updated" / lat-lon stay current (global service does the actual send).
  Future<void> _refreshOfficerLocationForUi() async {
    if (!isFieldOfficer || widget.fieldOfficer == null || !mounted) return;
    try {
      final updated =
          await AdminService.getFieldOfficerById(widget.fieldOfficer!.id);
      if (updated != null && mounted) {
        setState(() => _currentFieldOfficer = updated);
      }
    } catch (_) {}
  }

  /// Manual "Update my location" button: send once and refresh UI. Background updates continue via FieldOfficerLocationService.
  Future<void> _sendLocationUpdate() async {
    if (!isFieldOfficer || widget.fieldOfficer == null || !mounted) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await AdminService.updateFieldOfficerLocation(
        officerId: widget.fieldOfficer!.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) {
        final updated =
            await AdminService.getFieldOfficerById(widget.fieldOfficer!.id);
        if (updated != null) {
          setState(() {
            _currentFieldOfficer = updated;
            _locationCountdownSecs = 30;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      if (isFieldOfficer) {
        // Load field officer assigned jobs and current officer data
        final stats =
            await AdminService.getFieldOfficerStats(widget.fieldOfficer!.id);
        final assignedJobs =
            await AdminService.getAssignedJobs(widget.fieldOfficer!.id);
        final currentOfficer =
            await AdminService.getFieldOfficerById(widget.fieldOfficer!.id);
        if (mounted) {
          setState(() {
            _stats = stats;
            _recentSubmissions = assignedJobs.take(5).toList();
            _currentFieldOfficer = currentOfficer;
            if (!silent) {
              _isLoading = false;
            }
          });
        }
      } else {
        // Load admin dashboard (all submissions)
        final stats = await AdminService.getSubmissionStats();
        final recentSubmissions =
            await AdminService.getRecentSubmissions(limit: 5);
        if (mounted) {
          setState(() {
            _stats = stats;
            _recentSubmissions = recentSubmissions;
            if (!silent) {
              _isLoading = false;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (!silent) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Error loading dashboard: ${e.toString()}');
        }
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.accentOrange,
      ),
    );
  }

  Widget _buildFieldOfficerWelcome() {
    final officer = _currentFieldOfficer ?? widget.fieldOfficer!;
    final photoUrl = officer.displayPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Row(
      children: [
        // Profile picture
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            border: Border.all(
              color: Colors.white,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: hasPhoto
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    width: 72,
                    height: 72,
                    errorBuilder: (_, __, ___) =>
                        _buildProfilePlaceholder(officer),
                  )
                : _buildProfilePlaceholder(officer),
          ),
        ),
        const SizedBox(width: 20),
        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${officer.name}!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View your assigned jobs and mark items as collected',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePlaceholder(FieldOfficer officer) {
    final initial = officer.name.isNotEmpty
        ? officer.name.trim().substring(0, 1).toUpperCase()
        : '?';
    return Container(
      color: Colors.white.withOpacity(0.25),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
    );
  }

  Future<void> _updateCurrentLocation() async {
    if (!isFieldOfficer || widget.fieldOfficer == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Getting your location...'),
          ],
        ),
      ),
    );
    try {
      await _sendLocationUpdate();
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar('✅ Location updated successfully!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Error updating location: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Field Officer Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryGreen,
                            AppColors.primaryGreen
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: isFieldOfficer
                          ? _buildFieldOfficerWelcome()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${widget.admin!.username}!',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'View pending jobs and manage scrap collections',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: AppColors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Statistics Cards
                    _buildStatsSection(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActionsSection(),
                    const SizedBox(height: 24),

                    // Recent Submissions
                    _buildRecentSubmissionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistics',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              title: 'Total',
              value: _stats['total']?.toString() ?? '0',
              color: AppColors.primaryGreen,
              icon: Icons.assessment,
            ),
            _StatCard(
              title: 'Pending',
              value: _stats['pending']?.toString() ?? '0',
              color: AppColors.accentOrange,
              icon: Icons.pending,
            ),
            _StatCard(
              title: 'Approved',
              value: _stats['approved']?.toString() ?? '0',
              color: AppColors.primaryGreen,
              icon: Icons.check_circle,
            ),
            _StatCard(
              title: isFieldOfficer ? 'Completed' : 'Rejected',
              value: isFieldOfficer
                  ? (_stats['completed']?.toString() ?? '0')
                  : (_stats['rejected']?.toString() ?? '0'),
              color: isFieldOfficer
                  ? AppColors.primaryGreen
                  : AppColors.accentOrange,
              icon: isFieldOfficer ? Icons.check_circle : Icons.cancel,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationDisplay() {
    if (!isFieldOfficer) {
      return const SizedBox.shrink();
    }

    // Use _currentFieldOfficer if available, otherwise fallback to widget.fieldOfficer
    final officer = _currentFieldOfficer ?? widget.fieldOfficer;
    if (officer == null) {
      return const SizedBox.shrink();
    }

    final hasLocation = officer.latitude != null && officer.longitude != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Current Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasLocation) ...[
            _LocationInfoRow(
              label: 'Latitude',
              value: officer.latitude!.toStringAsFixed(6),
            ),
            const SizedBox(height: 8),
            _LocationInfoRow(
              label: 'Longitude',
              value: officer.longitude!.toStringAsFixed(6),
            ),
            if (officer.lastLocationUpdate != null) ...[
              const SizedBox(height: 8),
              _LocationInfoRow(
                label: 'Last Updated',
                value: _formatDateTime(officer.lastLocationUpdate!),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _locationCountdownSecs / 30,
                          strokeWidth: 4,
                          backgroundColor:
                              AppColors.primaryGreen.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryGreen),
                        ),
                        Text(
                          '$_locationCountdownSecs',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next update in ${_locationCountdownSecs}s',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Every 30s, new location is sent when there is movement.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.accentOrange,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No location data available. Please update your location.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 16),
        if (isFieldOfficer)
          // Field Officer Quick Actions
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'View All Jobs',
                      icon: Icons.list_alt,
                      color: AppColors.primaryGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminSubmissionsScreen(
                              admin: widget.admin,
                              fieldOfficer: widget.fieldOfficer,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'Messages',
                      icon: Icons.message,
                      color: AppColors.primaryGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminSubmissionsScreen(
                              admin: widget.admin,
                              fieldOfficer: widget.fieldOfficer,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'Office chat',
                      icon: Icons.chat_rounded,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OfficeChatListScreen(
                              admin: widget.admin,
                              fieldOfficer: widget.fieldOfficer,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'Update Location',
                      icon: Icons.location_on,
                      color: AppColors.accentOrange,
                      onTap: _updateCurrentLocation,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Location Display
              _buildLocationDisplay(),
            ],
          )
        else
          // Admin Quick Actions
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'View All Jobs',
                  icon: Icons.list_alt,
                  color: AppColors.primaryGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminSubmissionsScreen(
                          admin: widget.admin,
                          fieldOfficer: widget.fieldOfficer,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Messages',
                  icon: Icons.message,
                  color: AppColors.primaryGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminMessagesScreen(admin: widget.admin!),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: 'Office chat',
                icon: Icons.chat_rounded,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfficeChatListScreen(
                        admin: widget.admin,
                        fieldOfficer: widget.fieldOfficer,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            if (!isFieldOfficer)
              Expanded(
                child: _ActionCard(
                  title: 'Analytics',
                  icon: Icons.analytics,
                  color: AppColors.accentOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminAnalyticsScreen(),
                      ),
                    );
                  },
                ),
              )
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSubmissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Jobs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminSubmissionsScreen(
                      admin: widget.admin,
                      fieldOfficer: widget.fieldOfficer,
                    ),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_recentSubmissions.isEmpty)
          const Center(
            child: Text(
              'No submissions yet',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentSubmissions.length,
            itemBuilder: (context, index) {
              final submission = _recentSubmissions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(submission.itemName),
                  subtitle: Text(
                      '${submission.userName} - ${submission.phoneNumber}'),
                  trailing: Chip(
                    label: Text(submission.status),
                    backgroundColor: _getStatusColor(submission.status),
                  ),
                  onTap: () {
                    // Navigate to submission details
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accentOrange.withOpacity(0.2);
      case 'reviewed':
        return AppColors.primaryGreen.withOpacity(0.2);
      case 'approved':
        return AppColors.primaryGreen.withOpacity(0.2);
      case 'rejected':
        return AppColors.accentOrange.withOpacity(0.2);
      default:
        return Colors.grey.withOpacity(0.2);
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _LocationInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textGrey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
