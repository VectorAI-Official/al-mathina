import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_auth_service.dart';

const kPrimaryColor = Color(0xFF004D40);

class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const PhoneAuthScreen({
    this.onAuthSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _showOtpField = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  /// Validate phone number format
  bool _isValidPhoneNumber(String phone) {
    // Remove all spaces and special characters except +
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Check if it's a valid international phone number (E.164 format)
    return RegExp(r'^\+\d{1,3}\d{4,14}$').hasMatch(cleanPhone);
  }

  /// Format phone number to E.164 format
  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    if (!cleanPhone.startsWith('+')) {
      // If no +, assume country code 91 (India)
      if (cleanPhone.startsWith('0')) {
        cleanPhone = cleanPhone.substring(1);
      }
      cleanPhone = '+91$cleanPhone';
    }
    
    return cleanPhone;
  }

  /// Send OTP to phone number
  Future<void> _sendOTP() async {
    String phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String formattedPhone = _formatPhoneNumber(phone);
      
      await PhoneAuthService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() {
              _showOtpField = true;
              _verificationId = verificationId;
              _isLoading = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent to $formattedPhone'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onVerificationFailed: (exception) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = exception.message ?? 'Verification failed';
            });
          }
        },
        onVerificationCompleted: (credential) async {
          // Auto sign-in on instant verification (rarely happens)
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              widget.onAuthSuccess?.call();
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (mounted) {
              setState(() => _errorMessage = 'Sign-in failed: $e');
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  /// Verify OTP and sign in
  Future<void> _verifyOTP() async {
    String otp = _otpController.text.trim();

    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the OTP');
      return;
    }

    if (otp.length != 6) {
      setState(() => _errorMessage = 'OTP must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PhoneAuthService.signInWithOTP(
        otp: otp,
        verificationId: _verificationId,
      );

      if (mounted) {
        widget.onAuthSuccess?.call();
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.code == 'invalid-verification-code') {
            _errorMessage = 'Invalid OTP. Please try again.';
          } else {
            _errorMessage = e.message ?? 'Sign-in failed';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Number Sign In'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Logo/Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.phone,
                size: 40,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 32),
            // Title
            Text(
              _showOtpField ? 'Verify OTP' : 'Enter Your Number',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              _showOtpField
                  ? 'Enter the 6-digit code sent to your phone'
                  : 'We\'ll send you an OTP to verify your phone number',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            // Phone Number Field
            if (!_showOtpField) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: '+91 98765 43210',
                  prefixIcon: const Icon(Icons.phone, color: kPrimaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Send OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
            // OTP Field
            if (_showOtpField) ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimaryColor, width: 2),
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Verify OTP Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Back Button
              TextButton(
                onPressed: !_isLoading
                    ? () {
                        setState(() {
                          _showOtpField = false;
                          _otpController.clear();
                          _verificationId = null;
                          _errorMessage = null;
                        });
                      }
                    : null,
                child: const Text(
                  'Back to Phone Number',
                  style: TextStyle(color: kPrimaryColor),
                ),
              ),
            ],
            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
