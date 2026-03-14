import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../models/admin_submission_model.dart';
import '../../services/admin_service.dart';
import 'admin_message_screen.dart';

class AdminMessagesScreen extends StatefulWidget {
  final Admin admin;

  const AdminMessagesScreen({super.key, required this.admin});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  List<AdminSubmission> _submissionsWithMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissionsWithMessages();
  }

  Future<void> _loadSubmissionsWithMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allSubmissions = await AdminService.getAllSubmissions();
      final submissionsWithMessages = allSubmissions
          .where((submission) => submission.messageCount > 0)
          .toList();

      // Sort by most recent message activity
      submissionsWithMessages
          .sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      setState(() {
        _submissionsWithMessages = submissionsWithMessages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading messages: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissionsWithMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissionsWithMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Messages will appear here when users start conversations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _submissionsWithMessages.length,
                  itemBuilder: (context, index) {
                    final submission = _submissionsWithMessages[index];
                    return _MessageCard(
                      submission: submission,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminMessageScreen(
                              submission: submission,
                              admin: widget.admin,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final AdminSubmission submission;
  final VoidCallback onTap;

  const _MessageCard({
    required this.submission,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${submission.userName} - ${submission.phoneNumber}'),
            Text(
              '${submission.messageCount} message${submission.messageCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
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
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 1),
            const Icon(
              Icons.message,
              size: 12,
              color: Colors.blue,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
