import 'package:flutter/foundation.dart';

class PhoneAuthService {
  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove +91 country code if present
    String cleaned = phoneNumber.replaceAll('+91', '').replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a 10-digit number
    return cleaned.length == 10 && int.tryParse(cleaned) != null;
  }

  /// Format phone number to E.164 format (+91XXXXXXXXXX)
  static String formatPhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Remove leading 0 if present
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    
    // Add +91 country code
    return '+91$cleaned';
  }

  /// Clean phone number (remove formatting)
  static String cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll('+91', '').replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Generate UID from phone number (since Firebase is removed)
  static String generateUidFromPhone(String phoneNumber) {
    String cleaned = cleanPhoneNumber(phoneNumber);
    return 'user_$cleaned';
  }

  /// Validate and format phone number
  static String? validateAndFormat(String phoneNumber) {
    if (!isValidPhoneNumber(phoneNumber)) {
      return null;
    }
    return formatPhoneNumber(phoneNumber);
  }
}
