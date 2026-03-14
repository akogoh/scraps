import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/scrap_submission_model.dart';
import '../../models/message_model.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';

class MessageScreen extends StatefulWidget {
  final ScrapSubmission submission;

  const MessageScreen({super.key, required this.submission});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  DateTime? _selectedCollectionDate;
  Timer? _refreshTimer;
  ScrapSubmission? _currentSubmission;

  @override
  void initState() {
    super.initState();
    _currentSubmission = widget.submission;
    _selectedCollectionDate = widget.submission.collectionDate;
    _loadMessages();
    _refreshSubmissionData();
    // Start auto-refresh timer (poll every 5 seconds for messages and submission data)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
      _refreshSubmissionData(silent: true);
    });
  }

  Future<void> _refreshSubmissionData({bool silent = false}) async {
    try {
      final phoneNumber = await SessionManager.getCurrentUserPhone();
      if (phoneNumber == null) return;

      final submissions = await SupabaseService.getUserSubmissions(phoneNumber);
      final updatedSubmission = submissions.firstWhere(
        (s) => s.id == widget.submission.id,
        orElse: () => widget.submission,
      );

      if (mounted &&
          updatedSubmission.assignedOfficerName !=
              _currentSubmission?.assignedOfficerName) {
        // Field officer was just assigned - show verification popup
        if (updatedSubmission.assignedOfficerId != null &&
            _currentSubmission?.assignedOfficerId == null) {
          _showFieldOfficerVerification(updatedSubmission.assignedOfficerId!);
        }
        setState(() {
          _currentSubmission = updatedSubmission;
          _selectedCollectionDate = updatedSubmission.collectionDate;
        });
      }
    } catch (e) {
      if (!silent) {
        print('Error refreshing submission data: $e');
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final messages =
          await SupabaseService.getMessagesForSubmission(widget.submission.id);

      // Check if there are new messages
      final hasNewMessages = messages.length > _messages.length;
      final wasAtBottom = _scrollController.hasClients &&
          (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 50);

      setState(() {
        _messages = messages;
        if (!silent) {
          _isLoading = false;
        }
      });

      // Auto-scroll to bottom only if:
      // 1. There are new messages AND
      // 2. User was already at the bottom (or it's the initial load)
      if (hasNewMessages && (wasAtBottom || _isLoading)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (!silent) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error loading messages: ${e.toString()}');
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Get the current user ID from session
      final userId = await SessionManager.getCurrentUserId();
      if (userId == null) {
        _showSnackBar('Error: User session not found. Please login again.');
        return;
      }

      final newMessage = await SupabaseService.sendMessage(
        submissionId: widget.submission.id,
        senderId: userId,
        content: messageText,
        isAdminMessage: false,
      );

      setState(() {
        _messages.add(newMessage);
        _messageController.clear();
      });

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      _showSnackBar('Error sending message: ${e.toString()}');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _updateCollectionDate() async {
    if (_selectedCollectionDate == null) return;

    try {
      final success = await SupabaseService.updateCollectionDate(
        widget.submission.id,
        _selectedCollectionDate!,
      );

      if (success) {
        _showSnackBar('Collection date updated successfully!', isError: false);
        // Refresh the submission data
        setState(() {
          // The collection date will be updated in the parent widget
        });
      } else {
        _showSnackBar('Failed to update collection date');
      }
    } catch (e) {
      _showSnackBar('Error updating collection date: ${e.toString()}');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.accentOrange : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.submission.itemName,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'ID: ${widget.submission.id}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          // Submission Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${(_currentSubmission ?? widget.submission).status.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(
                        (_currentSubmission ?? widget.submission).status),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submitted: ${_formatDate((_currentSubmission ?? widget.submission).submittedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                // Field Officer Assignment (if assigned)
                if ((_currentSubmission ?? widget.submission)
                        .assignedOfficerName !=
                    null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryGreen.withOpacity(0.15),
                          AppColors.primaryGreen.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Field Officer Assigned',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (_currentSubmission ?? widget.submission)
                                    .assignedOfficerName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
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
          ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),

          // Collection Date Picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Collection Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),

                // Current Collection Date Display (if set)
                if (_selectedCollectionDate != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: AppColors.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scheduled Collection',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedCollectionDate!.day}/${_selectedCollectionDate!.month}/${_selectedCollectionDate!.year} ${_selectedCollectionDate!.hour}:${_selectedCollectionDate!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            // First select date
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  _selectedCollectionDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              // Then select time
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(
                                    _selectedCollectionDate ?? DateTime.now()),
                              );
                              if (time != null) {
                                setState(() {
                                  _selectedCollectionDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                                // Update the collection date
                                _updateCollectionDate();
                              }
                            }
                          },
                          child: Text(
                            'Change',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Date Picker (only show if no collection date is set)
                if (_selectedCollectionDate == null)
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            // First select date
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              // Then select time
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (time != null) {
                                setState(() {
                                  _selectedCollectionDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                                // Update the collection date
                                _updateCollectionDate();
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.white,
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.calendar_today, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Select collection date & time',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.white,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Messages Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation about your submission',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isFromAdmin = message.isAdminMessage;
    final senderLabel = isFromAdmin ? 'GreenHaul Team' : 'You';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isFromAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isFromAdmin) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_pin_circle,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isFromAdmin ? Colors.grey[200] : AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isFromAdmin
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                  bottomRight: isFromAdmin
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender label
                  Text(
                    senderLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isFromAdmin ? Colors.grey[700] : Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isFromAdmin ? Colors.black87 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isFromAdmin ? Colors.grey[600] : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isFromAdmin) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.primaryGreen;
      case 'rejected':
        return AppColors.accentOrange;
      case 'reviewed':
        return AppColors.accentOrange;
      default:
        return AppColors.primaryGreen;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showFieldOfficerVerification(String officerId) async {
    try {
      final officer = await AdminService.getFieldOfficerById(officerId);
      if (officer == null || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified_user, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Field Officer Verification',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A field officer has been assigned to collect your scrap. Please verify their identity:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Officer Photo
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGreen,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child:
                        officer.displayPhotoUrl != null && officer.displayPhotoUrl!.isNotEmpty
                            ? Image.network(
                                officer.displayPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: AppColors.backgroundGrey,
                                    child: Icon(
                                      Icons.person,
                                      size: 80,
                                      color: AppColors.primaryGreen,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: AppColors.backgroundGrey,
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  officer.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (officer.phoneNumber != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Phone: ${officer.phoneNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please verify this is the person who arrives to collect your scrap.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'I Understand',
                style: TextStyle(color: AppColors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing field officer verification: $e');
    }
  }
}
