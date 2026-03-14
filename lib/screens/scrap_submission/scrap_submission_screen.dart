import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../utils/app_colors.dart';

class ScrapSubmissionScreen extends StatefulWidget {
  const ScrapSubmissionScreen({super.key});

  @override
  State<ScrapSubmissionScreen> createState() => _ScrapSubmissionScreenState();
}

class _ScrapSubmissionScreenState extends State<ScrapSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _commentsController = TextEditingController();
  final _priceController = TextEditingController();

  File? _selectedImage;
  File? _selectedVideo;
  Uint8List? _selectedImageBytes; // web
  Uint8List? _selectedVideoBytes; // web
  String? _selectedImageName; // web name
  String? _selectedVideoName; // web name
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Location variables
  Position? _currentPosition;
  String? _currentAddress;
  bool _isGettingLocation = false;
  bool _isSelling = true; // default to selling (Yes)

  @override
  void dispose() {
    _itemNameController.dispose();
    _commentsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = image.name;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error picking image: ${e.toString()}');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );

      if (video != null) {
        if (kIsWeb) {
          final bytes = await video.readAsBytes();
          setState(() {
            _selectedVideoBytes = bytes;
            _selectedVideoName = video.name;
            _selectedVideo = null;
          });
        } else {
          setState(() {
            _selectedVideo = File(video.path);
            _selectedVideoBytes = null;
            _selectedVideoName = null;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error picking video: ${e.toString()}');
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  void _removeVideo() {
    setState(() {
      _selectedVideo = null;
      _selectedVideoBytes = null;
      _selectedVideoName = null;
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled. Please enable them.');
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(kIsWeb
            ? 'Location permission denied in browser. Click the lock icon in the address bar and allow Location.'
            : 'Location permissions are permanently denied.');
        return;
      }

      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy:
              kIsWeb ? LocationAccuracy.medium : LocationAccuracy.high,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (_) {
        // Fallback to last known position if available
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        _showSnackBar(kIsWeb
            ? 'Unable to get location. Ensure the site has Location permission and try again.'
            : 'Unable to get location. Please try again.');
        return;
      }

      // Get address from coordinates (web-safe)
      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          address =
              '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
        }
      } catch (_) {
        // On web, reverse geocoding can be unavailable; fall back to lat/lng text
        if (kIsWeb) {
          address = 'Lat ${position.latitude.toStringAsFixed(6)}, '
              'Lng ${position.longitude.toStringAsFixed(6)}';
        }
      }

      setState(() {
        _currentPosition = position;
        _currentAddress = address;
        _isGettingLocation = false;
      });

      _showSnackBar('Location captured successfully!', isError: false);
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  String? _validateItemName(String? value) {
    // Item name is now optional - no validation required
    return null;
  }

  String? _validateComments(String? value) {
    // Comments are now optional - no validation required
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      // Price is optional - no validation required
      return null;
    }
    final priceValue = double.tryParse(value.trim());
    if (priceValue == null) {
      return 'Please enter a valid price';
    }
    if (priceValue < 0) {
      return 'Price cannot be negative';
    }
    return null;
  }

  Future<void> _submitScrap() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null &&
        _selectedVideo == null &&
        _selectedImageBytes == null &&
        _selectedVideoBytes == null) {
      _showSnackBar('Please select at least one image or video');
      return;
    }

    if (_currentPosition == null) {
      _showSnackBar('Please capture your location');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text(
          'Do you want to submit this scrap for collection?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get user session data
      final sessionData = await SessionManager.getUserSession();
      final userId = sessionData['userId'];
      final phoneNumber = sessionData['phone'];

      if (userId == null || phoneNumber == null) {
        _showSnackBar('User session not found. Please login again.');
        return;
      }

      // Upload image and video to Supabase Storage
      String? imageUrl;
      String? videoUrl;

      if (kIsWeb) {
        if (_selectedImageBytes != null && _selectedImageName != null) {
          imageUrl = await SupabaseService.uploadImageBytes(
            bytes: _selectedImageBytes!,
            originalFileName: _selectedImageName!,
          );
        }
        if (_selectedVideoBytes != null && _selectedVideoName != null) {
          videoUrl = await SupabaseService.uploadVideoBytes(
            bytes: _selectedVideoBytes!,
            originalFileName: _selectedVideoName!,
          );
        }
      } else {
        if (_selectedImage != null) {
          imageUrl = await SupabaseService.uploadImage(_selectedImage!);
        }

        if (_selectedVideo != null) {
          videoUrl = await SupabaseService.uploadVideo(_selectedVideo!);
        }
      }

      // Parse suggested price
      double? suggestedPrice;
      if (_priceController.text.trim().isNotEmpty) {
        suggestedPrice = double.tryParse(_priceController.text.trim());
      }

      await SupabaseService.createScrapSubmission(
        userId: userId,
        phoneNumber: phoneNumber,
        itemName: _itemNameController.text.trim().isEmpty
            ? 'Unnamed Item'
            : _itemNameController.text.trim(),
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        comments: _commentsController.text.trim().isEmpty
            ? 'No additional comments provided'
            : _commentsController.text.trim(),
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        address: _currentAddress,
        isSelling: _isSelling,
        price: suggestedPrice ?? 0,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Submission failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: const Text(
            'Your scrap submission has been received. We will review it and get back to you soon.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(
                    context, true); // Go back to dashboard with refresh flag
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppColors.accentOrange : AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Scrap'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.recycling,
                      size: 50,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Submit Your Scrap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Take photos/videos and provide details about your scrap items',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Item Name Field
              TextFormField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  labelText: 'Item Name (Optional)',
                  hintText: 'e.g., Broken Car Engine, Old Refrigerator',
                  prefixIcon: const Icon(Icons.inventory),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: _validateItemName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),

              // Selling or Donating Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Are you selling or donating?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isSelling = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _isSelling
                                    ? AppColors.primaryGreen
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isSelling
                                      ? AppColors.primaryGreen
                                      : Colors.grey[300]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isSelling
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: _isSelling
                                        ? Colors.white
                                        : Colors.black54,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Selling (Yes)',
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _isSelling
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isSelling = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                color: !_isSelling
                                    ? AppColors.accentOrange
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_isSelling
                                      ? AppColors.accentOrange
                                      : Colors.grey[300]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !_isSelling
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: !_isSelling
                                        ? Colors.white
                                        : Colors.black54,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Donating (No)',
                                    softWrap: false,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: !_isSelling
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isSelling)
                      const Text(
                        'Select donating if you are giving it out free only',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                  ],
                ),
              ),

              // Image Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedImage == null && _selectedImageBytes == null)
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Stack(
                          children: [
                            if (!kIsWeb && _selectedImage != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if (kIsWeb && _selectedImageBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _selectedImageBytes!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _removeImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Video Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Video (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedVideo == null && _selectedVideoBytes == null)
                      SizedBox(
                        width: double.infinity,
                        height: 120,
                        child: ElevatedButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Record Video'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.black,
                                child: const Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 50,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _removeVideo,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentOrange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: AppColors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Location Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Location *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_currentPosition == null)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isGettingLocation ? null : _getCurrentLocation,
                          icon: _isGettingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.location_on),
                          label: Text(_isGettingLocation
                              ? 'Getting Location...'
                              : 'Get Current Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentOrange,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryGreen),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: AppColors.primaryGreen, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Location Captured',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentPosition = null;
                                      _currentAddress = null;
                                    });
                                  },
                                  child: const Icon(Icons.close,
                                      color: AppColors.accentOrange, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_currentAddress != null)
                              Text(
                                _currentAddress!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Comments Field
              TextFormField(
                controller: _commentsController,
                decoration: InputDecoration(
                  labelText: 'Comments (Optional)',
                  hintText:
                      'Describe the condition, age, and any other relevant details (optional)',
                  prefixIcon: const Icon(Icons.comment),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
                validator: _validateComments,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // Suggested Price Field
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Suggested Price (Optional)',
                  hintText: 'e.g., 500.00',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Text(
                      '¢',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: _validatePrice,
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitScrap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : const Text(
                          'Submit Scrap',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
