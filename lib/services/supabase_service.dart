import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart' as models;
import '../models/scrap_submission_model.dart';
import '../models/message_model.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  // User operations
  static Future<models.User?> getUserByPhone(String phoneNumber) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('phone_number', phoneNumber)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return models.User.fromJson(response);
    } catch (e) {
      print('❌ Error getting user by phone: $e');
      return null;
    }
  }

  // Create or get user (upsert pattern)
  // This handles the case where user might already exist
  static Future<models.User> createOrGetUser(
      String name, String phoneNumber) async {
    try {
      // First, try to get existing user
      final existingUser = await getUserByPhone(phoneNumber);
      if (existingUser != null) {
        print(
            '✅ User already exists: ${existingUser.name} (${existingUser.phoneNumber})');
        return existingUser;
      }

      // User doesn't exist, create new user
      final now = DateTime.now();
      final user = models.User(
        id: _uuid.v4(),
        name: name,
        phoneNumber: phoneNumber,
        createdAt: now,
      );

      try {
        await _client.from('users').insert(user.toJson());
        print('✅ New user created: ${user.name} (${user.phoneNumber})');
        return user;
      } catch (e) {
        // Handle duplicate key error - user might have been created between check and insert
        if (e.toString().contains('duplicate key') ||
            e.toString().contains('23505')) {
          print('⚠️ Duplicate key detected, fetching existing user...');
          // Try to get the user again
          final retryUser = await getUserByPhone(phoneNumber);
          if (retryUser != null) {
            print(
                '✅ User found after duplicate error: ${retryUser.name} (${retryUser.phoneNumber})');
            return retryUser;
          }
        }
        rethrow;
      }
    } catch (e) {
      print('❌ Error in createOrGetUser: $e');
      rethrow;
    }
  }

  // Create user (kept for backward compatibility, but use createOrGetUser instead)
  static Future<models.User> createUser(String name, String phoneNumber) async {
    return await createOrGetUser(name, phoneNumber);
  }

  /// Get user by id (e.g. to backfill phone for submission).
  static Future<models.User?> getUserById(String userId) async {
    try {
      final response =
          await _client.from('users').select().eq('id', userId).maybeSingle();
      if (response == null) return null;
      return models.User.fromJson(response);
    } catch (e) {
      print('❌ Error getting user by id: $e');
      return null;
    }
  }

  // Scrap submission operations
  // Upload media to Supabase Storage and return public URL
  static Future<String?> _uploadMediaFile({
    required File file,
    required String folder,
  }) async {
    try {
      final fileName = file.path.split('/').last.split('\\').last;
      final uniquePath =
          '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('scrap-media').upload(uniquePath, file);
      final publicUrl =
          _client.storage.from('scrap-media').getPublicUrl(uniquePath);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadImage(File file) {
    return _uploadMediaFile(file: file, folder: 'images');
  }

  static Future<String?> uploadVideo(File file) {
    return _uploadMediaFile(file: file, folder: 'videos');
  }

  // Web: upload bytes variant
  static Future<String?> _uploadMediaBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    try {
      final uniquePath =
          '$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('scrap-media').uploadBinary(uniquePath, bytes);
      final publicUrl =
          _client.storage.from('scrap-media').getPublicUrl(uniquePath);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadImageBytes({
    required Uint8List bytes,
    required String originalFileName,
  }) {
    return _uploadMediaBytes(
      bytes: bytes,
      fileName: originalFileName,
      folder: 'images',
    );
  }

  /// Upload collection photo (field officer / admin) to scrap-media/images
  static Future<String?> uploadCollectionImage(File file) {
    return _uploadMediaFile(file: file, folder: 'images');
  }

  /// Upload collection photo from bytes (web)
  static Future<String?> uploadCollectionImageBytes({
    required Uint8List bytes,
    required String originalFileName,
  }) {
    return _uploadMediaBytes(
      bytes: bytes,
      fileName: originalFileName,
      folder: 'images',
    );
  }

  static Future<String?> uploadVideoBytes({
    required Uint8List bytes,
    required String originalFileName,
  }) {
    return _uploadMediaBytes(
      bytes: bytes,
      fileName: originalFileName,
      folder: 'videos',
    );
  }

  /// Lightweight list of submission IDs for the current user (for realtime message filtering).
  static Future<List<String>> getUserSubmissionIds(String phoneNumber) async {
    try {
      final response = await _client
          .from('scrap_submissions')
          .select('id')
          .eq('phone_number', phoneNumber);
      return (response as List)
          .map<String>((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<ScrapSubmission>> getUserSubmissions(
      String phoneNumber) async {
    try {
      // Get all submissions for the user
      final response = await _client
          .from('scrap_submissions')
          .select()
          .eq('phone_number', phoneNumber)
          .order('submitted_at', ascending: false);

      final submissionsJson = response as List;

      // Collect unique officer IDs to batch fetch
      final Set<String> officerIds = {};
      for (var json in submissionsJson) {
        if (json['assigned_officer_id'] != null) {
          officerIds.add(json['assigned_officer_id'].toString());
        }
      }

      // Batch fetch all officer names using OR filter
      Map<String, String> officerNamesMap = {};
      if (officerIds.isNotEmpty) {
        try {
          // Build OR condition for multiple IDs
          final orConditions = officerIds.map((id) => 'id.eq.$id').join(',');

          final officersResponse = await _client
              .from('field_officers')
              .select('id, name')
              .or(orConditions);

          for (var officer in officersResponse) {
            officerNamesMap[officer['id'].toString()] = officer['name'];
          }
        } catch (e) {
          print('⚠️ Error batch fetching officer names: $e');
          // Fallback: fetch one by one (slower but reliable)
          for (var officerId in officerIds) {
            try {
              final officerResponse = await _client
                  .from('field_officers')
                  .select('id, name')
                  .eq('id', officerId)
                  .maybeSingle();

              if (officerResponse != null) {
                officerNamesMap[officerId] = officerResponse['name'];
              }
            } catch (err) {
              print('⚠️ Error fetching officer $officerId: $err');
            }
          }
        }
      }

      // Build submissions with officer names
      return submissionsJson.map((json) {
        String? officerName;
        if (json['assigned_officer_id'] != null) {
          officerName = officerNamesMap[json['assigned_officer_id'].toString()];
        }

        return ScrapSubmission.fromJson({
          ...json,
          'assigned_officer_name': officerName,
        });
      }).toList();
    } catch (e) {
      print('❌ Error loading user submissions: $e');
      return [];
    }
  }

  static Future<ScrapSubmission> createScrapSubmission({
    required String userId,
    required String phoneNumber,
    required String itemName,
    String? imageUrl,
    String? videoUrl,
    required String comments,
    double? latitude,
    double? longitude,
    String? address,
    double price = 0,
    bool isSelling = true,
  }) async {
    // Ensure we have a phone: use session phone, or fallback to user's phone from DB
    String phoneToSave = phoneNumber.trim();
    if (phoneToSave.isEmpty) {
      final user = await getUserById(userId);
      if (user != null && user.phoneNumber.trim().isNotEmpty) {
        phoneToSave = user.phoneNumber;
        print(
            '📱 Scrap submission: using phone from users table for user $userId');
      }
    }
    final submission = ScrapSubmission(
      id: _uuid.v4(),
      userId: userId,
      phoneNumber: phoneToSave,
      itemName: itemName,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      comments: comments,
      submittedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      address: address,
      price: price,
      isSelling: isSelling,
    );

    await _client.from('scrap_submissions').insert(submission.toJson());
    return submission;
  }

  // Update price for a scrap submission
  static Future<bool> updateSubmissionPrice({
    required String submissionId,
    required double price,
  }) async {
    try {
      await _client
          .from('scrap_submissions')
          .update({'price': price}).eq('id', submissionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Message operations
  static Future<List<Message>> getMessagesForSubmission(
      String submissionId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('submission_id', submissionId)
          .order('created_at', ascending: true);

      return (response as List).map((json) => Message.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Message> sendMessage({
    required String submissionId,
    required String senderId,
    required String content,
    bool isAdminMessage = false,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final newMessage = Message(
      id: id,
      submissionId: submissionId,
      senderId: senderId,
      content: content,
      isAdminMessage: isAdminMessage,
      createdAt: createdAt,
    );

    // Insert only columns that exist on messages table (omit image_url unless added via migration)
    await _client.from('messages').insert({
      'id': id,
      'submission_id': submissionId,
      'sender_id': senderId,
      'content': content,
      'is_admin_message': isAdminMessage,
      'is_read': false,
      'created_at': createdAt.toIso8601String(),
    });
    return newMessage;
  }

  static Future<bool> hasUnreadMessages(
      String submissionId, String senderId) async {
    try {
      final response = await _client
          .from('messages')
          .select('id')
          .eq('submission_id', submissionId)
          .eq('sender_id', senderId)
          .eq('is_admin_message', true)
          .eq('is_read', false)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get unread message count for a submission
  static Future<int> getUnreadMessageCount(
      String submissionId, String userId) async {
    try {
      final response = await _client
          .from('messages')
          .select('id')
          .eq('submission_id', submissionId)
          .neq('sender_id', userId) // Messages not from the user
          .eq('is_read', false);

      // Count unread messages
      return (response as List).length;
    } catch (e) {
      print('Error getting unread message count: $e');
      return 0;
    }
  }

  // Update collection date for a scrap submission
  static Future<bool> updateCollectionDate(
      String submissionId, DateTime collectionDate) async {
    try {
      await _client
          .from('scrap_submissions')
          .update({'collection_date': collectionDate.toIso8601String()}).eq(
              'id', submissionId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
