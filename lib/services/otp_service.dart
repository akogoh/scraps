import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../http_client_stub.dart'
    if (dart.library.io) '../http_client_io.dart';

class OtpService {
  // mNotify API Configuration
  static const String _apiKey = 'sishUWFdEEGAOSSOwgjAdGi26';
  static const String _apiUrl = 'https://api.mnotify.com/api/sms/quick';

  // Special test account for QA / Google Play review
  // When this phone + OTP are used, we bypass the SMS API and accept the login.
  static const String _testPhoneLocal = '0240000000';
  static const String _testOtp = '123456';

  static http.Client _createClient() {
    return createHttpClient();
  }
  static const String _senderId =
      'Greenhaul'; // Max 11 characters - Must match exactly as registered in mNotify
  static const String _otpKeyPrefix = 'otp_';
  static const String _otpTimestampPrefix = 'otp_timestamp_';
  static const int _otpExpiryMinutes = 10; // OTP expires in 10 minutes

  /// Generate a 6-digit OTP
  static String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Store OTP temporarily with phone number
  static Future<void> _storeOtp(String phoneNumber, String otp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_otpKeyPrefix$phoneNumber', otp);
    await prefs.setInt('$_otpTimestampPrefix$phoneNumber',
        DateTime.now().millisecondsSinceEpoch);
  }

  /// Get stored OTP for phone number
  static Future<String?> _getStoredOtp(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_otpKeyPrefix$phoneNumber');
  }

  /// Check if OTP is expired
  static Future<bool> _isOtpExpired(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('$_otpTimestampPrefix$phoneNumber');
    if (timestamp == null) return true;

    final otpTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(otpTime);

    return difference.inMinutes > _otpExpiryMinutes;
  }

  /// Clear OTP after successful verification
  static Future<void> _clearOtp(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_otpKeyPrefix$phoneNumber');
    await prefs.remove('$_otpTimestampPrefix$phoneNumber');
  }

  /// Format phone number for mNotify API (use local format as per documentation)
  /// Documentation shows examples like "0241234567" (10 digits starting with 0)
  static String _formatPhoneNumber(String phoneNumber) {
    // Remove any spaces or dashes
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s-]'), '');

    // Ensure it's 10 digits starting with 0 (local Ghana format)
    // If it starts with 233, remove it to get local format
    if (cleaned.startsWith('233') && cleaned.length == 13) {
      cleaned = '0${cleaned.substring(3)}';
    }
    // If it doesn't start with 0, add it (assuming it's a 9-digit number)
    else if (!cleaned.startsWith('0') && cleaned.length == 9) {
      cleaned = '0$cleaned';
    }

    // Validate: should be exactly 10 digits starting with 0
    if (cleaned.length != 10 || !cleaned.startsWith('0')) {
      print(
          '⚠️ Phone number format may be incorrect: $cleaned (expected: 10 digits starting with 0)');
    }

    return cleaned;
  }

  /// Send OTP to phone number via mNotify API
  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      // Format phone number (ensure it's in local format: 10 digits starting with 0)
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      // Validate phone number format
      if (formattedPhone.length != 10 || !formattedPhone.startsWith('0')) {
        return {
          'success': false,
          'message':
              'Invalid phone number format. Please enter a 10-digit number starting with 0 (e.g., 0241234567)',
        };
      }

      // Special path for test phone: don't call SMS API, use fixed OTP.
      if (formattedPhone == _testPhoneLocal) {
        await _storeOtp(phoneNumber, _testOtp);
        return {
          'success': true,
          'message':
              'Test OTP sent. Use code $_testOtp to log in with the test account.',
          'otp': _testOtp,
          'campaign_id': null,
          'total_sent': 0,
          'total_rejected': 0,
          'numbers_sent': [formattedPhone],
        };
      }

      // Generate OTP for normal users
      final otp = _generateOtp();

      // Store OTP temporarily
      await _storeOtp(phoneNumber, otp);

      // Prepare message (keep it concise for better delivery)
      final message =
          'Your verification code is: $otp. Valid for $_otpExpiryMinutes minutes.';

      // Prepare request payload according to mNotify API documentation
      final payload = {
        'recipient': [formattedPhone], // Array of phone numbers in local format
        'sender': _senderId, // Must be registered and approved
        'message': message,
        'is_schedule': false,
        'schedule_date': '',
        'sms_type':
            'otp', // Required: Marks this as OTP SMS (charges 0.035 per campaign)
      };

      // Make API request
      final url = Uri.parse('$_apiUrl?key=$_apiKey');

      // Log request for debugging (remove sensitive data in production)
      print('📤 Sending OTP request to: $_apiUrl');
      print('📱 Phone: $formattedPhone (original: $phoneNumber)');
      print(
          '📝 Payload: ${jsonEncode(payload).replaceAll(otp, '******')}'); // Hide OTP in logs

      final client = _createClient();
      try {
        final response = await client.post(
          url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body}');

        // Parse response body
        Map<String, dynamic>? responseData;
        try {
          responseData = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          print('⚠️ Could not parse response body: ${response.body}');
        }

        if (response.statusCode == 200) {
          if (responseData != null && responseData['status'] == 'success') {
            // Extract campaign ID and delivery info from response
            final summary = responseData['summary'];
          final campaignId = summary?['_id'];
          final totalSent = summary?['total_sent'] ?? 0;
          final creditLeft = summary?['credit_left'];

          // Extract additional info
          final totalRejected = summary?['total_rejected'] ?? 0;
          final numbersSent = summary?['numbers_sent'] as List<dynamic>?;

          print('✅ OTP sent successfully!');
          print('📋 Campaign ID: $campaignId');
          print('📊 Total sent: $totalSent');
          print('❌ Total rejected: $totalRejected');
          print('📱 Numbers sent: $numbersSent');
          print('💰 Credits left: $creditLeft');

          // Check if any numbers were rejected
          if (totalRejected > 0) {
            print(
                '⚠️ WARNING: Some numbers were rejected. Check phone number format.');
          }

          // Note: Status will be "SUBMITTED" initially, delivery can take 1-5 minutes
          return {
            'success': true,
            'message':
                'OTP sent successfully. Please check your phone (delivery may take 1-5 minutes). If you don\'t receive it, check your spam folder or try again.',
            'otp':
                otp, // Return OTP for testing purposes (remove in production)
            'campaign_id': campaignId,
            'total_sent': totalSent,
            'total_rejected': totalRejected,
            'numbers_sent': numbersSent,
          };
        } else {
          // Check for specific error messages from API
          final apiMessage = responseData?['message'] ?? 'Failed to send OTP';
          final apiCode = responseData?['code'];

          print('❌ API returned error: $apiMessage (code: $apiCode)');

          return {
            'success': false,
            'message': apiMessage,
            'code': apiCode,
          };
        }
      } else {
        // Handle specific error codes
        String errorMessage;
        switch (response.statusCode) {
          case 401:
            errorMessage = 'Unauthorized. Please check your API key.';
            break;
          case 402:
            errorMessage =
                'Insufficient credits. Please top up your mNotify account.';
            break;
          case 400:
            errorMessage = responseData?['message'] ??
                'Invalid request. Please check your phone number format.';
            break;
          case 500:
            errorMessage = 'Server error. Please try again later.';
            break;
          default:
            errorMessage = responseData?['message'] ??
                'Failed to send OTP. Status code: ${response.statusCode}';
        }

        print('❌ mNotify API Error (${response.statusCode}): ${response.body}');

          return {
            'success': false,
            'message': errorMessage,
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error sending OTP: $e');
      return {
        'success': false,
        'message': 'Error sending OTP: ${e.toString()}',
      };
    }
  }

  /// Verify OTP entered by user
  static Future<Map<String, dynamic>> verifyOtp(
      String phoneNumber, String enteredOtp) async {
    try {
      final trimmedOtp = enteredOtp.trim();
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      // Special case: test phone + fixed OTP, bypass stored values and API.
      if (formattedPhone == _testPhoneLocal && trimmedOtp == _testOtp) {
        await _clearOtp(phoneNumber);
        return {
          'success': true,
          'message': 'OTP verified successfully (test account).',
        };
      }

      // Get stored OTP
      final storedOtp = await _getStoredOtp(phoneNumber);

      if (storedOtp == null) {
        return {
          'success': false,
          'message': 'No OTP found. Please request a new OTP.',
        };
      }

      // Check if OTP is expired
      if (await _isOtpExpired(phoneNumber)) {
        await _clearOtp(phoneNumber);
        return {
          'success': false,
          'message': 'OTP has expired. Please request a new OTP.',
        };
      }

      // Verify OTP
      if (storedOtp == trimmedOtp) {
        // Clear OTP after successful verification
        await _clearOtp(phoneNumber);
        return {
          'success': true,
          'message': 'OTP verified successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid OTP. Please try again.',
        };
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Error verifying OTP: ${e.toString()}',
      };
    }
  }

  /// Resend OTP
  static Future<Map<String, dynamic>> resendOtp(String phoneNumber) async {
    // Clear old OTP first
    await _clearOtp(phoneNumber);
    // Send new OTP
    return await sendOtp(phoneNumber);
  }

  /// Check Sender ID status
  /// This helps verify if the sender ID is registered and approved
  static Future<Map<String, dynamic>> checkSenderIdStatus() async {
    try {
      final url =
          Uri.parse('https://api.mnotify.com/api/senderid/status?key=$_apiKey');
      final client = _createClient();
      try {
        final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sender_name': _senderId,
        }),
      );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          final summary = responseData['summary'];
          final status = summary?['status'];

          print('📋 Sender ID Status: $status');

          return {
            'success': true,
            'status': status,
            'sender_name': _senderId,
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to check sender ID status',
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error checking sender ID status: $e');
      return {
        'success': false,
        'message': 'Error checking sender ID: ${e.toString()}',
      };
    }
  }

  /// Check SMS balance
  static Future<Map<String, dynamic>> checkBalance() async {
    try {
      final url =
          Uri.parse('https://api.mnotify.com/api/balance/sms?key=$_apiKey');
      final client = _createClient();
      try {
        final response = await client.get(url);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          final balance = responseData['balance'] ?? 0;
          final bonus = responseData['bonus'] ?? 0;

          print('💰 SMS Balance: $balance (Bonus: $bonus)');

          return {
            'success': true,
            'balance': balance,
            'bonus': bonus,
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to check balance',
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error checking balance: $e');
      return {
        'success': false,
        'message': 'Error checking balance: ${e.toString()}',
      };
    }
  }

  /// Check delivery status of a sent SMS using campaign ID
  static Future<Map<String, dynamic>> checkDeliveryStatus(
      String campaignId) async {
    try {
      final url = Uri.parse(
          'https://api.mnotify.com/api/campaign/$campaignId?key=$_apiKey');
      final client = _createClient();
      try {
        final response = await client.get(url);

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          final report = responseData['report'] as List<dynamic>?;

          if (report != null && report.isNotEmpty) {
            final firstReport = report[0] as Map<String, dynamic>;
            final status = firstReport['status'];
            final recipient = firstReport['recipient'];

            print('📊 Delivery Status for $campaignId:');
            print('   Recipient: $recipient');
            print('   Status: $status');

            return {
              'success': true,
              'status': status,
              'recipient': recipient,
              'report': report,
            };
          }

          return {
            'success': true,
            'status': 'No delivery report yet',
          };
        } else {
          return {
            'success': false,
            'message': 'Failed to check delivery status',
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error checking delivery status: $e');
      return {
        'success': false,
        'message': 'Error checking delivery status: ${e.toString()}',
      };
    }
  }
}
