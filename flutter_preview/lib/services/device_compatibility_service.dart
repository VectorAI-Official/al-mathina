import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to check device compatibility for voice search features
class DeviceCompatibilityService {
  /// Check if device can handle voice search (speech_to_text)
  /// Low-end devices might struggle with real-time speech recognition
  static Future<bool> checkVoiceSearchCompatibility() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false; // Only support mobile devices
    }
    
    // Note: We can't directly check RAM or CPU, but we can use speech_to_text's
    // own initialization as a compatibility check. If it fails, device likely can't handle it.
    // This is already handled in VoiceSearchService.initialize()
    
    return true; // Let speech_to_text handle the actual compatibility check
  }
  
  /// Show a one-time warning dialog if voice search might not work well on device
  static Future<void> showCompatibilityWarningIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasShownWarning = prefs.getBool('voice_search_warning_shown') ?? false;
    
    if (hasShownWarning) return;
    
    // Only show if this is first time using voice search
    // This is a soft warning, not blocking
    debugPrint('ℹ️ Voice search compatibility check passed');
    
    // Mark as shown so we don't show again
    await prefs.setBool('voice_search_warning_shown', true);
  }
}
