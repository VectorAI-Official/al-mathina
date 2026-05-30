import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/shared_prefs_service.dart';
import '../services/fcm_service.dart';
import '../models/saved_account.dart';
import '../api_service.dart';
import '../main.dart' show MainScreen, mainScreenKey, AppProvider;

const kPrimaryColor = Color(0xFF66BB6A);

class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final bool showCancelButton;
  final String? prefilledPhone;

  const PhoneAuthScreen({
    this.onAuthSuccess,
    this.showCancelButton = false,
    this.prefilledPhone,
    Key? key,
  }) : super(key: key);

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill phone number if provided
    if (widget.prefilledPhone != null) {
      _phoneController.text = widget.prefilledPhone!;
      // Auto-login for account switching
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loginWithPhone();
        }
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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

  /// Login with phone number (no OTP required)
  Future<void> _loginWithPhone() async {
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
      // Simulate a brief delay for better UX (optional)
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        await _saveUserAndNavigate(formattedPhone);
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

  Future<void> _saveUserAndNavigate(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOldUser', true);
    await prefs.setString('userPhone', phoneNumber);
    
    // Generate a simple UID from phone number (since Firebase is removed)
    final uid = 'user_${phoneNumber.replaceAll('+', '')}';
    
    // Fetch store name from backend
    String? storeName;
    try {
      final storeDetails = await ApiService.getStoreDetails(phoneNumber);
      storeName = storeDetails['store_name']?.toString();
      
      // Save store name to SharedPreferences for current user
      if (storeName != null && storeName.trim().isNotEmpty) {
        await prefs.setString('userStoreName', storeName);
        print('💾 Saved store name to SharedPreferences: $storeName');
      }
    } catch (e) {
      print('Could not fetch store name: $e');
    }
    
    // Save account to saved accounts list
    print('');
    print('🔵🔵🔵 ABOUT TO SAVE ACCOUNT TO saved_accounts 🔵🔵🔵');
    print('   uid: $uid');
    print('   phoneNumber: $phoneNumber');
    print('   storeName: $storeName');
    final account = SavedAccount(
      uid: uid,
      phoneNumber: phoneNumber,
      storeName: storeName,
    );
    print('🔵 Created SavedAccount object: ${account.toJson()}');
    print('🔵 Calling SharedPrefsService.saveAccount()...');
    await SharedPrefsService.saveAccount(account);
    print('🔵 SharedPrefsService.saveAccount() completed!');
    print('Account saved: ${account.phoneNumber} (${account.uid}) - ${account.storeName}');
    print('🔵🔵🔵 SAVE ACCOUNT COMPLETE 🔵🔵🔵');
    print('');
    
    // Refresh FCM token after successful login
    print('🔔 Refreshing FCM token for push notifications...');
    await FCMService().refreshToken();
    
    widget.onAuthSuccess?.call();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
        (route) => false,
      );
    }
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
                  
                  // Cancel button and Language Switcher (Top Row)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel button (only show when adding account)
                      if (widget.showCancelButton)
                        IconButton(
                          icon: const Icon(Icons.close, color: kPrimaryColor),
                          tooltip: 'Cancel',
                          onPressed: () {
                            // Check if we can pop
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              // If we can't pop, navigate to MainScreen
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const MainScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        )
                      else
                        const SizedBox(width: 48), // Placeholder for alignment
                      
                      // Language Switcher
                      _buildLanguageSwitcher(appProvider),
                    ],
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
                    appProvider.text('welcome_back'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Phone Input
                  _buildPhoneInput(appProvider),
                  
                  const SizedBox(height: 20),
                  
                  // Error Message
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
                  autofocus: widget.prefilledPhone == null,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: appProvider.text('please_enter_10_digit'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                  onChanged: (value) {
                    // Auto-trigger login when 10 digits entered
                    if (value.length == 10 && !_isLoading) {
                      // Schedule for after the current frame to avoid setState during build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _loginWithPhone();
                        }
                      });
                    }
                    // Clear error when user types
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
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
