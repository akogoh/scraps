import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _phoneKey = 'user_phone';
  static const String _nameKey = 'user_name';
  static const String _userIdKey = 'user_id';

  // Save user session data
  static Future<void> saveUserSession({
    required String phoneNumber,
    required String name,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phoneNumber);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_userIdKey, userId);
  }

  // Get current user phone number
  static Future<String?> getCurrentUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  // Get current user name
  static Future<String?> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Check if user is logged in
  static Future<bool> isUserLoggedIn() async {
    final phone = await getCurrentUserPhone();
    return phone != null && phone.isNotEmpty;
  }

  // Clear user session (logout)
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_phoneKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_userIdKey);
  }

  // Get all user session data
  static Future<Map<String, String?>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'phone': prefs.getString(_phoneKey),
      'name': prefs.getString(_nameKey),
      'userId': prefs.getString(_userIdKey),
    };
  }
}
