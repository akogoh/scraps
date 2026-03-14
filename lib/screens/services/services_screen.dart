import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Services'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your trusted partner in scrap management and recycling',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Service Gallery Section
            const Text(
              'Our Work Gallery',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildServiceGallery(),

            const SizedBox(height: 24),

            // Services Section - Carousel
            const Text(
              'Our Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),

            // Service Carousel
            SizedBox(
              height: 400,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildServiceCard(
                      icon: _getServiceIcon(index),
                      title: _getServiceTitle(index),
                      description: _getServiceDescription(index),
                      features: _getServiceFeatures(index),
                    ),
                  );
                },
              ),
            ),

            // Page Indicators
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Container(
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? AppColors.primaryGreen
                        : AppColors.primaryGreen.withOpacity(0.3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Contact Section
            const Text(
              'Get In Touch',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
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
                    label: 'Call Us',
                    value: '0249211930 / 0201032117 / 0303981066',
                    onTap: () => _makePhoneCall('0249211930'),
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: 'GP 1837, Accra Central',
                    onTap: () => _openMaps(),
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.email,
                    label: 'Email',
                    value: 'info@greenhaulsolution.com',
                    onTap: () => _sendEmail('info@greenhaulsolution.com'),
                  ),
                  const SizedBox(height: 12),
                  _buildContactItem(
                    icon: Icons.language,
                    label: 'Website',
                    value: 'www.greenhaulsolution.com',
                    onTap: () =>
                        _openWebsite('https://www.greenhaulsolution.com'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Why Choose Us Section
            const Text(
              'Why Choose GreenHaul?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),

            _buildWhyChooseUsItem(
              icon: Icons.verified,
              title: 'Transparent Pricing',
              description:
                  'Clear and upfront pricing structure without hidden fees',
            ),

            _buildWhyChooseUsItem(
              icon: Icons.schedule,
              title: 'Convenient Service',
              description: 'Flexible scheduling and hassle-free pickup process',
            ),

            _buildWhyChooseUsItem(
              icon: Icons.eco,
              title: 'Environmental Responsibility',
              description:
                  'Contributing to a cleaner environment through proper recycling',
            ),

            _buildWhyChooseUsItem(
              icon: Icons.payment,
              title: 'Immediate Payment',
              description: 'Get paid on the spot for your scrap materials',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGallery() {
    // Generate list of image paths
    List<String> imagePaths = [];
    for (int i = 1; i <= 25; i++) {
      imagePaths.add('assets/g$i.jpg');
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imagePaths.length,
        itemBuilder: (context, index) {
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () => _showImageDialog(context, imagePaths[index]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      Image.asset(
                        imagePaths[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 50,
                            ),
                          );
                        },
                      ),
                      // Click indicator overlay
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getServiceIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.business;
      case 2:
        return Icons.directions_car;
      case 3:
        return Icons.recycling;
      default:
        return Icons.home;
    }
  }

  String _getServiceTitle(int index) {
    switch (index) {
      case 0:
        return 'Home Pickup Services';
      case 1:
        return 'Workshop & Business Services';
      case 2:
        return 'Vehicle Scrapping';
      case 3:
        return 'Metal Recycling';
      default:
        return '';
    }
  }

  String _getServiceDescription(int index) {
    switch (index) {
      case 0:
        return 'We come to your home to collect old metal articles and appliances. Simply gather them, take a photo, and send us the location.';
      case 1:
        return 'Specialized services for workshops, manufacturing companies, and businesses with large volumes of scrap materials.';
      case 2:
        return 'We buy condemned accident vehicles and damaged equipment for better value than traditional scrap yards.';
      case 3:
        return 'We accept all types of metal scraps including aluminum cans, copper, steel, and other valuable metals.';
      default:
        return '';
    }
  }

  List<String> _getServiceFeatures(int index) {
    switch (index) {
      case 0:
        return [
          'Free home pickup',
          'Competitive pricing',
          'Immediate payment',
          'Professional service'
        ];
      case 1:
        return [
          'Bulk collection services',
          'Scheduled pickups',
          'Transparent pricing',
          'Equipment transportation'
        ];
      case 2:
        return [
          'Accident vehicle collection',
          'Damaged equipment purchase',
          'Fair market pricing',
          'Quick processing'
        ];
      case 3:
        return [
          'All metal types accepted',
          'Environmental responsibility',
          'Cash for your scraps',
          'Eco-friendly processing'
        ];
      default:
        return [];
    }
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen.withOpacity(0.05),
              AppColors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon and Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Description
              Text(
                description,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Features
              ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
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

  Widget _buildWhyChooseUsItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
              size: 20,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      final subject = 'Inquiry about GreenHaul Services';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Could not open website. Please visit $formattedUrl manually.'),
              backgroundColor: Colors.orange,
            ),
          );
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

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Full screen image
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 100,
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
