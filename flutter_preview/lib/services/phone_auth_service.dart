import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PhoneAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store verification ID for later use
  static String? _verificationId;
  static String? _resendToken;

  // Callbacks for UI updates
  static Function(String)? onCodeSent;
  static Function(String)? onVerificationFailed;
  static Function()? onVerificationCompleted;

  /// Send OTP to phone number
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Duration timeout,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseException exception) onVerificationFailed,
    required Function(PhoneAuthCredential credential) onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _verificationId = credential.verificationId;
          onVerificationCompleted(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            print('Phone verification failed: ${e.code}');
            print('Message: ${e.message}');
          }
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendTokenId) {
          _verificationId = verificationId;
          _resendToken = resendTokenId?.toString();
          onCodeSent(verificationId);
          if (kDebugMode) {
            print('OTP sent to $phoneNumber');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (kDebugMode) {
            print('Auto-retrieval timeout for $phoneNumber');
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Firebase Auth Exception: ${e.code} - ${e.message}');
      }
      onVerificationFailed(e);
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
      onVerificationFailed(FirebaseAuthException(code: 'unknown_error', message: '$e'));
      rethrow;
    }
  }

  /// Sign in with OTP code
  static Future<UserCredential?> signInWithOTP({
    required String otp,
    required String? verificationId,
  }) async {
    try {
      // Use provided verificationId or stored one
      final verId = verificationId ?? _verificationId;

      if (verId == null) {
        throw FirebaseAuthException(
          code: 'missing_verification_id',
          message: 'Verification ID is missing. Please request OTP first.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verId,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (kDebugMode) {
        print('User signed in: ${userCredential.user?.phoneNumber}');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Firebase Auth Exception during sign-in: ${e.code}');
        print('Message: ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected error during sign-in: $e');
      }
      rethrow;
    }
  }

  /// Check if user is currently signed in
  static bool isSignedIn() {
    return _auth.currentUser != null;
  }

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Get current user's phone number
  static String? getCurrentUserPhone() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      _verificationId = null;
      _resendToken = null;
      if (kDebugMode) {
        print('User signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
      rethrow;
    }
  }

  /// Disable app verification (for testing only)
  static void disableAppVerification() {
    _auth.firebaseAuthSettings.appVerificationDisabledForTesting = true;
  }

  /// Enable app verification (for production)
  static void enableAppVerification() {
    _auth.firebaseAuthSettings.appVerificationDisabledForTesting = false;
  }

  /// Force reCAPTCHA flow (for testing)
  static void forceRecaptchaFlow() {
    _auth.firebaseAuthSettings.forceRecaptchaFlowForTesting = true;
  }

  /// Set language code for SMS
  static void setLanguageCode(String languageCode) {
    _auth.setLanguageCode(languageCode);
  }

  /// Use app language for SMS
  static void useAppLanguage() {
    _auth.useAppLanguage();
  }
}
