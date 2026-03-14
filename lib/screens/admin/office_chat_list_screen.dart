import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/office_message_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import 'office_chat_screen.dart';

class OfficeChatListScreen extends StatefulWidget {
  final Admin? admin;
  final FieldOfficer? fieldOfficer;

  const OfficeChatListScreen({
    super.key,
    this.admin,
    this.fieldOfficer,
  }) : assert(admin != null || fieldOfficer != null);

  @override
  State<OfficeChatListScreen> createState() => _OfficeChatListScreenState();
}

class _OfficeChatListScreenState extends State<OfficeChatListScreen> {
  List<OfficeConversation> _conversations = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  String get _myId => widget.admin?.id ?? widget.fieldOfficer!.id;
  String get _myType => widget.admin != null ? 'admin' : 'field_officer';

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final admins = await AdminService.getAllAdmins();
      final officers = await AdminService.getAllFieldOfficers();
      final conversations = await AdminService.getOfficeConversations(myId: _myId, myType: _myType);

      final convMap = <String, OfficeConversation>{};
      for (final c in conversations) {
        convMap['${c.otherType}:${c.otherId}'] = c;
      }

      final list = <OfficeConversation>[];
      for (final a in admins) {
        if (a.id == _myId && _myType == 'admin') continue;
        list.add(convMap['admin:${a.id}'] ?? OfficeConversation(otherId: a.id, otherType: 'admin', otherName: a.username));
      }
      for (final o in officers) {
        if (o.id == _myId && _myType == 'field_officer') continue;
        list.add(convMap['field_officer:${o.id}'] ?? OfficeConversation(otherId: o.id, otherType: 'field_officer', otherName: o.name));
      }

      list.sort((a, b) => (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)));

      if (mounted) {
        setState(() {
          _conversations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) _showSnackBar('Error: $e');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office chat'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No team members to chat with', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final c = _conversations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.otherType == 'admin' ? AppColors.primaryGreen : AppColors.accentOrange,
                        child: Text(
                          c.otherName.isNotEmpty ? c.otherName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(c.otherName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (c.otherType == 'admin') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Admin', style: TextStyle(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                            ),
                          ] else ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accentOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Field officer', style: TextStyle(fontSize: 11, color: AppColors.accentOrange, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: c.lastContent != null && c.lastContent!.isNotEmpty
                          ? Text(c.lastContent!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13))
                          : const Text('Tap to start chat', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      trailing: c.unreadCount > 0
                          ? CircleAvatar(radius: 12, backgroundColor: AppColors.primaryGreen, child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)))
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OfficeChatScreen(
                              admin: widget.admin,
                              fieldOfficer: widget.fieldOfficer,
                              otherId: c.otherId,
                              otherType: c.otherType,
                              otherName: c.otherName,
                            ),
                          ),
                        ).then((_) => _load(silent: true));
                      },
                    );
                  },
                ),
    );
  }
}
