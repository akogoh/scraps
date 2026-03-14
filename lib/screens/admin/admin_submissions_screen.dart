import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/admin_submission_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import 'admin_submission_detail_screen.dart';

class AdminSubmissionsScreen extends StatefulWidget {
  final Admin? admin;
  final FieldOfficer? fieldOfficer;

  const AdminSubmissionsScreen({
    super.key,
    this.admin,
    this.fieldOfficer,
  }) : assert(admin != null || fieldOfficer != null,
            'Either admin or fieldOfficer must be provided');

  @override
  State<AdminSubmissionsScreen> createState() => _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState extends State<AdminSubmissionsScreen> {
  List<AdminSubmission> _submissions = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  bool get isFieldOfficer => widget.fieldOfficer != null;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
    // Auto-refresh every 5 seconds for field officers, every 10 seconds for admins
    _refreshTimer = Timer.periodic(
      Duration(seconds: isFieldOfficer ? 5 : 10),
      (_) {
        // Only auto-refresh if not searching
        if (_searchController.text.trim().isEmpty) {
          _loadSubmissions(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      List<AdminSubmission> submissions;

      if (isFieldOfficer) {
        // Load only assigned jobs for field officer
        if (_selectedStatus == 'all') {
          if (!silent) {
            print('🔧 FieldOfficer: Loading all assigned jobs...');
          }
          submissions =
              await AdminService.getAssignedJobs(widget.fieldOfficer!.id);
        } else {
          if (!silent) {
            print(
                '🔧 FieldOfficer: Loading assigned jobs with status: $_selectedStatus');
          }
          submissions = await AdminService.getAssignedJobsByStatus(
              widget.fieldOfficer!.id, _selectedStatus);
        }
      } else {
        // Load all submissions for admin
        if (_selectedStatus == 'all') {
          if (!silent) {
            print('🔧 Loading all submissions...');
          }
          submissions = await AdminService.getAllSubmissions();
        } else {
          if (!silent) {
            print('🔧 Loading submissions with status: $_selectedStatus');
          }
          submissions =
              await AdminService.getSubmissionsByStatus(_selectedStatus);
        }
      }

      if (!silent) {
        print(
            '✅ Loaded ${submissions.length} ${isFieldOfficer ? "assigned jobs" : "submissions"}');
        print('🔧 Status breakdown:');
        final statusCounts = <String, int>{};
        for (var sub in submissions) {
          statusCounts[sub.status] = (statusCounts[sub.status] ?? 0) + 1;
        }
        statusCounts.forEach((status, count) {
          print('   - $status: $count');
        });
      }

      if (mounted) {
        setState(() {
          _submissions = submissions;
          if (!silent) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        if (!silent) {
          print(
              '❌ Error loading ${isFieldOfficer ? "assigned jobs" : "submissions"}: $e');
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Error loading jobs: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _searchSubmissions() async {
    if (_searchController.text.trim().isEmpty) {
      _loadSubmissions();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<AdminSubmission> submissions;
      if (isFieldOfficer) {
        submissions = await AdminService.searchAssignedJobs(
            widget.fieldOfficer!.id, _searchController.text.trim());
      } else {
        submissions =
            await AdminService.searchSubmissions(_searchController.text.trim());
      }
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error searching jobs: ${e.toString()}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFieldOfficer ? 'My Assigned Jobs' : 'All Jobs',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Summary Bar (when showing all)
          if (_selectedStatus == 'all' &&
              !_isLoading &&
              _submissions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.primaryGreen.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: isFieldOfficer
                    ? [
                        // Field Officers only see: Pending, Approved, Completed
                        _buildStatusSummary(
                            'Pending',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'pending')
                                .length,
                            AppColors.accentOrange),
                        _buildStatusSummary(
                            'Approved',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'approved')
                                .length,
                            AppColors.primaryGreen),
                        _buildStatusSummary(
                            'Completed',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'completed')
                                .length,
                            AppColors.primaryGreen),
                      ]
                    : [
                        // Admins see all statuses
                        _buildStatusSummary(
                            'Pending',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'pending')
                                .length,
                            AppColors.accentOrange),
                        _buildStatusSummary(
                            'Reviewed',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'reviewed')
                                .length,
                            AppColors.primaryGreen),
                        _buildStatusSummary(
                            'Approved',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'approved')
                                .length,
                            AppColors.primaryGreen),
                        _buildStatusSummary(
                            'Rejected',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'rejected')
                                .length,
                            AppColors.accentOrange),
                        _buildStatusSummary(
                            'Completed',
                            _submissions
                                .where((s) => s.status.toLowerCase() == 'completed')
                                .length,
                            AppColors.primaryGreen),
                      ],
              ),
            ),

          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search jobs by name, user, or phone...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadSubmissions();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _searchSubmissions(),
                ),
                const SizedBox(height: 16),

                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedStatus == 'all',
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'all';
                          });
                          _loadSubmissions();
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        isSelected: _selectedStatus == 'pending',
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'pending';
                          });
                          _loadSubmissions();
                        },
                      ),
                      if (!isFieldOfficer) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Reviewed',
                          isSelected: _selectedStatus == 'reviewed',
                          onTap: () {
                            setState(() {
                              _selectedStatus = 'reviewed';
                            });
                            _loadSubmissions();
                          },
                        ),
                      ],
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Approved',
                        isSelected: _selectedStatus == 'approved',
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'approved';
                          });
                          _loadSubmissions();
                        },
                      ),
                      if (!isFieldOfficer) ...[
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Rejected',
                          isSelected: _selectedStatus == 'rejected',
                          onTap: () {
                            setState(() {
                              _selectedStatus = 'rejected';
                            });
                            _loadSubmissions();
                          },
                        ),
                      ],
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Completed',
                        isSelected: _selectedStatus == 'completed',
                        onTap: () {
                          setState(() {
                            _selectedStatus = 'completed';
                          });
                          _loadSubmissions();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Submissions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _submissions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: AppColors.textGrey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedStatus == 'all'
                                  ? 'No jobs found'
                                  : 'No $_selectedStatus jobs found',
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.textGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting a different status filter',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textGrey.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _submissions.length,
                        itemBuilder: (context, index) {
                          final submission = _submissions[index];
                          return _SubmissionCard(
                            submission: submission,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AdminSubmissionDetailScreen(
                                    submission: submission,
                                    admin: widget.admin,
                                    fieldOfficer: widget.fieldOfficer,
                                  ),
                                ),
                              ).then((_) {
                                // Refresh the list when returning from detail screen
                                _loadSubmissions();
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final AdminSubmission submission;
  final VoidCallback onTap;

  const _SubmissionCard({
    required this.submission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(submission.status),
          child: Text(
            submission.itemName[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          submission.itemName,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${submission.userName} - ${submission.phoneNumber}',
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Submitted: ${_formatDate(submission.submittedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (submission.messageCount > 0)
              Text(
                '${submission.messageCount} messages',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(submission.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                submission.status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (submission.messageCount > 0) ...[
              const SizedBox(height: 2),
              const Icon(
                Icons.message,
                size: 12,
                color: AppColors.primaryGreen,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.accentOrange;
      case 'reviewed':
        return AppColors.primaryGreen;
      case 'approved':
        return AppColors.primaryGreen;
      case 'rejected':
        return AppColors.accentOrange;
      case 'completed':
        return AppColors.primaryGreen;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Widget _buildStatusSummary(String label, int count, Color color) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        count.toString(),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
