import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../services/announcement_service.dart';
import '../../utils/app_images.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_version.dart';
import '../scrap_submission/scrap_submission_screen.dart';
import '../reports/reports_screen.dart';
import '../admin/admin_main_screen.dart';
import '../services/services_screen.dart';
import '../help/help_support_screen.dart';
import '../../services/push_notification_service.dart';
import '../../widgets/announcement_bell.dart';
import '../announcements/announcements_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  int _totalSubmissions = 0;
  double _totalAmountPaid = 0.0;
  bool _isLoadingStats = true;
  Timer? _refreshTimer;
  bool _showLoginAnnouncementPrompt = false;
  int _unreadAnnouncementCount = 0;
  Timer? _loginPromptDismissTimer;
  Set<String> _mySubmissionIds = {};
  RealtimeChannel? _messagesChannel;
  Timer? _messageIdsRefreshTimer;

  @override
  void initState() {
    super.initState();
    PushNotificationService.registerToken(userId: widget.user.id);
    _loadSubmissionCount();
    _startAutoRefresh();
    _refreshMessageSubmissionIds();
    _subscribeToNewMessages();
    _messageIdsRefreshTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _refreshMessageSubmissionIds());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnnouncementPopupHelper.maybeShowPopup(context);
      _checkAndShowLoginAnnouncementPrompt();
    });

    // Fallback timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoadingStats) {
        print('⏰ Dashboard: Loading timeout, setting count to 0');
        setState(() {
          _totalSubmissions = 0;
          _isLoadingStats = false;
        });
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      print('🔄 Dashboard: Auto-refreshing data...');
      _refreshStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _loginPromptDismissTimer?.cancel();
    _messageIdsRefreshTimer?.cancel();
    _messagesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshMessageSubmissionIds() async {
    final ids =
        await SupabaseService.getUserSubmissionIds(widget.user.phoneNumber);
    if (mounted) setState(() => _mySubmissionIds = ids.toSet());
  }

  void _subscribeToNewMessages() {
    _messagesChannel = Supabase.instance.client
        .channel('user-messages-${widget.user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (!mounted) return;
            final n = payload.newRecord;
            if (n['is_admin_message'] == true &&
                _mySubmissionIds.contains(n['submission_id']?.toString())) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New message from team'),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> _checkAndShowLoginAnnouncementPrompt() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    try {
      final list = await AnnouncementService.getActiveAnnouncements();
      final prefs = await SharedPreferences.getInstance();
      final readIds =
          (prefs.getStringList('announcement_read_ids') ?? []).toSet();
      final unread = list.where((a) => !readIds.contains(a.id)).length;
      if (unread > 0 && mounted) {
        setState(() {
          _showLoginAnnouncementPrompt = true;
          _unreadAnnouncementCount = unread;
        });
        _loginPromptDismissTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showLoginAnnouncementPrompt = false);
        });
      }
    } catch (_) {}
  }

  void _dismissLoginAnnouncementPrompt() {
    _loginPromptDismissTimer?.cancel();
    setState(() => _showLoginAnnouncementPrompt = false);
  }

  void _openAnnouncementsFromPrompt() {
    _dismissLoginAnnouncementPrompt();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnnouncementsScreen(),
      ),
    );
  }

  Future<void> _loadSubmissionCount() async {
    try {
      // Try to get phone number from session first
      String? phoneNumber = await SessionManager.getCurrentUserPhone();
      print('📱 Dashboard: Phone number from session: $phoneNumber');

      // Fallback to widget user data if session fails
      if (phoneNumber == null) {
        phoneNumber = widget.user.phoneNumber;
        print('📱 Dashboard: Using phone number from widget: $phoneNumber');
      }

      if (phoneNumber.isNotEmpty) {
        final submissions =
            await SupabaseService.getUserSubmissions(phoneNumber);
        print('📊 Dashboard: Found ${submissions.length} submissions');

        // Calculate total amount paid (sum of prices for completed/approved submissions)
        double totalPaid = 0.0;
        for (var submission in submissions) {
          if ((submission.status == 'completed' ||
                  submission.status == 'approved') &&
              submission.price > 0) {
            totalPaid += submission.price;
          }
        }

        setState(() {
          _totalSubmissions = submissions.length;
          _totalAmountPaid = totalPaid;
          _isLoadingStats = false;
        });
      } else {
        print('❌ Dashboard: No phone number found in session');
        setState(() {
          _totalSubmissions = 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ Dashboard: Error loading submission count: $e');
      setState(() {
        _totalSubmissions = 0;
        _isLoadingStats = false;
      });
    }
  }

  void _refreshStats() {
    _loadSubmissionCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeScreen(),
              const ReportsScreen(),
            ],
          ),
          if (_showLoginAnnouncementPrompt) _buildLoginAnnouncementPrompt(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Refresh stats when switching to home tab
          if (index == 0) {
            _refreshStats();
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reports',
          ),
        ],
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildLoginAnnouncementPrompt() {
    final count = _unreadAnnouncementCount;
    final text = count == 1 ? '1 new announcement' : '$count new announcements';
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: _openAnnouncementsFromPrompt,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textDark.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: AppColors.primaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _dismissLoginAnnouncementPrompt,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textGrey,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.85),
                      const Color(0xFF038a5e),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminMainScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            AppImages.getImageForContext('drawer'),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.recycling,
                              size: 36,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.user.name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 16,
                          color: AppColors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.user.phoneNumber,
                          style: TextStyle(
                            color: AppColors.white.withOpacity(0.95),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu items
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  children: <Widget>[
                    _drawerItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _selectedIndex = 0);
                      },
                      isSelected: _selectedIndex == 0,
                    ),
                    _drawerItem(
                      icon: Icons.assessment_rounded,
                      label: 'Reports',
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _selectedIndex = 1);
                      },
                      isSelected: _selectedIndex == 1,
                    ),
                    const SizedBox(height: 8),
                    _drawerItem(
                      icon: Icons.campaign_rounded,
                      label: 'Announcements',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnnouncementsScreen(),
                          ),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.business_center_rounded,
                      label: 'Our Services',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ServicesScreen(),
                          ),
                        );
                      },
                    ),
                    _drawerItem(
                      icon: Icons.help_rounded,
                      label: 'Help & Support',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Logout, Delete Account & version
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showLogoutDialog,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showDeleteAccountDialog,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.delete_forever_rounded,
                                  color: Colors.red.shade900,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Delete Account',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v$appVersionName (build $appBuildNumber)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
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

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.35),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen.withOpacity(0.2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textGrey,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        actions: const [
          AnnouncementBell(),
        ],
        title: Row(
          children: [
            GestureDetector(
              onLongPress: () {
                print('🔧 Field Officer access triggered from app bar!');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminMainScreen(),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  AppImages.getImageForContext('appbar'),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.recycling,
                        size: 20,
                        color: AppColors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('GreenHaul'),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryGreen, Color(0xFF03a065)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Top Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back!',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.user.name,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.accentOrange,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Submissions',
                            value: _isLoadingStats
                                ? '...'
                                : _totalSubmissions.toString(),
                            icon: Icons.assignment,
                            isPrimary: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Total Earnings',
                            value: _isLoadingStats
                                ? '...'
                                : 'GH\u20B5 ${_totalAmountPaid.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Section
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Sell Scrap Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryGreen, Color(0xFF03a065)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ScrapSubmissionScreen(),
                                ),
                              );
                              // Refresh stats when returning from submission
                              if (result == true || result == null) {
                                _refreshStats();
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 20,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sell,
                                    size: 36,
                                    color: AppColors.white,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Sell Scrap',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.assessment,
                              title: 'View Reports',
                              gradientColors: const [
                                AppColors.primaryGreen,
                                Color(0xFF03a065),
                              ],
                              onTap: () {
                                setState(() {
                                  _selectedIndex = 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.help_outline,
                              title: 'Help & Support',
                              gradientColors: const [
                                AppColors.accentOrange,
                                Color(0xFF9a4612),
                              ],
                              onTap: () {
                                _showHelpDialog();
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Services Section
                      _buildServicesSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Our Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Service Images Preview
        _buildServiceImagesPreview(),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryGreen.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildServiceItem(
                icon: Icons.home,
                title: 'Home Pickup',
                description: 'We come to your home to collect scrap materials',
              ),
              const SizedBox(height: 16),
              _buildServiceItem(
                icon: Icons.business,
                title: 'Business Services',
                description: 'Bulk collection for workshops and companies',
              ),
              const SizedBox(height: 16),
              _buildServiceItem(
                icon: Icons.directions_car,
                title: 'Vehicle Scrapping',
                description: 'We buy condemned accident vehicles',
              ),
              const SizedBox(height: 16),
              _buildServiceItem(
                icon: Icons.recycling,
                title: 'Metal Recycling',
                description: 'All types of metal scraps accepted',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryGreen, Color(0xFF03a065)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServicesScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      color: AppColors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View All Services',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.2),
                AppColors.primaryGreen.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryGreen,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceImagesPreview() {
    // Show a few sample images from the gallery
    List<String> sampleImages = [
      'assets/g1.jpg',
      'assets/g2.jpg',
      'assets/g3.jpg',
      'assets/g4.jpg',
      'assets/g5.jpg',
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sampleImages.length,
        itemBuilder: (context, index) {
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GestureDetector(
                onTap: () => _showImageDialog(context, sampleImages[index]),
                child: Stack(
                  children: [
                    Image.asset(
                      sampleImages[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 30,
                          ),
                        );
                      },
                    ),
                    // Click indicator overlay
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: AppColors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Full screen image
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 100,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate back to onboarding
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/onboarding',
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  /// In-app account deletion (Apple App Store Guideline 5.1.1(v)).
  /// Requires the user to type DELETE to confirm — guards against
  /// accidental taps and signals the destructive nature clearly.
  void _showDeleteAccountDialog() {
    final controller = TextEditingController();
    bool canDelete = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.delete_forever_rounded,
                      color: Colors.red.shade900),
                  const SizedBox(width: 8),
                  const Text('Delete Account'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Your account and profile'),
                  const Text('• All your scrap submissions'),
                  const Text('• All your photos and videos'),
                  const Text('• All your messages with our team'),
                  const SizedBox(height: 12),
                  const Text(
                    'This action cannot be undone. To confirm, type DELETE below.',
                    style: TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final next = value.trim().toUpperCase() == 'DELETE';
                      if (next != canDelete) {
                        setStateDialog(() => canDelete = next);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canDelete
                      ? () {
                          Navigator.pop(dialogContext);
                          _performAccountDeletion();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performAccountDeletion() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    try {
      await SupabaseService.deleteAccount(userId: widget.user.id);
      await SessionManager.clearUserSession();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted. Goodbye.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/onboarding',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          backgroundColor: Colors.red.shade900,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: const Text(
            'Need help? Contact GreenHaul Solutions Ltd.\n\nPhone: 0249211930 / 0201032117 / 0303981066\nEmail: info@greenhaulsolution.com\nAddress: GP 1837, Accra Central\n\nOr tap "View All Services" for more details.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportScreen(),
                  ),
                );
              },
              child: const Text('More Details'),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isPrimary;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    // Use only GreenHaul colors - primaryGreen or accentOrange
    final cardColor =
        isPrimary ? AppColors.primaryGreen : AppColors.accentOrange;

    return Container(
      height: 180, // Fixed height to ensure both cards are same size
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor.withOpacity(0.3),
            cardColor.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardColor.withOpacity(0.8),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(height: 8),
          // Icon - Fixed size and position
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          // Value - Use FittedBox to prevent overflow
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title - Fixed size
          Text(
            title,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.3,
              shadows: [
                Shadow(
                  color: cardColor.withOpacity(0.5),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final List<Color> gradientColors;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors[0].withOpacity(0.1),
              gradientColors[1].withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gradientColors[0].withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradientColors[0].withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: gradientColors[0],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
