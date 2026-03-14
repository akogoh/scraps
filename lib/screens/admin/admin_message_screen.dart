import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/admin_submission_model.dart';
import '../../models/message_model.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_colors.dart';

class AdminMessageScreen extends StatefulWidget {
  final AdminSubmission submission;
  final Admin? admin;
  final FieldOfficer? fieldOfficer;

  const AdminMessageScreen({
    super.key,
    required this.submission,
    this.admin,
    this.fieldOfficer,
  }) : assert(admin != null || fieldOfficer != null,
            'Either admin or fieldOfficer must be provided');

  @override
  State<AdminMessageScreen> createState() => _AdminMessageScreenState();
}

class _AdminMessageScreenState extends State<AdminMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;

  // Image picker state
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Start auto-refresh timer (poll every 3 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final messages =
          await AdminService.getMessagesForSubmission(widget.submission.id);

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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = image.name;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: ${e.toString()}');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty &&
        _selectedImage == null &&
        _selectedImageBytes == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null || _selectedImageBytes != null) {
        if (kIsWeb) {
          imageUrl = await SupabaseService.uploadImageBytes(
            bytes: _selectedImageBytes!,
            originalFileName: _selectedImageName ??
                'message_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else {
          imageUrl = await SupabaseService.uploadImage(_selectedImage!);
        }
      }

      final adminId = widget.admin?.id ?? widget.fieldOfficer?.id ?? '';
      final success = await AdminService.sendMessageToUser(
        submissionId: widget.submission.id,
        content: messageText.isEmpty
            ? (imageUrl != null ? '[Image]' : '')
            : messageText,
        adminId: adminId,
        imageUrl: imageUrl,
      );

      if (success) {
        _messageController.clear();
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = null;
          _selectedImageName = null;
        });
        _loadMessages(); // Reload messages
        _showSnackBar('Message sent successfully', isError: false);
      } else {
        _showSnackBar('Failed to send message. Check database setup.');
      }
    } catch (e) {
      _showSnackBar('Error sending message: ${e.toString()}');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
            const Text('Messages'),
            Text(
              widget.submission.itemName,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // Submission Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversation with ${widget.submission.userName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Phone: ${widget.submission.phoneNumber}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Item: ${widget.submission.itemName}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
          ),

          // Selected Image Preview
          if (_selectedImage != null || _selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.memory(
                              _selectedImageBytes!,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Image selected',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _selectedImageBytes = null;
                        _selectedImageName = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate),
                  color: AppColors.primaryGreen,
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 2,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryGreen,
                  child: IconButton(
                    iconSize: 16,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 16),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isAdminMessage = message.isAdminMessage;
    final isFromAdmin = widget.admin != null;
    final senderLabel = isAdminMessage
        ? (isFromAdmin ? 'GreenHaul Admin' : 'GreenHaul Officer')
        : widget.submission.userName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isAdminMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isAdminMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isAdminMessage ? AppColors.primaryGreen : Colors.grey[200],
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isAdminMessage
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isAdminMessage
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
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
                      color: isAdminMessage
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[700],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (message.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () => _showImageDialog(message.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 150,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (message.content.isNotEmpty) ...[
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isAdminMessage ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isAdminMessage
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdminMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryGreen,
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _showImageDialog(String imageUrl) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 100),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
