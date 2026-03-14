// Test Admin Messages - Run this to test admin message functionality
import 'package:supabase_flutter/supabase_flutter.dart';

void testAdminMessages() async {
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL',
      anonKey: 'YOUR_SUPABASE_ANON_KEY',
    );

    final client = Supabase.instance.client;

    // Test 1: Check if messages table exists
    print('🔍 Testing messages table...');
    final messagesResponse = await client.from('messages').select('*').limit(1);
    print('✅ Messages table accessible');

    // Test 2: Check if admins table exists
    print('🔍 Testing admins table...');
    final adminsResponse = await client.from('admins').select('*').limit(1);
    print('✅ Admins table accessible');

    // Test 3: Try to insert a test message
    print('🔍 Testing message insertion...');
    final testMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'submission_id': 'test-submission-id',
      'sender_id': 'admin-001',
      'content': 'Test admin message',
      'is_admin_message': true,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    await client.from('messages').insert(testMessage);
    print('✅ Test message inserted successfully');

    // Test 4: Clean up test message
    await client
        .from('messages')
        .delete()
        .eq('id', testMessage['id'] as Object);
    print('✅ Test message cleaned up');

    print('🎉 All admin message tests passed!');
  } catch (e) {
    print('❌ Admin message test failed: $e');
  }
}
