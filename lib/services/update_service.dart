import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_version.dart';

class AppUpdateInfo {
  final String versionName;
  final int buildNumber;
  final String downloadUrl;
  final bool forceUpdate;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.downloadUrl,
    this.forceUpdate = false,
    this.releaseNotes,
  });
}

class UpdateService {
  static final _client = Supabase.instance.client;

  /// Default APK URL (used when server does not provide a valid download_url)
  static const String defaultApkUrl =
      'https://czfjhpnmkuvbcupombgp.supabase.co/storage/v1/object/public/app-releases/app-release.apk';

  static String _effectiveDownloadUrl(String? fromServer) {
    final url = (fromServer ?? '').trim();
    if (url.isEmpty || url.contains('your-apk-url') || url.contains('example.com')) {
      return defaultApkUrl;
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return defaultApkUrl;
  }

  /// Check if a newer version is available; returns update info or null.
  /// When releasing a new APK: update version in pubspec.yaml AND app_version.dart
  /// (e.g. 1.0.0+2 and appBuildNumber = 2) so the update prompt stops after users install.
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final currentBuild = appBuildNumber;

      final response = await _client
          .from('app_versions')
          .select('version_name, build_number, download_url, force_update, release_notes')
          .eq('is_active', true)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final serverBuild = (response['build_number'] as num?)?.toInt() ?? 0;
      // Only show update when there is a NEW version (higher build). Never show again once user is on latest.
      if (serverBuild <= currentBuild) return null;

      final rawUrl = response['download_url']?.toString() ?? '';
      return AppUpdateInfo(
        versionName: response['version_name'] ?? '',
        buildNumber: serverBuild,
        downloadUrl: _effectiveDownloadUrl(rawUrl),
        forceUpdate: response['force_update'] == true,
        releaseNotes: response['release_notes']?.toString(),
      );
    } catch (e) {
      print('❌ UpdateService: $e');
      return null;
    }
  }

  /// Open the download URL in browser (e.g. Play Store or direct link)
  static Future<bool> openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      print('❌ UpdateService: Could not open URL: $e');
    }
    return false;
  }

  /// Download APK from [url] and trigger system install (Android).
  /// [onProgress] receives (received, total) bytes; total may be 0 until known.
  /// Returns true if download and open-for-install succeeded; false otherwise
  /// (e.g. not Android → fall back to [openDownloadUrl]).
  static Future<bool> downloadAndInstallApk(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (!Platform.isAndroid) return false;
    if (url.isEmpty) return false;

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/app-update.apk';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          onProgress?.call(received, total);
        },
      );

      final result = await OpenFile.open(savePath, type: 'application/vnd.android.package-archive');
      return result.type == ResultType.done;
    } catch (e) {
      print('❌ UpdateService: downloadAndInstallApk $e');
      return false;
    }
  }
}
