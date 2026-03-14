import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../utils/app_colors.dart';
import '../screens/announcements/announcements_screen.dart';

const _readIdsKey = 'announcement_read_ids';

class AnnouncementBell extends StatefulWidget {
  final bool showBadge;
  final VoidCallback? onTap;

  const AnnouncementBell({
    super.key,
    this.showBadge = true,
    this.onTap,
  });

  @override
  State<AnnouncementBell> createState() => _AnnouncementBellState();
}

class _AnnouncementBellState extends State<AnnouncementBell>
    with WidgetsBindingObserver {
  List<Announcement> _announcements = [];
  Set<String> _readIds = {};
  int _unreadCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReadIds();
    _fetchAndUpdate();
    // Auto-pick updates: every 90 seconds + when app resumes
    _refreshTimer = Timer.periodic(const Duration(seconds: 90), (_) => _fetchAndUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAndUpdate();
    }
  }

  Future<void> _loadReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readIdsKey);
      if (list != null && mounted) {
        setState(() => _readIds = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _fetchAndUpdate() async {
    final list = await AnnouncementService.getActiveAnnouncements();
    await _loadReadIds();
    if (!mounted) return;
    final unread = list.where((a) => !_readIds.contains(a.id)).length;
    setState(() {
      _announcements = list;
      _unreadCount = unread;
    });
  }

  Future<void> _markAllRead() async {
    final ids = _announcements.map((a) => a.id).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readIdsKey, ids);
    } catch (_) {}
    if (mounted) setState(() => _unreadCount = 0);
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    _markAllRead();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnnouncementsScreen(),
      ),
    ).then((_) => _fetchAndUpdate());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.campaign_outlined),
          onPressed: _handleTap,
          tooltip: 'Announcements',
        ),
        if (widget.showBadge && _unreadCount > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.accentOrange,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Call from app launch to optionally show popup for high-priority announcements
/// Uses in-memory storage so popup shows again on each app launch (login)
class AnnouncementPopupHelper {
  static final Set<String> _shownThisSession = {};

  static Future<void> maybeShowPopup(BuildContext context) async {
    final top = await AnnouncementService.getTopPriorityAnnouncement(minPriority: 10);
    if (top == null || !context.mounted) return;
    if (_shownThisSession.contains(top.id)) return; // Already showed this session

    _shownThisSession.add(top.id);
    if (!context.mounted) return;
    _showAnnouncementDialog(context, top);
  }

  static void _showAnnouncementDialog(BuildContext context, Announcement a) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.textDark.withOpacity(0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen,
                      const Color(0xFF03a065),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        a.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            a.isDeal
                                ? Icons.local_offer_rounded
                                : Icons.campaign_rounded,
                            color: AppColors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            a.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Content
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.body,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (a.imageUrl != null && a.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            a.imageUrl!,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textGrey,
                      ),
                      child: const Text('Dismiss'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AnnouncementsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.campaign_rounded, size: 20),
                        label: const Text('View all'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
