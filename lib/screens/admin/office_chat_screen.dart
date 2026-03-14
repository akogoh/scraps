import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/office_message_model.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_colors.dart';

class OfficeChatScreen extends StatefulWidget {
  final Admin? admin;
  final FieldOfficer? fieldOfficer;
  final String otherId;
  final String otherType;
  final String otherName;

  const OfficeChatScreen({
    super.key,
    this.admin,
    this.fieldOfficer,
    required this.otherId,
    required this.otherType,
    required this.otherName,
  }) : assert(admin != null || fieldOfficer != null);

  @override
  State<OfficeChatScreen> createState() => _OfficeChatScreenState();
}

class _OfficeChatScreenState extends State<OfficeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  List<OfficeMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  String get _myId => widget.admin?.id ?? widget.fieldOfficer!.id;
  String get _myType => widget.admin != null ? 'admin' : 'field_officer';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final messages = await AdminService.getOfficeMessages(
        myId: _myId,
        myType: _myType,
        otherId: widget.otherId,
        otherType: widget.otherType,
      );
      final hasNew = messages.length > _messages.length;
      final wasAtBottom = _scrollController.hasClients &&
          (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50);
      if (mounted) {
        setState(() {
          _messages = messages;
          if (!silent) _isLoading = false;
        });
      }
      if (hasNew && (wasAtBottom || !silent) && _scrollController.hasClients) {
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
      if (mounted) setState(() => _isLoading = false);
      if (mounted) _showSnackBar('Error loading messages');
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
      if (mounted) _showSnackBar('Error picking image');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null && _selectedImageBytes == null) return;

    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_selectedImage != null || _selectedImageBytes != null) {
        if (kIsWeb) {
          imageUrl = await SupabaseService.uploadImageBytes(
            bytes: _selectedImageBytes!,
            originalFileName: _selectedImageName ?? 'office_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else {
          imageUrl = await SupabaseService.uploadImage(_selectedImage!);
        }
      }
      final error = await AdminService.sendOfficeMessage(
        senderId: _myId,
        senderType: _myType,
        recipientId: widget.otherId,
        recipientType: widget.otherType,
        content: text.isEmpty ? (imageUrl != null ? '[Image]' : '') : text,
        imageUrl: imageUrl,
      );
      if (mounted) {
        if (error == null) {
          _messageController.clear();
          setState(() {
            _selectedImage = null;
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
          _loadMessages();
          _showSnackBar('Sent', isError: false);
        } else {
          _showSnackBar('Failed to send');
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error sending');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primaryGreen,
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
            Text(widget.otherName),
            Text(
              widget.otherType == 'admin' ? 'Admin' : 'Field officer',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadMessages()),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Say hi!', style: TextStyle(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _buildBubble(_messages[index]),
                      ),
          ),
          if (_selectedImage != null || _selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb && _selectedImageBytes != null
                          ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                          : _selectedImage != null
                              ? Image.file(_selectedImage!, fit: BoxFit.cover)
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Image selected', style: TextStyle(color: Colors.grey))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectedImage = null; _selectedImageBytes = null; _selectedImageName = null; })),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey[300]!))),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.add_photo_alternate), color: AppColors.primaryGreen, onPressed: _pickImage),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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

  Widget _buildBubble(OfficeMessage msg) {
    final isMe = msg.senderId == _myId && msg.senderType == _myType;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.otherType == 'admin' ? AppColors.primaryGreen : AppColors.accentOrange,
              child: Text(widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryGreen : Colors.grey[200],
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(msg.imageUrl!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(msg.imageUrl!, width: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (msg.content.isNotEmpty)
                    Text(msg.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryGreen,
              child: Text((widget.admin?.username ?? widget.fieldOfficer?.name ?? 'Me')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }
}
