import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceSearchService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;

  /// Initialize speech recognition
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('🔴 Speech recognition error: ${error.errorMsg}');
          
          // Don't treat "no match" as a critical error
          if (error.errorMsg.contains('error_no_match')) {
            debugPrint('ℹ️ No speech detected - this is normal');
          }
        },
        onStatus: (status) {
          debugPrint('📡 Speech recognition status: $status');
        },
        debugLogging: true,
      );
      
      if (_isInitialized) {
        debugPrint('✅ Speech recognition initialized successfully');
        
        // Log available locales
        final locales = await _speech.locales();
        debugPrint('🌍 Available locales: ${locales.length}');
        for (var locale in locales) {
          if (locale.localeId.toLowerCase().contains('ta') || 
              locale.localeId.toLowerCase().contains('tamil') ||
              locale.localeId.toLowerCase().contains('en')) {
            debugPrint('   - ${locale.localeId}: ${locale.name}');
          }
        }
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Failed to initialize speech recognition: $e');
      return false;
    }
  }

  /// Check if Tamil language is available for speech recognition
  static Future<bool> isTamilLanguageAvailable() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      final locales = await _speech.locales();
      final hasTamil = locales.any((locale) => 
        locale.localeId.toLowerCase().contains('ta') || 
        locale.localeId.toLowerCase().contains('tamil')
      );
      
      debugPrint('🔍 Tamil language available: $hasTamil');
      return hasTamil;
    } catch (e) {
      debugPrint('❌ Error checking Tamil language: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  static Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Check if Tamil language is available
  static Future<bool> isTamilAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    return locales.any((locale) =>
        locale.localeId.toLowerCase().contains('ta') ||
        locale.localeId.toLowerCase().contains('tamil'));
  }

  /// Get Tamil locale ID
  static Future<String?> getTamilLocaleId() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    final tamilLocale = locales.firstWhere(
      (locale) =>
          locale.localeId.toLowerCase().contains('ta') ||
          locale.localeId.toLowerCase().contains('tamil'),
      orElse: () => locales.first,
    );

    return tamilLocale.localeId;
  }

  /// Start listening for voice input
  static Future<void> startListening({
    required Function(String) onResult,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError('Failed to initialize speech recognition');
        return;
      }
    }

    // Check microphone permission
    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) {
      onError('Microphone permission denied');
      return;
    }

    // TAMIL-ONLY: Force Tamil locale
    const String localeToUse = 'ta-IN'; // Tamil (India) - FORCED
    
    final locales = await _speech.locales();
    debugPrint('🌍 Available locales:');
    for (var locale in locales) {
      debugPrint('   - ${locale.localeId}: ${locale.name}');
    }
    
    debugPrint('🎤 Using locale: $localeToUse');
    debugPrint('🎤 TAMIL-ONLY: Tamil recognition forced');
    debugPrint('🎤 English STT is disabled');

    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint('🎯 Speech result: ${result.recognizedWords} (final: ${result.finalResult})');
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
          
          // Call onComplete when final result is received
          if (result.finalResult) {
            debugPrint('✅ Final result received');
            onComplete();
          }
        },
        localeId: localeToUse, // Tamil-ONLY (forced to ta-IN)
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) {
          debugPrint('🔊 Sound level: $level');
        },
      );
    } catch (e) {
      debugPrint('❌ Error starting speech recognition: $e');
      onError('Error starting speech recognition: $e');
    }
  }

  /// Stop listening
  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// Check if currently listening
  static bool get isListening => _speech.isListening;

  /// Check if speech recognition is available
  static bool get isAvailable => _isInitialized && _speech.isAvailable;
}
