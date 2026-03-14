import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement_model.dart';

class AnnouncementService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch active, non-expired announcements ordered by priority desc, then created_at desc
  static Future<List<Announcement>> getActiveAnnouncements() async {
    try {
      final now = DateTime.now().toIso8601String();
      final response = await _client
          .from('announcements')
          .select('id, title, body, type, image_url, link_url, priority, created_at, expires_at')
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.$now')
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Announcement.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ AnnouncementService: Error fetching announcements: $e');
      return [];
    }
  }

  /// Check if there's a high-priority announcement (e.g. for popup on launch)
  static Future<Announcement?> getTopPriorityAnnouncement({int minPriority = 10}) async {
    final list = await getActiveAnnouncements();
    return list.isNotEmpty && list.first.priority >= minPriority ? list.first : null;
  }
}
