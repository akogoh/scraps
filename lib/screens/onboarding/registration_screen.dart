import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../services/otp_service.dart';
import '../../utils/app_colors.dart';
import '../dashboard/dashboard_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with CodeAutoFill {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  
  int _currentStep = 1; // 1: Phone, 2: OTP, 3: Name (if new user)
  bool _isLoading = false;
  String? _phoneNumber;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _appSignature;

  @override
  void initState() {
    super.initState();
    _listenForSms();
    _getAppSignature();
  }

  Future<void> _getAppSignature() async {
    try {
      _appSignature = await SmsAutoFill().getAppSignature;
      print('📱 App Signature: $_appSignature');
      // You can use this signature in the OTP message for better autofill
      // Format: "Your code is 123456\n$_appSignature"
    } catch (e) {
      print('⚠️ Could not get app signature: $e');
    }
  }

  void _listenForSms() {
    listenForCode();
  }

  @override
  void codeUpdated() {
    // Auto-fill OTP when SMS is received
    if (code != null) {
      setState(() {
        _otpController.text = code!;
      });
      
      // Auto-verify when complete 6-digit code is received
      if (code!.length == 6 && !_isLoading) {
        // Small delay to ensure UI is updated and user can see the code
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isLoading) {
            _verifyOtp();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _resendTimer?.cancel();
    cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    setState(() {
      _resendCountdown = 60; // 60 seconds countdown
    });
    
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.trim().length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'Phone number must contain only digits';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the OTP';
    }
    if (value.trim().length != 6) {
      return 'OTP must be 6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value.trim())) {
      return 'OTP must contain only digits';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      final result = await OtpService.sendOtp(phoneNumber);

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _phoneNumber = phoneNumber;
            _currentStep = 2;
            _isLoading = false;
            _otpController.clear(); // Clear any previous OTP
          });
          _startResendCountdown();
          
          // Re-initialize SMS listener when moving to OTP step
          _listenForSms();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('OTP sent successfully! Check your SMS.'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to send OTP'),
              backgroundColor: AppColors.accentOrange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error sending OTP: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending OTP: ${e.toString()}'),
            backgroundColor: AppColors.accentOrange,
          ),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final otp = _otpController.text.trim();
      final result = await OtpService.verifyOtp(_phoneNumber!, otp);

      if (mounted) {
        if (result['success'] == true) {
          // Check if user exists
          final existingUser = await SupabaseService.getUserByPhone(_phoneNumber!);
          
          if (existingUser != null) {
            // Existing user - login directly (use name from input if provided, otherwise use existing)
            final nameToUse = _nameController.text.trim().isNotEmpty 
                ? _nameController.text.trim() 
                : existingUser.name;
            
            // Update user name if a new name was provided
            if (_nameController.text.trim().isNotEmpty && nameToUse != existingUser.name) {
              // Update the user's name in database if changed
              // Note: You may want to add an update method to SupabaseService for this
            }
            
            await SessionManager.saveUserSession(
              phoneNumber: existingUser.phoneNumber,
              name: nameToUse,
              userId: existingUser.id,
            );
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(user: existingUser),
              ),
            );
          } else {
            // New user - check if name was provided
            if (_nameController.text.trim().isNotEmpty) {
              // Name provided - complete registration directly
              final name = _nameController.text.trim();
              final user = await SupabaseService.createOrGetUser(name, _phoneNumber!);
              
              await SessionManager.saveUserSession(
                phoneNumber: user.phoneNumber,
                name: user.name,
                userId: user.id,
              );

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => DashboardScreen(user: user),
                ),
              );
            } else {
              // No name provided - ask for name
              setState(() {
                _currentStep = 3;
                _isLoading = false;
              });
            }
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Invalid OTP'),
              backgroundColor: AppColors.accentOrange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying OTP: ${e.toString()}'),
            backgroundColor: AppColors.accentOrange,
          ),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await OtpService.resendOtp(_phoneNumber!);

      if (mounted) {
        if (result['success'] == true) {
          _startResendCountdown();
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('OTP resent successfully!'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to resend OTP'),
              backgroundColor: AppColors.accentOrange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error resending OTP: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resending OTP: ${e.toString()}'),
            backgroundColor: AppColors.accentOrange,
          ),
        );
      }
    }
  }

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final user = await SupabaseService.createOrGetUser(name, _phoneNumber!);
      
      await SessionManager.saveUserSession(
        phoneNumber: user.phoneNumber,
        name: user.name,
        userId: user.id,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(user: user),
          ),
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
            backgroundColor: AppColors.accentOrange,
          ),
        );
      }
    }
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        // Logo/Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.recycling,
            size: 60,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 40),

        // Title
        const Text(
          'Welcome to GreenHaul',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your details to get started',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textGrey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Phone Field (Primary - emphasized)
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number *',
            hintText: 'Enter 10-digit phone number',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: _validatePhone,
          autofocus: true,
        ),
        const SizedBox(height: 20),

        // Name Field (Secondary - optional for existing users)
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name (Optional)',
            hintText: 'Enter your full name',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textCapitalization: TextCapitalization.words,
          // Name is optional - only validate if provided
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              return _validateName(value);
            }
            return null; // Allow empty name
          },
        ),
        const SizedBox(height: 40),

        // Send OTP Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Send OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Terms
        const Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _currentStep = 1;
                _otpController.clear();
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        // Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sms,
            size: 50,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 30),

        // Title
        const Text(
          'Enter Verification Code',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to\n$_phoneNumber',
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textGrey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // OTP Field with SMS Autofill support
        TextFormField(
          controller: _otpController,
          decoration: InputDecoration(
            labelText: 'Enter OTP',
            hintText: '000000',
            prefixIcon: const Icon(Icons.lock),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
            helperText: 'SMS code will be auto-filled if available',
            helperStyle: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey.withOpacity(0.7),
            ),
          ),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: _validateOtp,
          autofocus: true,
          // Enable SMS autofill
          autofillHints: const [AutofillHints.oneTimeCode],
          // Auto-verify when 6 digits are entered (manual typing)
          onChanged: (value) {
            if (value.length == 6 && !_isLoading) {
              // Small delay to ensure UI is updated
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && !_isLoading) {
                  _verifyOtp();
                }
              });
            }
          },
        ),
        const SizedBox(height: 20),

        // Resend OTP
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive the code? ",
              style: TextStyle(color: AppColors.textGrey),
            ),
            if (_resendCountdown > 0)
              Text(
                'Resend in $_resendCountdown',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading ? null : _resendOtp,
                child: const Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 30),

        // Verify Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Verify OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        // Back button
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _currentStep = 2;
                _nameController.clear();
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        // Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_add,
            size: 50,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 30),

        // Title
        const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your name to complete registration',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textGrey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),

        // Name Field
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Full Name',
            hintText: 'Enter your full name',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: _validateName,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        const SizedBox(height: 40),

        // Complete Registration Button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _completeRegistration,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Complete Registration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: _currentStep == 1
                ? _buildPhoneStep()
                : _currentStep == 2
                    ? _buildOtpStep()
                    : _buildNameStep(),
          ),
        ),
      ),
    );
  }
}
