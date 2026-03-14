import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get user demographics data
  static Future<Map<String, dynamic>> getUserDemographics() async {
    try {
      final response = await _supabase
          .from('users')
          .select(
              'id, name, phone_number, created_at, gender, age_group, region')
          .order('created_at', ascending: false);

      final users = response as List<dynamic>;

      // Calculate demographics
      int totalUsers = users.length;
      int maleUsers = users.where((user) => user['gender'] == 'male').length;
      int femaleUsers =
          users.where((user) => user['gender'] == 'female').length;
      int otherGender = users.where((user) => user['gender'] == 'other').length;
      int unknownGender = users
          .where((user) => user['gender'] == null || user['gender'] == '')
          .length;

      // Age groups
      int youngAdults =
          users.where((user) => user['age_group'] == '18-25').length;
      int adults = users.where((user) => user['age_group'] == '26-40').length;
      int middleAged =
          users.where((user) => user['age_group'] == '41-60').length;
      int seniors = users.where((user) => user['age_group'] == '60+').length;

      // Regional distribution
      Map<String, int> regionalDistribution = {};
      for (var user in users) {
        String region = user['region'] ?? 'Unknown';
        regionalDistribution[region] = (regionalDistribution[region] ?? 0) + 1;
      }

      // Recent registrations (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      int recentRegistrations = users.where((user) {
        final createdAt = DateTime.parse(user['created_at']);
        return createdAt.isAfter(thirtyDaysAgo);
      }).length;

      return {
        'totalUsers': totalUsers,
        'genderDistribution': {
          'male': maleUsers,
          'female': femaleUsers,
          'other': otherGender,
          'unknown': unknownGender,
        },
        'ageDistribution': {
          '18-25': youngAdults,
          '26-40': adults,
          '41-60': middleAged,
          '60+': seniors,
        },
        'regionalDistribution': regionalDistribution,
        'recentRegistrations': recentRegistrations,
        'rawData': users,
      };
    } catch (e) {
      print('Error fetching user demographics: $e');
      return {
        'totalUsers': 0,
        'genderDistribution': {
          'male': 0,
          'female': 0,
          'other': 0,
          'unknown': 0
        },
        'ageDistribution': {'18-25': 0, '26-40': 0, '41-60': 0, '60+': 0},
        'regionalDistribution': {},
        'recentRegistrations': 0,
        'rawData': [],
      };
    }
  }

  // Get submission analytics
  static Future<Map<String, dynamic>> getSubmissionAnalytics() async {
    try {
      final response = await _supabase
          .from('scrap_submissions')
          .select(
              'id, item_name, status, created_at, latitude, longitude, address, price, is_selling, user_id')
          .order('created_at', ascending: false);

      final submissions = response as List<dynamic>;

      // Calculate submission metrics
      int totalSubmissions = submissions.length;
      int pendingSubmissions =
          submissions.where((s) => s['status'] == 'pending').length;
      int approvedSubmissions =
          submissions.where((s) => s['status'] == 'approved').length;
      int rejectedSubmissions =
          submissions.where((s) => s['status'] == 'rejected').length;
      int reviewedSubmissions =
          submissions.where((s) => s['status'] == 'reviewed').length;

      // Price analytics
      List<double> prices = submissions
          .where((s) => s['price'] != null && s['price'] > 0)
          .map((s) => (s['price'] as num).toDouble())
          .toList();

      double totalValue = prices.fold(0, (sum, price) => sum + price);
      double averagePrice = prices.isNotEmpty ? totalValue / prices.length : 0;
      double maxPrice =
          prices.isNotEmpty ? prices.reduce((a, b) => a > b ? a : b) : 0;
      double minPrice =
          prices.isNotEmpty ? prices.reduce((a, b) => a < b ? a : b) : 0;

      // Selling vs Donating
      int sellingSubmissions =
          submissions.where((s) => s['is_selling'] == true).length;
      int donatingSubmissions =
          submissions.where((s) => s['is_selling'] == false).length;

      // Recent submissions (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      int recentSubmissions = submissions.where((s) {
        final createdAt = DateTime.parse(s['created_at']);
        return createdAt.isAfter(thirtyDaysAgo);
      }).length;

      // Regional submission distribution
      Map<String, int> regionalSubmissions = {};
      for (var submission in submissions) {
        String region = _extractRegionFromAddress(submission['address'] ?? '');
        regionalSubmissions[region] = (regionalSubmissions[region] ?? 0) + 1;
      }

      return {
        'totalSubmissions': totalSubmissions,
        'statusDistribution': {
          'pending': pendingSubmissions,
          'reviewed': reviewedSubmissions,
          'approved': approvedSubmissions,
          'rejected': rejectedSubmissions,
        },
        'priceAnalytics': {
          'totalValue': totalValue,
          'averagePrice': averagePrice,
          'maxPrice': maxPrice,
          'minPrice': minPrice,
          'totalTransactions': prices.length,
        },
        'sellingVsDonating': {
          'selling': sellingSubmissions,
          'donating': donatingSubmissions,
        },
        'recentSubmissions': recentSubmissions,
        'regionalSubmissions': regionalSubmissions,
        'rawData': submissions,
      };
    } catch (e) {
      print('Error fetching submission analytics: $e');
      return {
        'totalSubmissions': 0,
        'statusDistribution': {
          'pending': 0,
          'reviewed': 0,
          'approved': 0,
          'rejected': 0
        },
        'priceAnalytics': {
          'totalValue': 0,
          'averagePrice': 0,
          'maxPrice': 0,
          'minPrice': 0,
          'totalTransactions': 0
        },
        'sellingVsDonating': {'selling': 0, 'donating': 0},
        'recentSubmissions': 0,
        'regionalSubmissions': {},
        'rawData': [],
      };
    }
  }

  // Get combined analytics dashboard data
  static Future<Map<String, dynamic>> getDashboardAnalytics() async {
    try {
      final userDemographics = await getUserDemographics();
      final submissionAnalytics = await getSubmissionAnalytics();

      return {
        'userDemographics': userDemographics,
        'submissionAnalytics': submissionAnalytics,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error fetching dashboard analytics: $e');
      return {
        'userDemographics': {},
        'submissionAnalytics': {},
        'generatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  // Export data to CSV format
  static Future<String> exportUsersToCSV() async {
    try {
      final demographics = await getUserDemographics();
      final users = demographics['rawData'] as List<dynamic>;

      String csv = 'ID,Name,Phone,Gender,Age Group,Region,Created At\n';
      for (var user in users) {
        csv +=
            '${user['id']},${user['name']},${user['phone_number']},${user['gender'] ?? 'Unknown'},${user['age_group'] ?? 'Unknown'},${user['region'] ?? 'Unknown'},${user['created_at']}\n';
      }

      return csv;
    } catch (e) {
      print('Error exporting users to CSV: $e');
      return '';
    }
  }

  static Future<String> exportSubmissionsToCSV() async {
    try {
      final analytics = await getSubmissionAnalytics();
      final submissions = analytics['rawData'] as List<dynamic>;

      String csv =
          'ID,Item Name,Status,Price,Is Selling,Address,User ID,Created At\n';
      for (var submission in submissions) {
        csv +=
            '${submission['id']},${submission['item_name']},${submission['status']},${submission['price']},${submission['is_selling']},${submission['address'] ?? 'N/A'},${submission['user_id']},${submission['created_at']}\n';
      }

      return csv;
    } catch (e) {
      print('Error exporting submissions to CSV: $e');
      return '';
    }
  }

  // Helper method to extract region from address
  static String _extractRegionFromAddress(String address) {
    if (address.isEmpty) return 'Unknown';

    // Simple region extraction based on common Ghana regions
    final addressLower = address.toLowerCase();
    if (addressLower.contains('accra') ||
        addressLower.contains('greater accra')) {
      return 'Greater Accra';
    }
    if (addressLower.contains('kumasi') || addressLower.contains('ashanti')) {
      return 'Ashanti';
    }
    if (addressLower.contains('tema')) return 'Greater Accra';
    if (addressLower.contains('tamale') || addressLower.contains('northern')) {
      return 'Northern';
    }
    if (addressLower.contains('takoradi') || addressLower.contains('western')) {
      return 'Western';
    }
    if (addressLower.contains('cape coast') ||
        addressLower.contains('central')) {
      return 'Central';
    }
    if (addressLower.contains('koforidua') ||
        addressLower.contains('eastern')) {
      return 'Eastern';
    }
    if (addressLower.contains('ho') || addressLower.contains('volta')) {
      return 'Volta';
    }
    if (addressLower.contains('bolgatanga') ||
        addressLower.contains('upper east')) {
      return 'Upper East';
    }
    if (addressLower.contains('wa') || addressLower.contains('upper west')) {
      return 'Upper West';
    }
    if (addressLower.contains('sunyani') || addressLower.contains('bono')) {
      return 'Bono';
    }
    if (addressLower.contains('techiman') ||
        addressLower.contains('bono east')) {
      return 'Bono East';
    }
    if (addressLower.contains('kintampo') || addressLower.contains('ahafo')) {
      return 'Ahafo';
    }
    if (addressLower.contains('goaso') ||
        addressLower.contains('western north')) {
      return 'Western North';
    }
    if (addressLower.contains('damongo') || addressLower.contains('savannah')) {
      return 'Savannah';
    }
    if (addressLower.contains('bolga') || addressLower.contains('north east')) {
      return 'North East';
    }
    if (addressLower.contains('ho') || addressLower.contains('oti')) {
      return 'Oti';
    }

    return 'Other';
  }
}
