import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analytics_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;
  String _selectedTab = 'overview';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await AnalyticsService.getDashboardAnalytics();
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading analytics: ${e.toString()}');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export_users') {
                _exportUsersData();
              } else if (value == 'export_submissions') {
                _exportSubmissionsData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_users',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Users CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_submissions',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Submissions CSV'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null
              ? const Center(child: Text('No data available'))
              : Column(
                  children: [
                    // Tab Bar
                    Container(
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          _buildTabButton('overview', 'Overview'),
                          _buildTabButton('users', 'Users'),
                          _buildTabButton('submissions', 'Submissions'),
                          _buildTabButton('regions', 'Regions'),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabButton(String tab, String label) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2E7D32) : Colors.grey[300]!,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 'overview':
        return _buildOverviewTab();
      case 'users':
        return _buildUsersTab();
      case 'submissions':
        return _buildSubmissionsTab();
      case 'regions':
        return _buildRegionsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final userData =
        Map<String, dynamic>.from(_analyticsData!['userDemographics']);
    final submissionData =
        Map<String, dynamic>.from(_analyticsData!['submissionAnalytics']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics
          const Text(
            'Key Metrics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Users',
                  userData['totalUsers'].toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Total Submissions',
                  submissionData['totalSubmissions'].toString(),
                  Icons.assignment,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Recent Users (30d)',
                  userData['recentRegistrations'].toString(),
                  Icons.person_add,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Recent Submissions (30d)',
                  submissionData['recentSubmissions'].toString(),
                  Icons.add_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Price Analytics
          const Text(
            'Financial Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildPriceAnalyticsCard(submissionData['priceAnalytics']),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final userData =
        Map<String, dynamic>.from(_analyticsData!['userDemographics']);
    final genderData =
        Map<String, dynamic>.from(userData['genderDistribution']);
    final ageData = Map<String, dynamic>.from(userData['ageDistribution']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGenderChart(genderData),
          const SizedBox(height: 24),
          _buildAgeChart(ageData),
        ],
      ),
    );
  }

  Widget _buildSubmissionsTab() {
    final submissionData =
        Map<String, dynamic>.from(_analyticsData!['submissionAnalytics']);
    final statusData =
        Map<String, dynamic>.from(submissionData['statusDistribution']);
    final sellingData =
        Map<String, dynamic>.from(submissionData['sellingVsDonating']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusChart(statusData),
          const SizedBox(height: 24),
          _buildSellingChart(sellingData),
        ],
      ),
    );
  }

  Widget _buildRegionsTab() {
    final userData =
        Map<String, dynamic>.from(_analyticsData!['userDemographics']);
    final submissionData =
        Map<String, dynamic>.from(_analyticsData!['submissionAnalytics']);
    final userRegions =
        Map<String, dynamic>.from(userData['regionalDistribution']);
    final submissionRegions =
        Map<String, dynamic>.from(submissionData['regionalSubmissions']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Distribution by Region',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRegionChart(userRegions),
          const SizedBox(height: 24),
          const Text(
            'Submissions by Region',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRegionChart(submissionRegions),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceAnalyticsCard(Map<String, dynamic> priceData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPriceMetric('Total Value',
                      'GH₵${priceData['totalValue'].toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildPriceMetric('Average Price',
                      'GH₵${priceData['averagePrice'].toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPriceMetric('Max Price',
                      'GH₵${priceData['maxPrice'].toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _buildPriceMetric('Min Price',
                      'GH₵${priceData['minPrice'].toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPriceMetric('Total Transactions',
                priceData['totalTransactions'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGenderChart(Map<String, dynamic> genderData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gender Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...genderData.entries.map((entry) => _buildChartBar(
                  entry.key.toUpperCase(),
                  entry.value,
                  _getGenderColor(entry.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeChart(Map<String, dynamic> ageData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Age Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...ageData.entries.map((entry) => _buildChartBar(
                  entry.key,
                  entry.value,
                  _getAgeColor(entry.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChart(Map<String, dynamic> statusData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submission Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...statusData.entries.map((entry) => _buildChartBar(
                  entry.key.toUpperCase(),
                  entry.value,
                  _getStatusColor(entry.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSellingChart(Map<String, dynamic> sellingData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selling vs Donating',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...sellingData.entries.map((entry) => _buildChartBar(
                  entry.key.toUpperCase(),
                  entry.value,
                  entry.key == 'selling' ? Colors.green : Colors.blue,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionChart(Map<String, dynamic> regionData) {
    if (regionData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No regional data available'),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...regionData.entries.map((entry) => _buildChartBar(
                  entry.key,
                  entry.value,
                  _getRegionColor(entry.key),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBar(String label, int value, Color color) {
    final total = _getTotalForChart();
    final percentage = total > 0 ? (value / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$value (${percentage.toStringAsFixed(1)}%)'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  int _getTotalForChart() {
    switch (_selectedTab) {
      case 'users':
        final genderData = Map<String, dynamic>.from(
            _analyticsData!['userDemographics']['genderDistribution']);
        return genderData.values.fold(0, (sum, value) => sum + (value as int));
      case 'submissions':
        final statusData = Map<String, dynamic>.from(
            _analyticsData!['submissionAnalytics']['statusDistribution']);
        return statusData.values.fold(0, (sum, value) => sum + (value as int));
      case 'regions':
        final regionData = Map<String, dynamic>.from(
            _analyticsData!['userDemographics']['regionalDistribution']);
        return regionData.values.fold(0, (sum, value) => sum + (value as int));
      default:
        return 0;
    }
  }

  Color _getGenderColor(String gender) {
    switch (gender.toLowerCase()) {
      case 'male':
        return Colors.blue;
      case 'female':
        return Colors.pink;
      case 'other':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getAgeColor(String ageGroup) {
    switch (ageGroup) {
      case '18-25':
        return Colors.green;
      case '26-40':
        return Colors.blue;
      case '41-60':
        return Colors.orange;
      case '60+':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getRegionColor(String region) {
    // Generate consistent colors for regions
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
    ];
    final index = region.hashCode % colors.length;
    return colors[index];
  }

  Future<void> _exportUsersData() async {
    try {
      final csvData = await AnalyticsService.exportUsersToCSV();
      await Clipboard.setData(ClipboardData(text: csvData));
      _showSnackBar('Users data copied to clipboard', isError: false);
    } catch (e) {
      _showSnackBar('Error exporting users data: ${e.toString()}');
    }
  }

  Future<void> _exportSubmissionsData() async {
    try {
      final csvData = await AnalyticsService.exportSubmissionsToCSV();
      await Clipboard.setData(ClipboardData(text: csvData));
      _showSnackBar('Submissions data copied to clipboard', isError: false);
    } catch (e) {
      _showSnackBar('Error exporting submissions data: ${e.toString()}');
    }
  }
}
