import 'package:flutter/material.dart';
import '../utils/app_images.dart';
import '../utils/app_colors.dart';
import '../utils/app_version.dart';
import '../services/update_service.dart';
import 'onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Only shows when server has a newer build than current; otherwise user is left alone.
    final update = await UpdateService.checkForUpdate();
    if (update != null && mounted) {
      _showUpdateDialog(update);
      return;
    }

    _navigateToNext();
  }

  void _navigateToNext() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen(),
      ),
    );
  }

  void _startDownloadAndInstall(AppUpdateInfo update) {
    final progressNotifier =
        ValueNotifier<double?>(null); // null = indeterminate
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(progress: progressNotifier),
    );
    UpdateService.downloadAndInstallApk(
      update.downloadUrl,
      onProgress: (received, total) {
        if (total > 0) {
          progressNotifier.value = (received / total).clamp(0.0, 1.0);
        }
      },
    ).then((bool installTriggered) async {
      if (!mounted) return;
      Navigator.pop(context); // close progress dialog

      if (!installTriggered) {
        // Install screen didn't open - fallback to browser if URL is real
        final url = update.downloadUrl.trim();
        final isPlaceholder = url.isEmpty ||
            url.contains('your-apk-url') ||
            url.contains('example.com');
        final isRealUrl =
            url.startsWith('http://') || url.startsWith('https://');
        if (isPlaceholder || !isRealUrl) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Download failed. Please set a valid APK URL in app settings.'),
                backgroundColor: AppColors.accentOrange,
              ),
            );
          }
        } else {
          await UpdateService.openDownloadUrl(update.downloadUrl);
        }
        if (update.forceUpdate && mounted) {
          _showUpdateDialog(update);
        } else if (mounted) {
          _navigateToNext();
        }
        return;
      }

      // Install was triggered - give the system time to show the install screen
      // (don't navigate yet or we steal focus and the user never sees it)
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      _showInstallPromptDialog(update);
    });
  }

  void _showInstallPromptDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.install_mobile_rounded,
                  color: AppColors.primaryGreen, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Complete installation',
                      style: TextStyle(fontSize: 20))),
            ],
          ),
          content: const Text(
            'The install screen should appear on your device. If you don\'t see it, check your recent apps or notifications.\n\nTap OK after you\'ve installed the update or cancelled.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToNext();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (context) => PopScope(
        canPop: !update.forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                color: AppColors.primaryGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update available',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${update.versionName} is available.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your version: v$appVersionName (build $appBuildNumber)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (update.releaseNotes != null &&
                    update.releaseNotes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    update.releaseNotes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
                if (update.forceUpdate) ...[
                  const SizedBox(height: 12),
                  Text(
                    'This update is required to continue using the app.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accentOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!update.forceUpdate)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToNext();
                },
                child: const Text('Later'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                if (!mounted) return;
                _startDownloadAndInstall(update);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryGreen,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo with beautiful shadow
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      AppImages.getImageForContext('splash'),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.recycling,
                            size: 80,
                            color: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // App Name
              const Text(
                'GreenHaul',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Turn your waste into wealth',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),

              // Loading indicator with accent color
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 32),
              // Version info so we know we're on the right build
              Text(
                'v$appVersionName ($appBuildNumber)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({required this.progress});

  final ValueNotifier<double?> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final hasProgress = value != null && value >= 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 48,
                  color: AppColors.primaryGreen.withOpacity(0.9),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Downloading update...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  hasProgress ? '${(value * 100).round()}%' : 'Preparing...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: hasProgress ? value : null,
                    minHeight: 8,
                    backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
