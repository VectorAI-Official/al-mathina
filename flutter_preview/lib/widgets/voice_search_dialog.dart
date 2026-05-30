import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_search_service.dart';
import '../services/device_compatibility_service.dart';

class VoiceSearchDialog extends StatefulWidget {
  final Function(String) onSearchQuery;
  final String currentLanguage;

  const VoiceSearchDialog({
    Key? key,
    required this.onSearchQuery,
    this.currentLanguage = 'en',
  }) : super(key: key);

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog>
    with SingleTickerProviderStateMixin {
  String _recognizedText = '';
  bool _isListening = false;
  String _statusMessage = '';
  late AnimationController _animationController;

  // Bilingual translations
  final Map<String, Map<String, String>> _translations = {
    'en': {
      'title': 'Voice Search',
      'subtitle': 'Tamil only',
      'tapMic': 'Tap the microphone and speak',
      'listening': 'Listening... Speak in Tamil',
      'noSpeech': 'No speech detected. Try again',
      'readyToSearch': 'Ready to search',
      'micPermission': 'Microphone permission required',
      'error': 'Error occurred. Try again',
      'speakClearly': 'Speak clearly in Tamil',
      'tapAndSpeak': 'Tap mic and speak...',
      'tryAgain': 'Try Again',
      'search': 'Search',
    },
    'ta': {
      'title': 'குரல் தேடல்',
      'subtitle': 'தமிழ் மட்டும்',
      'tapMic': 'மைக்கைத் தட்டி பேசுங்கள்',
      'listening': 'கேட்கிறது... தமிழில் பேசுங்கள்',
      'noSpeech': 'பேச்சு இல்லை. மீண்டும் முயற்சிக்கவும்',
      'readyToSearch': 'தேடலுக்கு தயார்',
      'micPermission': 'மைக் அனுமதி தேவை',
      'error': 'பிழை. மீண்டும் முயற்சிக்கவும்',
      'speakClearly': 'தெளிவாக பேசுங்கள்',
      'tapAndSpeak': 'மைக் தட்டி பேசுங்கள்...',
      'tryAgain': 'மீண்டும் முயற்சிக்கவும்',
      'search': 'தேடுக',
    },
  };

  String _t(String key) => _translations[widget.currentLanguage]?[key] ?? _translations['en']![key]!;

  @override
  void initState() {
    super.initState();
    _statusMessage = _t('tapMic');
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
    
    // Auto-start listening when dialog opens
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startListening();
      }
    });
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _statusMessage = _t('listening');
      _recognizedText = '';
    });

    await VoiceSearchService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
            _statusMessage = _t('listening');
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            if (_recognizedText.isEmpty) {
              _statusMessage = _t('noSpeech');
            } else {
              // Show search button
              _statusMessage = _t('readyToSearch');
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            if (error.contains('no_match') || error.contains('No speech')) {
              _statusMessage = _t('noSpeech');
            } else if (error.contains('permission')) {
              _statusMessage = _t('micPermission');
            } else {
              _statusMessage = _t('error');
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
          ? _t('noSpeech')
          : _t('readyToSearch');
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t('subtitle'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF66BB6A),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Helpful tip
            if (!_isListening && _recognizedText.isEmpty)
              Text(
                _t('speakClearly'),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 16),

            // Recognized Text
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
                          ? _t('tapAndSpeak')
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
            const SizedBox(height: 16),

            // Search Button - Show when text is recognized
            if (_recognizedText.isNotEmpty && !_isListening)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_recognizedText.trim().isNotEmpty) {
                      final query = _recognizedText.trim();
                      Navigator.of(context).pop(); // Close dialog first
                      widget.onSearchQuery(query); // Then trigger search
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: Text(_t('search')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // Action Buttons - Only show retry when needed
            if (!_isListening && _recognizedText.isEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _startListening,
                  icon: const Icon(Icons.mic),
                  label: Text(_t('tryAgain')),
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
