import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGreen, AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GreenHaul Solutions Ltd.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'We\'re here to help you with all your scrap management needs',
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQ Section
            const Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            _buildFAQItem(
              question: 'How do I submit a scrap collection request?',
              answer:
                  'Simply go to the "Submit Scrap" tab, fill in the details about your scrap items, add photos/videos, set your location, and submit. We\'ll review and get back to you with a quote.',
            ),

            _buildFAQItem(
              question: 'What types of scrap materials do you accept?',
              answer:
                  'We accept all types of metal scraps including aluminum cans, copper, steel, old appliances, vehicles, electronic waste, and other valuable metals.',
            ),

            _buildFAQItem(
              question: 'How do you determine the price for my scrap?',
              answer:
                  'Our pricing is based on current market rates, the type and quantity of materials, and their condition. We provide transparent, upfront pricing with no hidden fees.',
            ),

            _buildFAQItem(
              question: 'Do you provide home pickup services?',
              answer:
                  'Yes! We offer convenient home pickup services. Simply gather your scrap materials, take photos, and we\'ll come to your location to collect and pay you on the spot.',
            ),

            _buildFAQItem(
              question: 'How long does it take to process my submission?',
              answer:
                  'We typically review submissions within 24 hours and will contact you with a quote. Collection can be scheduled at your convenience.',
            ),

            _buildFAQItem(
              question: 'What if I\'m not satisfied with the price offered?',
              answer:
                  'You can always negotiate or decline our offer. We believe in fair pricing and transparent communication. Feel free to discuss your expectations with our team.',
            ),

            const SizedBox(height: 24),

            // Contact Support Section
            const Text(
              'Contact Support',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  _buildContactItem(
                    icon: Icons.phone,
                    title: 'Call Us',
                    subtitle: 'Speak directly with our team',
                    value: '0249211930 / 0201032117 / 0303981066',
                    onTap: () => _makePhoneCall('0249211930'),
                  ),
                  const Divider(),
                  _buildContactItem(
                    icon: Icons.email,
                    title: 'Email Support',
                    subtitle: 'Send us your questions',
                    value: 'info@greenhaulsolution.com',
                    onTap: () => _sendEmail('info@greenhaulsolution.com'),
                  ),
                  const Divider(),
                  _buildContactItem(
                    icon: Icons.location_on,
                    title: 'Visit Our Office',
                    subtitle: 'Come see us in person',
                    value: 'GP 1837, Accra Central',
                    onTap: () => _openMaps(),
                  ),
                  const Divider(),
                  _buildContactItem(
                    icon: Icons.language,
                    title: 'Website',
                    subtitle: 'Learn more about our services',
                    value: 'www.greenhaulsolution.com',
                    onTap: () =>
                        _openWebsite('https://www.greenhaulsolution.com'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Business Hours
            const Text(
              'Business Hours',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  _buildBusinessHourItem(
                      day: 'Monday - Friday', hours: '8:00 AM - 6:00 PM'),
                  _buildBusinessHourItem(
                      day: 'Saturday', hours: '9:00 AM - 4:00 PM'),
                  _buildBusinessHourItem(day: 'Sunday', hours: 'Closed'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Emergency Contact
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentOrange, AppColors.accentOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentOrange.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emergency,
                    color: AppColors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Emergency Collection',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Need immediate collection? Call our emergency line',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _makePhoneCall('0249211930'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.accentOrange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Call Emergency Line',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: 0.2,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textDark,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Try multiple phone URI formats
      final List<Uri> phoneUris = [
        Uri(scheme: 'tel', path: cleanNumber),
        Uri.parse('tel:$cleanNumber'),
      ];

      bool launched = false;
      for (var uri in phoneUris) {
        try {
          await launchUrl(uri);
          launched = true;
          break;
        } catch (e) {
          // Try next format
          continue;
        }
      }

      if (!launched) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open phone dialer. Please dial $phoneNumber manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error making phone call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openMaps() async {
    try {
      final address = 'GP 1837, Accra Central';
      final encodedAddress = Uri.encodeComponent(address);

      // Try multiple map URL formats
      final List<Uri> mapUris = [
        Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
        Uri.parse('https://maps.google.com/?q=$encodedAddress'),
        Uri.parse('geo:0,0?q=$encodedAddress'),
        Uri.parse('https://www.google.com/maps?q=$encodedAddress'),
      ];

      bool launched = false;
      for (var uri in mapUris) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          continue; // Try next format
        }
      }

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open maps. Please install Google Maps or search for "$address" manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error opening maps: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendEmail(String email) async {
    try {
      final subject = 'GreenHaul App Support Request';
      final encodedSubject = Uri.encodeComponent(subject);

      // Try multiple email URI formats
      final List<Uri> emailUris = [
        Uri(
          scheme: 'mailto',
          path: email,
          query: 'subject=$encodedSubject',
        ),
        Uri.parse('mailto:$email?subject=$encodedSubject'),
      ];

      bool launched = false;
      for (var uri in emailUris) {
        try {
          await launchUrl(uri);
          launched = true;
          break;
        } catch (e) {
          continue; // Try next format
        }
      }

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not open email app. Please send an email to $email manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error sending email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openWebsite(String url) async {
    try {
      // Ensure URL has proper scheme
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }

      final Uri websiteUri = Uri.parse(formattedUrl);

      // Try launching directly
      try {
        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        // Fallback: try in-app browser
        try {
          await launchUrl(websiteUri, mode: LaunchMode.platformDefault);
        } catch (e2) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Could not open website. Please visit $formattedUrl manually.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error opening website: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _buildBusinessHourItem extends StatelessWidget {
  final String day;
  final String hours;

  const _buildBusinessHourItem({
    required this.day,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          Text(
            hours,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
