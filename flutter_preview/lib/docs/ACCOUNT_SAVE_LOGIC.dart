// PART 2: Logic on Successful Login
// 
// Add this import at the top of phone_auth_screen.dart:
// import '../services/shared_prefs_service.dart';
// import '../models/saved_account.dart';
//
// Then modify the _saveUserAndNavigate method to save the account:

Future<void> _saveUserAndNavigate(String phoneNumber) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isOldUser', true);
  await prefs.setString('userPhone', phoneNumber);
  
  // ===== ADD THIS BLOCK TO SAVE THE ACCOUNT =====
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final sharedPrefsService = SharedPrefsService();
    final account = SavedAccount(
      uid: currentUser.uid,
      phoneNumber: phoneNumber,
    );
    await sharedPrefsService.saveAccount(account);
  }
  // ===== END OF BLOCK TO ADD =====
  
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
