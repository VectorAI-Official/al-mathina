import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/phone_auth_screen.dart';

/// Function to handle "Add Account" action
/// Call this from wherever you have the "Add Account" button
Future<void> onAddAccount(BuildContext context) async {
  // Sign out from the current account
  await FirebaseAuth.instance.signOut();
  
  // Navigate to PhoneAuthScreen with an empty phone number
  // This will clear the navigation stack so user can't go back
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const PhoneAuthScreen(),
      ),
      (route) => false, // Remove all previous routes
    );
  }
}

/// Alternative: If you want to keep the navigation stack
/// Use this version instead:
Future<void> onAddAccountKeepStack(BuildContext context) async {
  // Sign out from the current account
  await FirebaseAuth.instance.signOut();
  
  // Navigate to PhoneAuthScreen
  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PhoneAuthScreen(),
      ),
    );
  }
}
