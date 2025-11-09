import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/phone_auth_service.dart';
import '../main.dart' show MainScreen, mainScreenKey, AppProvider;

const kPrimaryColor = Color(0xFF66BB6A);

class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const PhoneAuthScreen({
    this.onAuthSuccess,
    Key? key,
  }) : super(key: key);

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> with CodeAutoFill {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  String _otpCode = '';
  
  bool _isLoading = false;
  bool _showOtpField = false;
  String? _verificationId;
  String? _errorMessage;
  String? _appSignature;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getAppSignature();
    listenForCode();
  }

  @override
  void codeUpdated() {
    if (code != null && code!.length == 6) {
      // Schedule for after the current frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _otpCode = code!;
          });
          // Auto-verify OTP when received
          _verifyOTP();
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpFocusNode.dispose();
    cancel();
    super.dispose();
  }

  Future<void> _getAppSignature() async {
    try {
      _appSignature = await SmsAutoFill().getAppSignature;
      print('App Signature: $_appSignature');
    } catch (e) {
      print('Error getting app signature: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // Request SMS permission for auto-fill
    if (await Permission.sms.isDenied) {
      await Permission.sms.request();
    }

    // Request phone permission for reading phone state
    if (await Permission.phone.isDenied) {
      await Permission.phone.request();
    }

    // Request notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Format phone number to E.164 format (+91XXXXXXXXXX)
  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading 0 if present
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    // Add +91 country code
    return '+91$cleanPhone';
  }

  /// Send OTP (triggered automatically when 10 digits entered)
  Future<void> _sendOTP() async {
    // SOLUTION: Clear any stale or corrupted user session before sending OTP
    // This ensures a fresh authentication flow every time
    await FirebaseAuth.instance.signOut();
    
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    String phone = _phoneController.text.trim();
    
    if (phone.length != 10) {
      setState(() => _errorMessage = appProvider.text('please_enter_10_digit'));
      return;
    }

    String formattedPhone = _formatPhoneNumber(phone);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await PhoneAuthService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        onCodeSent: (verificationId) async {
          if (mounted) {
            setState(() {
              _showOtpField = true;
              _verificationId = verificationId;
              _isLoading = false;
            });
            
            // Start listening for SMS
            await SmsAutoFill().listenForCode;
            
            // Request focus on OTP field after a short delay to ensure widget is built
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _otpFocusNode.canRequestFocus) {
                _otpFocusNode.requestFocus();
              }
            });
          }
        },
        onVerificationFailed: (exception) {
          if (mounted) {
            final appProvider = Provider.of<AppProvider>(context, listen: false);
            String errorMsg = appProvider.text('verification_failed');
            if (exception.code == 'invalid-phone-number') {
              errorMsg = appProvider.text('invalid_phone_number');
            } else if (exception.code == 'too-many-requests') {
              errorMsg = appProvider.text('too_many_attempts');
            } else if (exception.code == 'quota-exceeded') {
              errorMsg = appProvider.text('sms_quota_exceeded');
            } else if (exception.message != null) {
              errorMsg = exception.message!;
            }
            
            setState(() {
              _isLoading = false;
              _errorMessage = errorMsg;
            });
          }
        },
        onVerificationCompleted: (credential) async {
          // Auto sign-in on instant verification
          try {
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              await _saveUserAndNavigate(userCredential.user?.phoneNumber ?? formattedPhone);
            }
          } catch (e) {
            if (mounted) {
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              setState(() => _errorMessage = '${appProvider.text('auto_signin_failed')}: ${e.toString()}');
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

  /// Verify OTP (triggered automatically when 6 digits entered or manually)
  Future<void> _verifyOTP() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    if (_otpCode.length != 6) {
      setState(() => _errorMessage = appProvider.text('enter_6_digit_otp'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await PhoneAuthService.signInWithOTP(
        otp: _otpCode,
        verificationId: _verificationId,
      );

      if (mounted && userCredential != null) {
        await _saveUserAndNavigate(
          userCredential.user?.phoneNumber ?? _formatPhoneNumber(_phoneController.text),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        setState(() {
          _isLoading = false;
          _otpCode = ''; // Clear OTP on error
          
          if (e.code == 'invalid-verification-code') {
            _errorMessage = appProvider.text('invalid_otp');
          } else if (e.code == 'session-expired') {
            _errorMessage = appProvider.text('otp_expired');
          } else {
            _errorMessage = e.message ?? appProvider.text('verification_failed');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        setState(() {
          _isLoading = false;
          _otpCode = '';
          _errorMessage = appProvider.text('connection_error');
        });
      }
    }
  }

  Future<void> _saveUserAndNavigate(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOldUser', true);
    await prefs.setString('userPhone', phoneNumber);
    
    widget.onAuthSuccess?.call();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainScreen(key: mainScreenKey),
        ),
        (route) => false,
      );
    }
  }

  void _backToPhoneInput() {
    setState(() {
      _showOtpField = false;
      _otpCode = '';
      _verificationId = null;
      _errorMessage = null;
    });
    cancel(); // Stop listening for SMS
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Language Switcher (Top Right)
                  Align(
                    alignment: Alignment.topRight,
                    child: _buildLanguageSwitcher(appProvider),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // App Title - "Al-Mathina" on top, "Traders" below
                  Column(
                    children: [
                      Text(
                        appProvider.text('al_mathina'),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        appProvider.text('traders'),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _showOtpField ? appProvider.text('enter_otp') : appProvider.text('welcome_back'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Phone Input or OTP Input
                  if (!_showOtpField) ...[
                    _buildPhoneInput(appProvider),
                  ] else ...[
                    _buildOtpInput(appProvider),
                  ],
                  
                  const SizedBox(height: 20),              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
                  // Back Button (only in OTP view)
                  if (_showOtpField && !_isLoading) ...[
                    TextButton.icon(
                      onPressed: _backToPhoneInput,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(appProvider.text('change_phone_number')),
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Loading Indicator
                  if (_isLoading)
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhoneInput(AppProvider appProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appProvider.text('phone_number'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              // Country Code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
              ),
              
              // Phone Input
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_isLoading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: appProvider.text('enter_the_number'),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  onChanged: (value) {
                    // Auto-trigger login when 10 digits entered
                    if (value.length == 10 && !_isLoading) {
                      // Schedule for after the current frame to avoid setState during build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _sendOTP();
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput(AppProvider appProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appProvider.text('enter_6_digit_otp'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        
        PinFieldAutoFill(
          focusNode: _otpFocusNode,
          autoFocus: true,
          codeLength: 6,
          decoration: BoxLooseDecoration(
            strokeColorBuilder: FixedColorBuilder(
              _errorMessage != null ? Colors.red : kPrimaryColor,
            ),
            bgColorBuilder: FixedColorBuilder(Colors.grey[50]!),
            radius: const Radius.circular(12),
            strokeWidth: 2,
            gapSpace: 12,
          ),
          currentCode: _otpCode,
          onCodeChanged: (code) {
            // Defer state updates to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _otpCode = code ?? '';
                _errorMessage = null;
              });
              // Auto-verify when 6 digits entered
              if (code != null && code.length == 6 && !_isLoading) {
                _verifyOTP();
              }
            });
          },
          onCodeSubmitted: (code) {
            // Defer to after frame to prevent setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _otpCode = code;
              });
              _verifyOTP();
            });
          },
        ),
        
        const SizedBox(height: 16),
        
        Center(
          child: Text(
            '${appProvider.text('otp_sent_to')} +91 ${_phoneController.text}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSwitcher(AppProvider appProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageButton('English', 'en', appProvider),
          const SizedBox(width: 4),
          _buildLanguageButton('தமிழ்', 'ta', appProvider),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(String label, String langCode, AppProvider appProvider) {
    bool isSelected = appProvider.currentLanguage == langCode;
    return GestureDetector(
      onTap: () {
        appProvider.setLanguage(langCode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : kPrimaryColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
