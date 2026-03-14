import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/admin_model.dart';
import '../models/admin_submission_model.dart';
import '../models/message_model.dart';
import '../models/field_officer_model.dart';
import '../models/office_message_model.dart';
import 'supabase_service.dart';

class AdminService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();

  // Admin authentication
  static Future<Admin?> loginAdmin(String username, String password) async {
    try {
      // For now, we'll use a simple check
      // In production, you should use proper authentication
      final response = await _client
          .from('admins')
          .select()
          .eq('username', username)
          .eq('is_active', true)
          .single();

      // In production, verify password hash here
      return Admin.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Get all submissions for admin dashboard
  static Future<List<AdminSubmission>> getAllSubmissions() async {
    try {
      print('🔧 AdminService: Fetching all submissions...');
      final response = await _client
          .from('admin_dashboard')
          .select()
          .order('submitted_at', ascending: false);

      print(
          '🔧 AdminService: Received ${(response as List).length} submissions');

      final submissions = (response as List)
          .map((json) {
            try {
              return AdminSubmission.fromJson(json);
            } catch (e) {
              print('❌ AdminService: Error parsing submission: $e');
              print('❌ AdminService: JSON: $json');
              return null;
            }
          })
          .whereType<AdminSubmission>()
          .toList();

      print(
          '✅ AdminService: Successfully parsed ${submissions.length} submissions');
      print('🔧 AdminService: Status breakdown:');
      final statusCounts = <String, int>{};
      for (var sub in submissions) {
        statusCounts[sub.status] = (statusCounts[sub.status] ?? 0) + 1;
      }
      statusCounts.forEach((status, count) {
        print('   - $status: $count');
      });

      return submissions;
    } catch (e) {
      print('❌ AdminService: Error fetching all submissions: $e');
      print('❌ AdminService: Error type: ${e.runtimeType}');
      rethrow; // Re-throw so UI can handle it
    }
  }

  // Get submissions by status
  static Future<List<AdminSubmission>> getSubmissionsByStatus(
      String status) async {
    try {
      print('🔧 AdminService: Fetching submissions with status: $status');
      final response = await _client
          .from('admin_dashboard')
          .select()
          .eq('status', status)
          .order('submitted_at', ascending: false);

      print(
          '🔧 AdminService: Received ${(response as List).length} submissions with status $status');

      final submissions = (response as List)
          .map((json) {
            try {
              return AdminSubmission.fromJson(json);
            } catch (e) {
              print('❌ AdminService: Error parsing submission: $e');
              return null;
            }
          })
          .whereType<AdminSubmission>()
          .toList();

      print(
          '✅ AdminService: Successfully parsed ${submissions.length} submissions with status $status');
      return submissions;
    } catch (e) {
      print('❌ AdminService: Error fetching submissions by status: $e');
      rethrow; // Re-throw so UI can handle it
    }
  }

  /// Update submission status. Returns null on success, or an error message on failure.
  /// [reviewedBy] must be an admin ID (scrap_submissions.reviewed_by references admins).
  /// Pass null for field-officer actions so we don't set an invalid FK.
  static Future<String?> updateSubmissionStatus({
    required String submissionId,
    required String status,
    String? adminNotes,
    String? reviewedBy,
  }) async {
    try {
      final map = <String, dynamic>{
        'status': status,
        'admin_notes': adminNotes,
        'reviewed_at': DateTime.now().toIso8601String(),
      };
      if (reviewedBy != null) {
        map['reviewed_by'] = reviewedBy;
      }
      await _client.from('scrap_submissions').update(map).eq('id', submissionId);
      return null;
    } catch (e) {
      print('❌ AdminService.updateSubmissionStatus: $e');
      return e.toString();
    }
  }

  // Send message to user
  static Future<bool> sendMessageToUser({
    required String submissionId,
    required String content,
    required String adminId,
    String? imageUrl,
  }) async {
    try {
      print('🔧 Admin: Attempting to send message...');
      print('🔧 Admin: Submission ID: $submissionId');
      print('🔧 Admin: Admin ID: $adminId');
      print('🔧 Admin: Content: $content');
      if (imageUrl != null) {
        print('🔧 Admin: Image URL: $imageUrl');
      }

      // First, let's test if we can access the messages table
      print('🔧 Admin: Testing table access...');
      await _client.from('messages').select('id').limit(1);
      print('✅ Admin: Messages table accessible');

      // Get the submission to find the user ID
      print('🔧 Admin: Getting submission details...');
      final submission = await _client
          .from('scrap_submissions')
          .select('user_id')
          .eq('id', submissionId)
          .single();

      final userId = submission['user_id'];
      print('🔧 Admin: Found user ID: $userId');

      // Now try to insert the message using the user ID as sender
      // but mark it as admin message
      // Omit image_url unless messages table has that column (see sql/add_messages_image_url.sql)
      final messageData = {
        'id': _uuid.v4(),
        'submission_id': submissionId,
        'sender_id': userId,
        'content': content,
        'is_admin_message': true,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('🔧 Admin: Inserting message data: $messageData');
      await _client.from('messages').insert(messageData);
      print('✅ Admin: Message sent successfully');
      return true;
    } catch (e) {
      print('❌ Admin: Failed to send message: $e');
      print('❌ Admin: Error type: ${e.runtimeType}');
      return false;
    }
  }

  // Get messages for a submission
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

  // Get submission statistics
  static Future<Map<String, int>> getSubmissionStats() async {
    try {
      final response = await _client.rpc('get_submission_stats');

      if (response != null && response is List && response.isNotEmpty) {
        final stats = response.first;
        return {
          'total': stats['total_submissions'] ?? 0,
          'pending': stats['pending_count'] ?? 0,
          'reviewed': stats['reviewed_count'] ?? 0,
          'approved': stats['approved_count'] ?? 0,
          'rejected': stats['rejected_count'] ?? 0,
        };
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // Get recent submissions
  static Future<List<AdminSubmission>> getRecentSubmissions(
      {int limit = 10}) async {
    try {
      final response = await _client.rpc('get_recent_submissions', params: {
        'limit_count': limit,
      });

      return (response as List)
          .map((json) => AdminSubmission.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Search submissions
  static Future<List<AdminSubmission>> searchSubmissions(String query) async {
    try {
      final response = await _client
          .from('admin_dashboard')
          .select()
          .or('item_name.ilike.%$query%,user_name.ilike.%$query%,phone_number.ilike.%$query%')
          .order('submitted_at', ascending: false);

      return (response as List)
          .map((json) => AdminSubmission.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<AdminSubmission?> getSubmissionById(String id) async {
    try {
      final response =
          await _client.from('admin_dashboard').select().eq('id', id).single();
      final json = Map<String, dynamic>.from(response);
      // admin_dashboard view may not have admin_collection_image_url; fetch from table
      if (json['admin_collection_image_url'] == null) {
        final extra = await _client
            .from('scrap_submissions')
            .select('admin_collection_image_url')
            .eq('id', id)
            .maybeSingle();
        if (extra != null && extra['admin_collection_image_url'] != null) {
          json['admin_collection_image_url'] =
              extra['admin_collection_image_url'];
        }
      }
      return AdminSubmission.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Fetches submission directly from scrap_submissions to guarantee image_url/video_url.
  /// No join to users - avoids RLS/permission issues; we fetch user name separately.
  static Future<AdminSubmission?> getSubmissionWithMedia(String id,
      {String? assignedOfficerId}) async {
    try {
      var query = _client
          .from('scrap_submissions')
          .select('id, item_name, comments, status, submitted_at, created_at, '
              'latitude, longitude, address, image_url, video_url, admin_collection_image_url, '
              'admin_notes, reviewed_by, reviewed_at, price, collection_date, '
              'assigned_officer_id, assigned_at, assigned_by, phone_number, user_id')
          .eq('id', id);
      if (assignedOfficerId != null) {
        query = query.eq('assigned_officer_id', assignedOfficerId);
      }
      final response = await query.maybeSingle();
      if (response == null) return null;
      final json = Map<String, dynamic>.from(response);

      String userName = '';
      try {
        final user = await SupabaseService.getUserById(
            json['user_id']?.toString() ?? '');
        userName = user?.name ?? '';
      } catch (_) {}

      int messageCount = 0;
      try {
        final messages =
            await _client.from('messages').select('id').eq('submission_id', id);
        messageCount = (messages as List).length;
      } catch (_) {}

      return AdminSubmission.fromJson({
        ...json,
        'user_name': userName,
        'phone_number': json['phone_number'] ?? '',
        'message_count': messageCount,
        'submitted_at': json['submitted_at'] ?? json['created_at'],
      });
    } catch (e) {
      return null;
    }
  }

  /// Fetches a submission from field_officer_jobs (includes image_url, video_url).
  /// Use this for field officers so they get full job data from the view they can access.
  static Future<AdminSubmission?> getSubmissionByIdForFieldOfficer(
      String id, String officerId) async {
    try {
      final response = await _client
          .from('field_officer_jobs')
          .select()
          .eq('id', id)
          .eq('assigned_officer_id', officerId)
          .maybeSingle();
      if (response == null) return null;
      final json = Map<String, dynamic>.from(response);
      // field_officer_jobs view may not have admin_collection_image_url; fetch from table
      if (json['admin_collection_image_url'] == null) {
        final extra = await _client
            .from('scrap_submissions')
            .select('admin_collection_image_url')
            .eq('id', id)
            .maybeSingle();
        if (extra != null && extra['admin_collection_image_url'] != null) {
          json['admin_collection_image_url'] =
              extra['admin_collection_image_url'];
        }
      }
      return AdminSubmission.fromJson(json);
    } catch (_) {
      return getSubmissionWithMedia(id, assignedOfficerId: officerId);
    }
  }

  // ========== FIELD OFFICER METHODS ==========

  // Field Officer authentication (name only for now)
  // Uses case-insensitive match so "John Doe" in DB matches "john doe" from app
  static Future<FieldOfficer?> loginFieldOfficer(String name) async {
    try {
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        print('❌ FieldOfficer: Empty name');
        return null;
      }
      print('🔧 FieldOfficer: Attempting login with name: "$trimmedName"');

      // Try exact match first (for speed when names match exactly)
      var response = await _client
          .from('field_officers')
          .select()
          .eq('name', trimmedName)
          .eq('is_active', true)
          .maybeSingle();

      // If no match, try case-insensitive match (handles web app vs app casing)
      if (response == null) {
        print('🔧 FieldOfficer: No exact match, trying case-insensitive...');
        final list = await _client
            .from('field_officers')
            .select()
            .eq('is_active', true)
            .limit(100);
        if (list.isNotEmpty) {
          final lowerInput = trimmedName.toLowerCase();
          for (final row in list) {
            final rowName = row['name']?.toString().trim() ?? '';
            if (rowName.toLowerCase() == lowerInput) {
              response = row;
              print('✅ FieldOfficer: Matched by case-insensitive name');
              break;
            }
          }
        }
      }

      if (response == null) {
        print('❌ FieldOfficer: No officer found with name: "$trimmedName"');
        return null;
      }

      // Update last_login
      try {
        await _client
            .from('field_officers')
            .update({'last_login': DateTime.now().toIso8601String()}).eq(
                'id', response['id']);
      } catch (_) {
        // Non-fatal if update fails (e.g. RLS)
      }

      print('✅ FieldOfficer: Login successful');
      return FieldOfficer.fromJson(response);
    } catch (e) {
      print('❌ FieldOfficer: Login error: $e');
      return null;
    }
  }

  // Get field officer by ID
  static Future<FieldOfficer?> getFieldOfficerById(String officerId) async {
    try {
      final response = await _client
          .from('field_officers')
          .select()
          .eq('id', officerId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return FieldOfficer.fromJson(response);
    } catch (e) {
      print('❌ Error fetching field officer: $e');
      return null;
    }
  }

  // Update field officer location
  static Future<bool> updateFieldOfficerLocation({
    required String officerId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      print('🔧 FieldOfficer: Updating location for officer: $officerId');
      await _client.from('field_officers').update({
        'latitude': latitude,
        'longitude': longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', officerId);

      print('✅ FieldOfficer: Location updated successfully');
      return true;
    } catch (e) {
      print('❌ FieldOfficer: Error updating location: $e');
      return false;
    }
  }

  // Get all jobs assigned to a field officer
  static Future<List<AdminSubmission>> getAssignedJobs(String officerId) async {
    try {
      print('🔧 FieldOfficer: Fetching jobs for officer: $officerId');

      // Try using the view first
      try {
        final response = await _client
            .from('field_officer_jobs')
            .select()
            .eq('assigned_officer_id', officerId)
            .order('submitted_at', ascending: false);

        print(
            '🔧 FieldOfficer: Received ${(response as List).length} assigned jobs');

        final submissions = (response as List)
            .map((json) {
              try {
                return AdminSubmission.fromJson(json);
              } catch (e) {
                print('❌ FieldOfficer: Error parsing submission: $e');
                print('❌ FieldOfficer: JSON: $json');
                return null;
              }
            })
            .whereType<AdminSubmission>()
            .toList();

        print('✅ FieldOfficer: Successfully parsed ${submissions.length} jobs');
        return submissions;
      } catch (viewError) {
        print(
            '⚠️ FieldOfficer: View not available, using direct query: $viewError');
        // Fallback: Query directly from scrap_submissions
        final response = await _client
            .from('scrap_submissions')
            .select('*, users!inner(name, phone_number)')
            .eq('assigned_officer_id', officerId)
            .order('submitted_at', ascending: false);

        return (response as List)
            .map((json) {
              try {
                final userData = json['users'] is List
                    ? (json['users'] as List).first
                    : json['users'];
                return AdminSubmission.fromJson({
                  ...json,
                  'user_name': userData['name'] ?? '',
                  'phone_number':
                      json['phone_number'] ?? userData['phone_number'] ?? '',
                  'message_count': 0,
                });
              } catch (e) {
                print('❌ FieldOfficer: Error parsing fallback: $e');
                return null;
              }
            })
            .whereType<AdminSubmission>()
            .toList();
      }
    } catch (e) {
      print('❌ FieldOfficer: Error fetching assigned jobs: $e');
      rethrow;
    }
  }

  // Get assigned jobs by status
  static Future<List<AdminSubmission>> getAssignedJobsByStatus(
      String officerId, String status) async {
    try {
      final response = await _client
          .from('field_officer_jobs')
          .select()
          .eq('assigned_officer_id', officerId)
          .eq('status', status)
          .order('submitted_at', ascending: false);

      return (response as List)
          .map((json) {
            try {
              return AdminSubmission.fromJson(json);
            } catch (e) {
              print('❌ FieldOfficer: Error parsing submission: $e');
              return null;
            }
          })
          .whereType<AdminSubmission>()
          .toList();
    } catch (e) {
      print('❌ FieldOfficer: Error fetching jobs by status: $e');
      // Fallback to direct query
      try {
        final allJobs = await getAssignedJobs(officerId);
        return allJobs
            .where((j) => j.status.toLowerCase() == status.toLowerCase())
            .toList();
      } catch (e2) {
        return [];
      }
    }
  }

  // Mark job as collected (update status to completed)
  static Future<bool> markJobAsCollected({
    required String submissionId,
    String? notes,
    String? officerId,
    String? adminCollectionImageUrl,
    String? paymentPhoneNumber,
  }) async {
    try {
      print('🔧 FieldOfficer: Marking job as collected: $submissionId');
      final updateData = {
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null && notes.isNotEmpty) {
        updateData['admin_notes'] = notes;
      }

      if (adminCollectionImageUrl != null &&
          adminCollectionImageUrl.isNotEmpty) {
        updateData['admin_collection_image_url'] = adminCollectionImageUrl;
      }

      if (paymentPhoneNumber != null && paymentPhoneNumber.isNotEmpty) {
        updateData['payment_phone_number'] = paymentPhoneNumber;
      }

      await _client
          .from('scrap_submissions')
          .update(updateData)
          .eq('id', submissionId);

      print('✅ FieldOfficer: Job marked as collected');
      return true;
    } catch (e) {
      print('❌ FieldOfficer: Error marking job as collected: $e');
      return false;
    }
  }

  // Mark job as rejected (optionally with image/notes; uses same image column as collection)
  static Future<bool> markJobAsRejected({
    required String submissionId,
    String? notes,
    String? adminCollectionImageUrl,
  }) async {
    try {
      print('🔧 FieldOfficer: Marking job as rejected: $submissionId');
      final updateData = {
        'status': 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null && notes.isNotEmpty) {
        updateData['admin_notes'] = notes;
      }

      if (adminCollectionImageUrl != null &&
          adminCollectionImageUrl.isNotEmpty) {
        updateData['admin_collection_image_url'] = adminCollectionImageUrl;
      }

      await _client
          .from('scrap_submissions')
          .update(updateData)
          .eq('id', submissionId);

      print('✅ FieldOfficer: Job marked as rejected');
      return true;
    } catch (e) {
      print('❌ FieldOfficer: Error marking job as rejected: $e');
      return false;
    }
  }

  // Get field officer statistics
  static Future<Map<String, int>> getFieldOfficerStats(String officerId) async {
    try {
      final allJobs = await getAssignedJobs(officerId);
      return {
        'total': allJobs.length,
        'pending':
            allJobs.where((j) => j.status.toLowerCase() == 'pending').length,
        'approved':
            allJobs.where((j) => j.status.toLowerCase() == 'approved').length,
        'completed':
            allJobs.where((j) => j.status.toLowerCase() == 'completed').length,
        'rejected':
            allJobs.where((j) => j.status.toLowerCase() == 'rejected').length,
        'reviewed':
            allJobs.where((j) => j.status.toLowerCase() == 'reviewed').length,
      };
    } catch (e) {
      print('❌ FieldOfficer: Error getting stats: $e');
      return {
        'total': 0,
        'pending': 0,
        'approved': 0,
        'completed': 0,
        'rejected': 0,
        'reviewed': 0,
      };
    }
  }

  // Search assigned jobs
  static Future<List<AdminSubmission>> searchAssignedJobs(
      String officerId, String query) async {
    try {
      final response = await _client
          .from('field_officer_jobs')
          .select()
          .eq('assigned_officer_id', officerId)
          .or('item_name.ilike.%$query%,user_name.ilike.%$query%,phone_number.ilike.%$query%')
          .order('submitted_at', ascending: false);

      return (response as List)
          .map((json) {
            try {
              return AdminSubmission.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<AdminSubmission>()
          .toList();
    } catch (e) {
      print('❌ FieldOfficer: Error searching jobs: $e');
      // Fallback: search in all assigned jobs
      try {
        final allJobs = await getAssignedJobs(officerId);
        final queryLower = query.toLowerCase();
        return allJobs.where((job) {
          return job.itemName.toLowerCase().contains(queryLower) ||
              job.userName.toLowerCase().contains(queryLower) ||
              job.phoneNumber.contains(query);
        }).toList();
      } catch (e2) {
        return [];
      }
    }
  }

  // ========== OFFICE CHAT (admin ↔ field officer) ==========

  static Future<List<Admin>> getAllAdmins() async {
    try {
      final response = await _client
          .from('admins')
          .select()
          .eq('is_active', true)
          .order('username');
      return (response as List).map((j) => Admin.fromJson(j)).toList();
    } catch (e) {
      print('❌ getAllAdmins: $e');
      return [];
    }
  }

  static Future<List<FieldOfficer>> getAllFieldOfficers() async {
    try {
      final response = await _client
          .from('field_officers')
          .select()
          .eq('is_active', true)
          .order('name');
      return (response as List).map((j) => FieldOfficer.fromJson(j)).toList();
    } catch (e) {
      print('❌ getAllFieldOfficers: $e');
      return [];
    }
  }

  /// Returns conversations for the current user (admin or field officer).
  static Future<List<OfficeConversation>> getOfficeConversations({
    required String myId,
    required String myType,
  }) async {
    try {
      final messages = await _client
          .from('office_messages')
          .select()
          .or('and(sender_id.eq.$myId,sender_type.eq.$myType),and(recipient_id.eq.$myId,recipient_type.eq.$myType)')
          .order('created_at', ascending: false);

      final list = messages as List;
      final seen = <String>{};
      final conversations = <OfficeConversation>[];

      final admins = await getAllAdmins();
      final officers = await getAllFieldOfficers();
      final nameMap = <String, String>{};
      for (final a in admins) {
        nameMap['admin:${a.id}'] = a.username;
      }
      for (final o in officers) {
        nameMap['field_officer:${o.id}'] = o.name;
      }

      for (final m in list) {
        final senderId = m['sender_id']?.toString() ?? '';
        final senderType = m['sender_type']?.toString() ?? '';
        final recipientId = m['recipient_id']?.toString() ?? '';
        final recipientType = m['recipient_type']?.toString() ?? '';
        final otherId = senderId == myId ? recipientId : senderId;
        final otherType = senderId == myId ? recipientType : senderType;
        final key = '$otherType:$otherId';
        if (seen.contains(key)) continue;
        seen.add(key);

        final content = m['content']?.toString();
        final createdAt = m['created_at'] != null
            ? DateTime.parse(m['created_at'].toString())
            : null;
        final isToMe = recipientId == myId && recipientType == myType;
        final unread = isToMe && (m['is_read'] != true);

        final otherName = nameMap[key] ?? (otherType == 'admin' ? 'Admin' : 'Officer');

        conversations.add(OfficeConversation(
          otherId: otherId,
          otherType: otherType,
          otherName: otherName,
          lastContent: content,
          lastAt: createdAt,
          unreadCount: unread ? 1 : 0,
        ));
      }

      return conversations;
    } catch (e) {
      print('❌ getOfficeConversations: $e');
      return [];
    }
  }

  static Future<List<OfficeMessage>> getOfficeMessages({
    required String myId,
    required String myType,
    required String otherId,
    required String otherType,
  }) async {
    try {
      final response = await _client
          .from('office_messages')
          .select()
          .or('sender_id.eq.$myId,recipient_id.eq.$myId')
          .or('sender_id.eq.$otherId,recipient_id.eq.$otherId')
          .order('created_at', ascending: true);

      final list = response as List;
      final filtered = list.where((m) {
        final sId = m['sender_id']?.toString();
        final sType = m['sender_type']?.toString();
        final rId = m['recipient_id']?.toString();
        final rType = m['recipient_type']?.toString();
        final fromMeToOther = sId == myId && sType == myType && rId == otherId && rType == otherType;
        final fromOtherToMe = sId == otherId && sType == otherType && rId == myId && rType == myType;
        return fromMeToOther || fromOtherToMe;
      }).toList();

      return filtered
          .map((j) => OfficeMessage.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    } catch (e) {
      print('❌ getOfficeMessages: $e');
      return [];
    }
  }

  static Future<String?> sendOfficeMessage({
    required String senderId,
    required String senderType,
    required String recipientId,
    required String recipientType,
    required String content,
    String? imageUrl,
  }) async {
    try {
      await _client.from('office_messages').insert({
        'id': _uuid.v4(),
        'sender_id': senderId,
        'sender_type': senderType,
        'recipient_id': recipientId,
        'recipient_type': recipientType,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      print('❌ sendOfficeMessage: $e');
      return e.toString();
    }
  }
}
