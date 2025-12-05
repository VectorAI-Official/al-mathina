import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_search_service.dart';
import '../services/device_compatibility_service.dart';

class VoiceSearchDialog extends StatefulWidget {
  final Function(String) onSearchQuery;

  const VoiceSearchDialog({
    Key? key,
    required this.onSearchQuery,
  }) : super(key: key);

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  String _recognizedText = '';
  String _tamilText = '';
  String _englishText = '';
  bool _isListening = false;
  bool _showLanguageOptions = false;
  String _statusMessage = 'Tap the microphone and speak';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    // Check device compatibility first
    await DeviceCompatibilityService.showCompatibilityWarningIfNeeded(context);
    
    final initialized = await VoiceSearchService.initialize();
    if (!initialized && mounted) {
      setState(() {
        _statusMessage = 'Speech recognition not available';
      });
      // Show user-friendly message for incompatible devices
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice search is not supported on this device'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Check if Tamil is available and prompt installation if needed (only once per app install)
    final prefs = await SharedPreferences.getInstance();
    final hasInstalledTamil = prefs.getBool('tamil_installed') ?? false;
    final hasSkippedTamil = prefs.getBool('tamil_skipped') ?? false;
    
    if (!hasInstalledTamil && !hasSkippedTamil) {
      final tamilAvailable = await VoiceSearchService.isTamilAvailable();
      if (!tamilAvailable && mounted) {
        final shouldOpenSettings = await _showTamilInstallDialog();
        if (shouldOpenSettings) {
          await _openLanguageSettings();
          // Wait for user to return from settings
          await Future.delayed(const Duration(seconds: 1));
          // Recheck if Tamil was installed
          final nowAvailable = await VoiceSearchService.isTamilAvailable();
          if (nowAvailable) {
            await prefs.setBool('tamil_installed', true);
            await prefs.setBool('tamil_skipped', false);
          }
        } else {
          // User clicked Skip - remember this choice
          await prefs.setBool('tamil_skipped', true);
        }
      } else if (tamilAvailable) {
        await prefs.setBool('tamil_installed', true);
        await prefs.setBool('tamil_skipped', false);
      }
    }
    
    // Auto-start listening when dialog opens
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startListening();
      }
    });
  }
  
  Future<void> _openLanguageSettings() async {
    if (Platform.isAndroid) {
      try {
        const intent = AndroidIntent(
          action: 'android.settings.LOCALE_SETTINGS',
        );
        await intent.launch();
        debugPrint('✅ Opened Language Settings');
      } catch (e) {
        debugPrint('❌ Could not open settings: $e');
      }
    }
  }
  
  Future<bool> _checkTamilStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final installed = prefs.getBool('tamil_installed') ?? false;
    if (installed) return true;
    
    // Recheck if Tamil is now available
    final available = await VoiceSearchService.isTamilAvailable();
    if (available) {
      await prefs.setBool('tamil_installed', true);
      await prefs.setBool('tamil_skipped', false);
    }
    return available;
  }
  
  Future<bool> _showTamilInstallDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.language, color: Color(0xFF66BB6A), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Install Tamil Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(0xFF66BB6A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF66BB6A).withOpacity(0.3), width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.mic, color: Color(0xFF66BB6A), size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Add Tamil (தமிழ்) to enable Tamil voice search',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF004D40),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'English voice search works without Tamil',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Skip',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: Icon(Icons.settings, size: 18),
            label: Text('Install Tamil'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66BB6A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _statusMessage = 'Listening... Speak in Tamil or English';
      _recognizedText = '';
      _showLanguageOptions = false;
      _tamilText = '';
      _englishText = '';
    });

    await VoiceSearchService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
            _statusMessage = 'Listening...';
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            if (_recognizedText.isEmpty) {
              _statusMessage = 'Could not detect speech. Tap mic to try again';
              _showLanguageOptions = false;
            } else {
              // Detect if text contains Tamil or English characters
              final hasTamil = _recognizedText.contains(RegExp(r'[\u0B80-\u0BFF]'));
              final hasEnglish = _recognizedText.contains(RegExp(r'[a-zA-Z]'));
              
              // Set both versions
              if (hasTamil) {
                _tamilText = _recognizedText;
                _englishText = _recognizedText; // Same for now, user will pick
              } else if (hasEnglish) {
                _englishText = _recognizedText;
                _tamilText = _recognizedText; // Same for now, user will pick
              } else {
                // Unknown language - treat as English
                _englishText = _recognizedText;
                _tamilText = _recognizedText;
              }
              
              _statusMessage = 'Which language did you speak?';
              _showLanguageOptions = true;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _showLanguageOptions = false;
            if (error.contains('no_match') || error.contains('No speech')) {
              _statusMessage = 'Could not detect speech. Tap mic to try again';
            } else if (error.contains('permission')) {
              _statusMessage = 'Microphone permission required';
            } else {
              _statusMessage = 'Error occurred. Tap mic to try again';
            }
          });
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await VoiceSearchService.stopListening();
    setState(() {
      _isListening = false;
      _statusMessage = _recognizedText.isEmpty
          ? 'No speech detected'
          : 'Tap search to continue';
    });
  }

  void _performSearch() {
    if (_recognizedText.trim().isNotEmpty) {
      widget.onSearchQuery(_recognizedText.trim());
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    VoiceSearchService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F5F5),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voice Search',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Animated Microphone
            GestureDetector(
              onTap: _isListening ? _stopListening : _startListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulsing circles (only when listening)
                  if (_isListening) ...[
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(150, 150),
                          painter: SoundWavePainter(
                            animation: _animationController,
                            color: const Color(0xFF66BB6A),
                          ),
                        );
                      },
                    ),
                  ],

                  // Mic button
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isListening
                            ? [
                                const Color(0xFF66BB6A),
                                const Color(0xFF4CAF50),
                              ]
                            : [
                                const Color(0xFF81C784),
                                const Color(0xFF66BB6A),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF66BB6A).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status Message
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Helpful tip
            if (!_isListening && _recognizedText.isEmpty)
              Text(
                'Speak clearly in Tamil or English',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),

            // Recognized Text - Only show when NOT showing language options
            if (!_showLanguageOptions)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isListening ? const Color(0xFF66BB6A) : Colors.grey[300]!,
                    width: _isListening ? 2 : 1,
                  ),
                  boxShadow: _isListening ? [
                    BoxShadow(
                      color: const Color(0xFF66BB6A).withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : [],
                ),
                constraints: const BoxConstraints(minHeight: 80),
                child: Column(
                  children: [
                    if (_recognizedText.isEmpty && _isListening)
                      const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.grey,
                          fontWeight: FontWeight.w300,
                        ),
                      )
                    else
                      Text(
                        _recognizedText.isEmpty
                            ? 'Tap mic and speak...'
                            : _recognizedText,
                        style: TextStyle(
                          fontSize: _recognizedText.isEmpty ? 16 : 20,
                          color: _recognizedText.isEmpty
                              ? Colors.grey[400]
                              : Colors.black87,
                          height: 1.4,
                          fontWeight: _recognizedText.isEmpty 
                              ? FontWeight.normal 
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Language Selection Buttons - Show after recognition
            if (_showLanguageOptions && _recognizedText.isNotEmpty) ...[
              const Text(
                'Select your language:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              // English Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onSearchQuery(_englishText.trim());
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.language, color: Colors.white),
                  label: Text(
                    'English: $_englishText',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A), // Green like cart
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Tamil Button - Show 'Allow' if not installed, otherwise show recognized text
              FutureBuilder<bool>(
                future: _checkTamilStatus(),
                builder: (context, snapshot) {
                  final tamilInstalled = snapshot.data ?? false;
                  
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (!tamilInstalled) {
                          // Show installation dialog again
                          Navigator.of(context).pop();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('tamil_skipped', false);
                          await _openLanguageSettings();
                        } else {
                          widget.onSearchQuery(_tamilText.trim());
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(
                        tamilInstalled ? Icons.record_voice_over : Icons.language,
                        color: Colors.white,
                      ),
                      label: Text(
                        tamilInstalled ? 'தமிழ்: $_tamilText' : 'தமிழ்: Allow',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF66BB6A), // Green like cart
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  );
                },
              ),
            ],

            // Action Buttons - Only show retry when needed
            if (!_isListening && _recognizedText.isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startListening,
                  icon: const Icon(Icons.mic),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF66BB6A),
                    side: const BorderSide(color: Color(0xFF66BB6A), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for sound wave animation
class SoundWavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  SoundWavePainter({
    required this.animation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw 3 expanding circles
    for (int i = 0; i < 3; i++) {
      final t = (animation.value + (i * 0.33)) % 1.0;
      final radius = size.width / 2 * t;
      final opacity = 1.0 - t;

      paint.color = color.withOpacity(opacity * 0.5);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(SoundWavePainter oldDelegate) => true;
}
