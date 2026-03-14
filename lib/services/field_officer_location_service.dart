import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'admin_service.dart';

/// Keeps sending field officer location every 30s even after they log out,
/// until the app process ends. Started when they open the dashboard as field officer.
class FieldOfficerLocationService {
  static String? _officerId;
  static Timer? _timer;

  /// Start background location updates for this officer. Keeps running after logout.
  static void start(String officerId) {
    if (_officerId == officerId && _timer != null) return;
    _officerId = officerId;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _sendUpdate());
    // Send once soon
    Future.delayed(const Duration(seconds: 2), _sendUpdate);
  }

  /// Stop updates (e.g. if you want to stop on logout in future). Not called on logout by default.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _officerId = null;
  }

  static Future<void> _sendUpdate() async {
    final id = _officerId;
    if (id == null) return;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await AdminService.updateFieldOfficerLocation(
        officerId: id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Silent fail
    }
  }
}
