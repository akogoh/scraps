import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectionTest {
  static final SupabaseClient _client = Supabase.instance.client;

  // Test basic connection
  static Future<bool> testConnection() async {
    try {
      await _client.from('users').select('count').limit(1);
      print('✅ Supabase connection successful');
      return true;
    } catch (e) {
      print('❌ Supabase connection failed: $e');
      return false;
    }
  }

  // Test inserting a user
  static Future<bool> testInsertUser() async {
    try {
      final testUser = {
        'id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Test User',
        'phone_number': '9999999999',
      };

      await _client.from('users').insert(testUser);
      print('✅ User insertion successful');
      return true;
    } catch (e) {
      print('❌ User insertion failed: $e');
      return false;
    }
  }

  // Test querying users
  static Future<bool> testQueryUsers() async {
    try {
      final response = await _client.from('users').select().limit(5);
      print('✅ User query successful: ${response.length} users found');
      return true;
    } catch (e) {
      print('❌ User query failed: $e');
      return false;
    }
  }

  // Run all tests
  static Future<void> runAllTests() async {
    print('🧪 Running Supabase connection tests...\n');

    final connectionTest = await testConnection();
    if (!connectionTest) return;

    final insertTest = await testInsertUser();
    if (!insertTest) return;

    final queryTest = await testQueryUsers();
    if (!queryTest) return;

    print('\n🎉 All tests passed! Your Supabase setup is working correctly.');
  }
}
