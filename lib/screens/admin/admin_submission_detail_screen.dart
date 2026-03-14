import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../models/admin_model.dart';
import '../../models/field_officer_model.dart';
import '../../models/admin_submission_model.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_colors.dart';
import 'admin_message_screen.dart';

class AdminSubmissionDetailScreen extends StatefulWidget {
  final AdminSubmission submission;
  final Admin? admin;
  final FieldOfficer? fieldOfficer;

  const AdminSubmissionDetailScreen({
    super.key,
    required this.submission,
    this.admin,
    this.fieldOfficer,
  }) : assert(admin != null || fieldOfficer != null,
            'Either admin or fieldOfficer must be provided');

  @override
  State<AdminSubmissionDetailScreen> createState() =>
      _AdminSubmissionDetailScreenState();
}

class _AdminSubmissionDetailScreenState
    extends State<AdminSubmissionDetailScreen> {
  final TextEditingController _adminNotesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _selectedStatus = '';
  bool _isUpdating = false;
  AdminSubmission? _freshSubmission;
  Timer? _refreshTimer;
  bool get isFieldOfficer => widget.fieldOfficer != null;

  // Image picker for field officer collection photo
  final ImagePicker _picker = ImagePicker();
  File? _collectionImage;
  Uint8List? _collectionImageBytes;
  String? _collectionImageName;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.submission.status;
    _adminNotesController.text = widget.submission.adminNotes ?? '';
    _priceController.text = (widget.submission.price).toStringAsFixed(2);
    _loadFresh();
    // Auto-refresh submission details every 5 seconds for field officers
    if (isFieldOfficer) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadFresh(silent: true),
      );
    }
  }

  Future<void> _loadFresh({bool silent = false}) async {
    try {
      // Fetch directly from scrap_submissions to guarantee image_url/video_url
      AdminSubmission? latest = await AdminService.getSubmissionWithMedia(
        widget.submission.id,
        assignedOfficerId: isFieldOfficer ? widget.fieldOfficer?.id : null,
      );
      latest ??= isFieldOfficer && widget.fieldOfficer != null
          ? await AdminService.getSubmissionByIdForFieldOfficer(
              widget.submission.id, widget.fieldOfficer!.id)
          : await AdminService.getSubmissionById(widget.submission.id);
      if (latest != null && mounted) {
        final s = latest;
        final hasChanges = _freshSubmission == null ||
            _freshSubmission!.status != s.status ||
            _freshSubmission!.adminNotes != s.adminNotes ||
            _freshSubmission!.imageUrl != s.imageUrl ||
            _freshSubmission!.videoUrl != s.videoUrl ||
            _freshSubmission!.adminCollectionImageUrl !=
                s.adminCollectionImageUrl;

        if (hasChanges) {
          setState(() {
            _freshSubmission = s;
            _selectedStatus = s.status;
            if (_adminNotesController.text == _freshSubmission?.adminNotes ||
                _adminNotesController.text == widget.submission.adminNotes) {
              _adminNotesController.text = s.adminNotes ?? '';
            }
            _priceController.text = s.price.toStringAsFixed(2);
          });
        }
      }
    } catch (e) {
      // Silent error handling for auto-refresh
      if (!silent && mounted) {
        print('Error refreshing submission: $e');
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _adminNotesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _updatePrice() async {
    final raw = _priceController.text.trim();
    if (raw.isEmpty) {
      _showSnackBar('Enter a price');
      return;
    }
    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null) {
      _showSnackBar('Invalid price');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final ok = await SupabaseService.updateSubmissionPrice(
        submissionId: widget.submission.id,
        price: parsed,
      );
      if (ok) {
        _showSnackBar('Price updated', isError: false);
        await _loadFresh();
      } else {
        _showSnackBar('Failed to update price');
      }
    } catch (e) {
      _showSnackBar('Error updating price: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == widget.submission.status &&
        _adminNotesController.text.trim() ==
            (widget.submission.adminNotes ?? '')) {
      return; // No changes
    }

    // Check if trying to approve without price review (admin only)
    if (!isFieldOfficer &&
        _selectedStatus == 'approved' &&
        widget.submission.price == 0) {
      _showSnackBar('Please set a price before approving this submission');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final error = await AdminService.updateSubmissionStatus(
        submissionId: widget.submission.id,
        status: _selectedStatus,
        adminNotes: _adminNotesController.text.trim().isEmpty
            ? null
            : _adminNotesController.text.trim(),
        reviewedBy: isFieldOfficer ? null : widget.admin!.id,
      );

      if (error == null && mounted) {
        _showSnackBar('Status updated successfully', isError: false);
        _loadFresh();
        Navigator.pop(context, true); // Return true to indicate update
      } else if (mounted) {
        _showSnackBar(error ?? 'Failed to update status');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error updating status: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _rejectJob() async {
    // Field officer: use richer flow with image + notes, reuse collection columns.
    if (isFieldOfficer) {
      await _rejectJobAsFieldOfficer();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject job?'),
        content: const Text(
          'This will mark the job as rejected. You can add a reason in the notes below before confirming.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isUpdating = true);
    try {
      final error = await AdminService.updateSubmissionStatus(
        submissionId: widget.submission.id,
        status: 'rejected',
        adminNotes: _adminNotesController.text.trim().isEmpty
            ? null
            : _adminNotesController.text.trim(),
        reviewedBy: isFieldOfficer ? null : widget.admin!.id,
      );
      if (error == null && mounted) {
        _showSnackBar('Job rejected', isError: false);
        _loadFresh();
        Navigator.pop(context, true);
      } else if (mounted) {
        _showSnackBar('Failed to reject. ${error ?? ""}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Field officer rejection: allow photo + notes (uses same image column as collection).
  Future<void> _rejectJobAsFieldOfficer() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject Job'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a photo explaining the rejection (optional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(
                      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
                      maxWidth: 1920,
                      maxHeight: 1080,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      if (kIsWeb) {
                        final bytes = await image.readAsBytes();
                        setDialogState(() {
                          _collectionImageBytes = bytes;
                          _collectionImageName = image.name;
                          _collectionImage = null;
                        });
                      } else {
                        setDialogState(() {
                          _collectionImage = File(image.path);
                          _collectionImageBytes = null;
                          _collectionImageName = null;
                        });
                      }
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _collectionImage != null ||
                            _collectionImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.memory(
                                    _collectionImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    _collectionImage!,
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate,
                                  size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add photo (optional)',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rejection notes (reason):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Explain why this job is being rejected...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _collectionImage = null;
                  _collectionImageBytes = null;
                  _collectionImageName = null;
                });
                Navigator.pop(context, null);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'confirmed': true,
                  'image': _collectionImage,
                  'imageBytes': _collectionImageBytes,
                  'imageName': _collectionImageName,
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject job'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result['confirmed'] != true || !mounted) {
      setState(() {
        _collectionImage = null;
        _collectionImageBytes = null;
        _collectionImageName = null;
      });
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Upload rejection image (reuses admin_collection_image_url column)
      String? adminCollectionImageUrl;
      if (result['image'] != null || result['imageBytes'] != null) {
        if (kIsWeb) {
          adminCollectionImageUrl =
              await SupabaseService.uploadCollectionImageBytes(
            bytes: result['imageBytes'],
            originalFileName: result['imageName'] ??
                'officer_reject_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else {
          adminCollectionImageUrl =
              await SupabaseService.uploadCollectionImage(result['image']);
        }
      }

      final notes = _adminNotesController.text.trim().isEmpty
          ? 'Rejected by ${widget.fieldOfficer?.name ?? 'Field officer'}'
          : _adminNotesController.text.trim();

      final success = await AdminService.markJobAsRejected(
        submissionId: widget.submission.id,
        notes: notes,
        adminCollectionImageUrl: adminCollectionImageUrl,
      );

      if (success) {
        // Notify user in chat that job was rejected
        final actorId = widget.fieldOfficer?.id ?? widget.admin?.id;
        if (actorId != null) {
          try {
            final messageContent = '❌ Job rejected\n\n$notes';
            await AdminService.sendMessageToUser(
              submissionId: widget.submission.id,
              content: messageContent,
              adminId: actorId,
              imageUrl: adminCollectionImageUrl,
            );
          } catch (e) {
            print('⚠️ Could not send rejection message: $e');
          }
        }

        _showSnackBar('Job rejected', isError: false);
        _loadFresh();
        setState(() {
          _collectionImage = null;
          _collectionImageBytes = null;
          _collectionImageName = null;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        _showSnackBar('Failed to reject job');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _markJobCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as completed?'),
        content: const Text(
          'This will mark the job as completed. Use "Mark as Collected" below if you want to add a collection photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isUpdating = true);
    try {
      final error = await AdminService.updateSubmissionStatus(
        submissionId: widget.submission.id,
        status: 'completed',
        adminNotes: _adminNotesController.text.trim().isEmpty
            ? null
            : _adminNotesController.text.trim(),
        reviewedBy: isFieldOfficer ? null : widget.admin!.id,
      );
      if (error == null && mounted) {
        _showSnackBar('Job marked as completed', isError: false);
        _loadFresh();
        Navigator.pop(context, true);
      } else if (mounted) {
        _showSnackBar('Failed to update. ${error ?? ""}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAsCollected() async {
    // Show dialog with image picker and notes
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark as Collected'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a photo of the collected item:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(
                      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
                      maxWidth: 1920,
                      maxHeight: 1080,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      if (kIsWeb) {
                        final bytes = await image.readAsBytes();
                        setDialogState(() {
                          _collectionImageBytes = bytes;
                          _collectionImageName = image.name;
                          _collectionImage = null;
                        });
                      } else {
                        setDialogState(() {
                          _collectionImage = File(image.path);
                          _collectionImageBytes = null;
                          _collectionImageName = null;
                        });
                      }
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _collectionImage != null ||
                            _collectionImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.memory(
                                    _collectionImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    _collectionImage!,
                                    fit: BoxFit.cover,
                                  ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate,
                                  size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to add photo',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add remarks (optional):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter any remarks about the collection...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _collectionImage = null;
                  _collectionImageBytes = null;
                  _collectionImageName = null;
                });
                Navigator.pop(context, null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'confirmed': true,
                  'image': _collectionImage,
                  'imageBytes': _collectionImageBytes,
                  'imageName': _collectionImageName,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Mark as Collected'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result['confirmed'] != true) {
      setState(() {
        _collectionImage = null;
        _collectionImageBytes = null;
        _collectionImageName = null;
      });
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Upload collection image if provided
      String? adminCollectionImageUrl;
      if (result['image'] != null || result['imageBytes'] != null) {
        if (kIsWeb) {
          adminCollectionImageUrl =
              await SupabaseService.uploadCollectionImageBytes(
            bytes: result['imageBytes'],
            originalFileName: result['imageName'] ??
                'officer_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
        } else {
          adminCollectionImageUrl =
              await SupabaseService.uploadCollectionImage(result['image']);
        }
      }

      final collectedBy =
          widget.fieldOfficer?.name ?? widget.admin?.username ?? 'Admin';
      final notes = _adminNotesController.text.trim().isEmpty
          ? 'Collected by $collectedBy'
          : _adminNotesController.text.trim();
      final actorId = widget.fieldOfficer?.id ?? widget.admin?.id;

      // Mark as collected — payment is handled on the web dashboard
      final success = await AdminService.markJobAsCollected(
        submissionId: widget.submission.id,
        notes: notes,
        officerId: widget.fieldOfficer?.id,
        adminCollectionImageUrl: adminCollectionImageUrl,
      );

      if (success && actorId != null) {
        // Send a message to the user with the collection photo and notes
        try {
          final messageContent = '✅ Item collected successfully!\n\n$notes';

          await AdminService.sendMessageToUser(
            submissionId: widget.submission.id,
            content: messageContent,
            adminId: actorId,
            imageUrl: adminCollectionImageUrl,
          );
        } catch (e) {
          print('⚠️ Could not send collection message: $e');
          // Don't fail the whole operation if message sending fails
        }

        _showSnackBar('✅ Item marked as collected successfully!',
            isError: false);
        _loadFresh();
        setState(() {
          _collectionImage = null;
          _collectionImageBytes = null;
          _collectionImageName = null;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        _showSnackBar('Failed to mark item as collected');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
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

  Future<void> _openAddressInMaps(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);

      // Try multiple URL formats for better compatibility
      final List<Uri> mapUris = [
        // Google Maps web (primary)
        Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$encodedAddress'),
        // Google Maps app (Android/iOS)
        Uri.parse('https://maps.google.com/?q=$encodedAddress'),
        // Alternative format
        Uri.parse('geo:0,0?q=$encodedAddress'),
      ];

      bool launched = false;
      for (var uri in mapUris) {
        try {
          // Try launching directly first (canLaunchUrl sometimes returns false incorrectly)
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // If direct launch fails, try checking canLaunchUrl
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              launched = true;
              break;
            }
          } catch (e2) {
            continue; // Try next format
          }
        }
      }

      if (!launched && mounted) {
        _showSnackBar(
            'Could not open maps. Please install Google Maps app or check your internet connection.');
      }
    } catch (e) {
      print('Error opening maps: $e');
      if (mounted) {
        _showSnackBar('Error opening maps: ${e.toString()}');
      }
    }
  }

  Future<void> _openLocationInMaps(double latitude, double longitude) async {
    try {
      // Try multiple URL formats for better compatibility
      final List<Uri> mapUris = [
        // Google Maps with coordinates (most reliable)
        Uri.parse('https://www.google.com/maps?q=$latitude,$longitude'),
        // Google Maps search format
        Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'),
        // Geo URI (works on mobile)
        Uri.parse('geo:$latitude,$longitude'),
        // Alternative format
        Uri.parse('https://maps.google.com/?q=$latitude,$longitude'),
      ];

      bool launched = false;
      for (var uri in mapUris) {
        try {
          // Try launching directly first (canLaunchUrl sometimes returns false incorrectly)
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // If direct launch fails, try checking canLaunchUrl
          try {
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              launched = true;
              break;
            }
          } catch (e2) {
            continue; // Try next format
          }
        }
      }

      if (!launched && mounted) {
        _showSnackBar(
            'Could not open maps. Please install Google Maps app or check your internet connection.');
      }
    } catch (e) {
      print('Error opening maps: $e');
      if (mounted) {
        _showSnackBar('Error opening maps: ${e.toString()}');
      }
    }
  }

  Future<void> _showImageDialog(String url) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: const [
                    Icon(Icons.image, color: AppColors.primaryGreen),
                    SizedBox(width: 8),
                    Text('Image Preview',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('Failed to load image'),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showVideoDialog(String url) async {
    VideoPlayerController? controller;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        return FutureBuilder(
          future: controller!.initialize(),
          builder: (context, snapshot) {
            final isReady = snapshot.connectionState == ConnectionState.done;
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.ondemand_video,
                            color: AppColors.accentOrange),
                        SizedBox(width: 8),
                        Text('Video',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio:
                          isReady ? controller!.value.aspectRatio : 16 / 9,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(color: Colors.black),
                          if (isReady)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: VideoPlayer(controller!),
                            )
                          else
                            const CircularProgressIndicator(),
                          if (isReady)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      controller!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (controller!.value.isPlaying) {
                                        controller!.pause();
                                      } else {
                                        controller!.play();
                                      }
                                      (context as Element).markNeedsBuild();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: VideoProgressIndicator(
                                      controller!,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: AppColors.accentOrange,
                                        bufferedColor: Colors.white70,
                                        backgroundColor: Colors.white24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    await controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionStatus =
        (_freshSubmission ?? widget.submission).status.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Job Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminMessageScreen(
                    submission: widget.submission,
                    admin: widget.admin,
                    fieldOfficer: widget.fieldOfficer,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Submission Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: AppColors.primaryGreen),
                        const SizedBox(width: 8),
                        const Text(
                          'Submission Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                        label: 'Item Name', value: widget.submission.itemName),
                    if (widget.submission.userName.trim().isNotEmpty)
                      _InfoRow(
                        label: 'User Name',
                        value: widget.submission.userName,
                      ),
                    if (widget.submission.phoneNumber.trim().isNotEmpty)
                      _InfoRow(
                        label: 'Phone Number',
                        value: widget.submission.phoneNumber,
                      ),
                    _InfoRow(
                      label: 'Price (GH\u20B5)',
                      value:
                          (_freshSubmission?.price ?? widget.submission.price)
                              .toStringAsFixed(2),
                    ),
                    if ((_freshSubmission?.collectionDate ??
                            widget.submission.collectionDate) !=
                        null)
                      _InfoRow(
                        label: 'Collection Date',
                        value: _formatDateTime(
                            (_freshSubmission?.collectionDate ??
                                widget.submission.collectionDate)!),
                      ),
                    _InfoRow(
                      label: 'Submitted At',
                      value: _formatDateTime(widget.submission.submittedAt),
                    ),
                    const SizedBox(height: 8),
                    // Price & Collection Date Summary (inline)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.price_change,
                              color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Price: GH\u20B5 ${(_freshSubmission?.price ?? widget.submission.price).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule,
                              color: AppColors.primaryGreen, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_freshSubmission?.collectionDate ??
                                          widget.submission.collectionDate) !=
                                      null
                                  ? _formatDateTime(
                                      (_freshSubmission?.collectionDate ??
                                          widget.submission.collectionDate)!)
                                  : 'No collection date set',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _InfoRow(label: 'Status', value: widget.submission.status),
                    if (widget.submission.reviewedBy != null)
                      _InfoRow(
                          label: 'Reviewed By',
                          value: widget.submission.reviewedBy!),
                    if (widget.submission.reviewedAt != null)
                      _InfoRow(
                        label: 'Reviewed At',
                        value: _formatDateTime(widget.submission.reviewedAt!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Info (if available)
            if (widget.submission.latitude != null &&
                widget.submission.longitude != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          const Text(
                            'Location Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Latitude',
                        value: widget.submission.latitude!.toString(),
                      ),
                      _InfoRow(
                        label: 'Longitude',
                        value: widget.submission.longitude!.toString(),
                      ),
                      if (widget.submission.address != null)
                        InkWell(
                          onTap: () =>
                              _openAddressInMaps(widget.submission.address!),
                          child: _InfoRow(
                            label: 'Address',
                            value: widget.submission.address!,
                            isClickable: true,
                          ),
                        ),
                      if (widget.submission.latitude != null &&
                          widget.submission.longitude != null)
                        InkWell(
                          onTap: () => _openLocationInMaps(
                            widget.submission.latitude!,
                            widget.submission.longitude!,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.map,
                                    color: AppColors.primaryGreen),
                                const SizedBox(width: 8),
                                const Text(
                                  'Open in Google Maps',
                                  style: TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Comments
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.comment,
                            color: AppColors.accentOrange),
                        const SizedBox(width: 8),
                        const Text(
                          'User Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.submission.comments,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Media (Image & Video) - right after User Comments - ALWAYS shown
            Builder(
              builder: (context) {
                final eff = _freshSubmission ?? widget.submission;
                final hasImage = (eff.imageUrl ?? '').trim().isNotEmpty;
                final hasVideo = (eff.videoUrl ?? '').trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.image,
                                    color: AppColors.primaryGreen),
                                const SizedBox(width: 8),
                                const Text(
                                  'Image & Video',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (!hasImage && !hasVideo)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                        color: Colors.grey.shade600, size: 32),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'No image or video submitted for this job.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (hasImage)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Image',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () =>
                                        _showImageDialog(eff.imageUrl!),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        eff.imageUrl!,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          height: 180,
                                          color: Colors.grey[200],
                                          alignment: Alignment.center,
                                          child: const Text(
                                              'Failed to load image'),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showImageDialog(eff.imageUrl!),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open'),
                                    ),
                                  ),
                                ],
                              ),
                            if (hasImage && hasVideo)
                              const SizedBox(height: 16),
                            if (hasVideo)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Video',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () =>
                                        _showVideoDialog(eff.videoUrl!),
                                    child: Container(
                                      height: 160,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.play_circle_fill,
                                          size: 48, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showVideoDialog(eff.videoUrl!),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open'),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Collection Photo (when field officer marked as collected with photo)
            Builder(
              builder: (context) {
                final eff = _freshSubmission ?? widget.submission;
                final hasCollectionPhoto =
                    (eff.adminCollectionImageUrl ?? '').trim().isNotEmpty;
                if (!hasCollectionPhoto) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.camera_alt,
                                    color: AppColors.primaryGreen),
                                const SizedBox(width: 8),
                                const Text(
                                  'Collection Photo',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Photo taken when this item was collected',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _showImageDialog(
                                  eff.adminCollectionImageUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  eff.adminCollectionImageUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: const Text('Failed to load image'),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showImageDialog(
                                    eff.adminCollectionImageUrl!),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Field Officer Actions / Admin Actions
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isFieldOfficer
                              ? Icons.person_pin_circle
                              : Icons.admin_panel_settings,
                          color: isFieldOfficer
                              ? AppColors.primaryGreen
                              : Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFieldOfficer
                              ? 'Field Officer Actions'
                              : 'Admin Actions',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isFieldOfficer) ...[
                      // Field Officer UI: Item Collection card
                      // Only show when job is not completed AND not rejected
                      if (!['completed', 'rejected']
                          .contains(submissionStatus)) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 48,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Item Collection',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Mark this item as collected when you have successfully picked it up from the user.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              // Reject job / Mark completed (always visible when job not completed)
                              if ((_freshSubmission ?? widget.submission)
                                      .status
                                      .trim()
                                      .toLowerCase() !=
                                  'rejected') ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            _isUpdating ? null : _rejectJob,
                                        icon: const Icon(Icons.cancel_outlined,
                                            size: 20),
                                        label: const Text('Reject job'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isUpdating
                                            ? null
                                            : _markJobCompleted,
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 20),
                                        label: const Text('Mark completed'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Notes field for field officer
                              TextField(
                                controller: _adminNotesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'Add rejection / collection notes (optional)...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.note),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Mark as Collected Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isUpdating ? null : _markAsCollected,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: _isUpdating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_circle),
                                  label: Text(
                                    _isUpdating
                                        ? 'Marking...'
                                        : 'Mark as Collected',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Status finalised - show appropriate message
                        if (submissionStatus == 'completed') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 32,
                                  color: AppColors.primaryGreen,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This item has been marked as collected.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (submissionStatus == 'rejected') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accentOrange,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.cancel,
                                  size: 32,
                                  color: AppColors.accentOrange,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This item has been rejected.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentOrange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ] else ...[
                      // Admin UI: Price Editor
                      const Text(
                        'Price (GH\u20B5):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // Price Review Warning
                      if (widget.submission.price == 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.accentOrange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning,
                                color: AppColors.accentOrange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Price review required before approval',
                                  style: TextStyle(
                                    color: AppColors.accentOrange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                prefixText: 'GH\u20B5 ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isUpdating ? null : _updatePrice,
                            icon: _isUpdating
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Admin: Reject or Mark completed (quick actions)
                      if (widget.submission.status.toLowerCase() !=
                              'completed' &&
                          widget.submission.status.toLowerCase() !=
                              'rejected') ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isUpdating ? null : _rejectJob,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Reject job'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isUpdating ? null : _markJobCompleted,
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Mark completed'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Status Update (dropdown for other statuses)
                      const Text(
                        'Update Status:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'pending',
                          'reviewed',
                          'approved',
                          'rejected',
                          'completed'
                        ]
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Admin Notes
                      const Text(
                        'Admin Notes:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _adminNotesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Add notes about this submission...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mark as Collected (with photo) - for admins
                      if (widget.submission.status.toLowerCase() != 'completed')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 32,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Mark as collected with a photo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isUpdating ? null : _markAsCollected,
                                    icon:
                                        const Icon(Icons.camera_alt, size: 20),
                                    label: const Text('Mark as Collected'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Update Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : _updateStatus,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isUpdating
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Update Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isClickable;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: isClickable ? AppColors.primaryGreen : null,
                fontWeight: isClickable ? FontWeight.bold : null,
                decoration: isClickable ? TextDecoration.underline : null,
              ),
            ),
          ),
          if (isClickable)
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.primaryGreen,
            ),
        ],
      ),
    );
  }
}
