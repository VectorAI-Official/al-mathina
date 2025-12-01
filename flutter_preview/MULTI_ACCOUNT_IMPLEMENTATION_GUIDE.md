# Multi-Account Management Implementation Guide

## Summary
This guide shows how to add Instagram-style multi-account management to your Flutter app without modifying the core Firebase Phone Authentication logic.

---

## Files Created

1. **lib/models/saved_account.dart** - Model for saved accounts
2. **lib/services/shared_prefs_service.dart** - Service for managing saved accounts
3. **lib/services/account_manager.dart** - "Add Account" functionality
4. **lib/screens/account_switcher_page.dart** - UI for switching accounts

---

## Implementation Steps

### Step 1: Add Imports to phone_auth_screen.dart

At the top of `lib/screens/phone_auth_screen.dart`, add:

```dart
import 'services/shared_prefs_service.dart';
import 'models/saved_account.dart';
```

### Step 2: Modify _saveUserAndNavigate Method

In `lib/screens/phone_auth_screen.dart`, find the `_saveUserAndNavigate` method (around line 250) and add the account saving logic:

**BEFORE:**
```dart
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
```

**AFTER:**
```dart
Future<void> _saveUserAndNavigate(String phoneNumber) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isOldUser', true);
  await prefs.setString('userPhone', phoneNumber);
  
  // ===== SAVE ACCOUNT TO LIST =====
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final sharedPrefsService = SharedPrefsService();
    final account = SavedAccount(
      uid: currentUser.uid,
      phoneNumber: phoneNumber,
    );
    await sharedPrefsService.saveAccount(account);
  }
  // ================================
  
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
```

### Step 3: (Optional) Add Pre-filled Phone Support

To support switching accounts with pre-filled phone numbers, modify `PhoneAuthScreen` to accept an optional parameter:

**Add to PhoneAuthScreen widget:**
```dart
class PhoneAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final String? initialPhoneNumber; // ADD THIS

  const PhoneAuthScreen({
    this.onAuthSuccess,
    this.initialPhoneNumber, // ADD THIS
    Key? key,
  }) : super(key: key);

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}
```

**In _PhoneAuthScreenState initState, add:**
```dart
@override
void initState() {
  super.initState();
  
  // Pre-fill phone number if provided
  if (widget.initialPhoneNumber != null) {
    _phoneController.text = widget.initialPhoneNumber!;
  }
  
  _requestPermissions();
  _getAppSignature();
  listenForCode();
}
```

**Update PhoneAuthScreenWithPrefilledPhone in account_switcher_page.dart:**
```dart
@override
Widget build(BuildContext context) {
  return PhoneAuthScreen(initialPhoneNumber: widget.phoneNumber);
}
```

---

## Usage Examples

### Example 1: Add "Add Account" Button

In your settings or profile screen:

```dart
import 'services/account_manager.dart';

// In your widget build method:
ElevatedButton(
  onPressed: () => onAddAccount(context),
  child: const Text('Add Account'),
)
```

### Example 2: Add "Switch Account" Button

```dart
import 'screens/account_switcher_page.dart';

// In your widget build method:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccountSwitcherPage(),
      ),
    );
  },
  child: const Text('Switch Account'),
)
```

### Example 3: Show Account Switcher in Drawer/Menu

```dart
Drawer(
  child: ListView(
    children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: Color(0xFF66BB6A)),
        child: Text('Al-Mathina', style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: const Text('Switch Account'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AccountSwitcherPage(),
            ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.add),
        title: const Text('Add Account'),
        onTap: () => onAddAccount(context),
      ),
      // ... other menu items
    ],
  ),
)
```

---

## How It Works

### Account Flow

1. **First Login**: User completes phone auth → Account saved to `saved_accounts` list
2. **Add Account**: User clicks "Add Account" → Signs out → Goes to phone auth with empty field
3. **Switch Account**: User selects account → Signs out → Goes to phone auth with pre-filled number

### Data Storage

Accounts are stored in SharedPreferences as JSON:
```json
{
  "saved_accounts": [
    {"uid": "abc123", "phoneNumber": "+911234567890"},
    {"uid": "def456", "phoneNumber": "+919876543210"}
  ]
}
```

### Re-Authentication Requirement

Since Firebase only supports one active session at a time, switching accounts requires:
1. Sign out from current account
2. Navigate to phone auth screen
3. Complete OTP verification for the selected account
4. Account becomes active after successful verification

---

## Important Notes

1. **No Modifications to Core Auth Logic**: Your existing `verifyPhoneNumber`, `signInWithCredential`, and OTP verification logic remain unchanged.

2. **Automatic Account Saving**: Every successful login automatically saves the account to the list (no duplicates).

3. **Current User Indicator**: The AccountSwitcherPage shows which account is currently active.

4. **Remove Accounts**: Users can remove accounts from the list (except the current one) by tapping the X button.

5. **Persistence**: All accounts persist across app restarts via SharedPreferences.

---

## Testing Checklist

- [ ] First login saves account to list
- [ ] Second login with different number adds to list
- [ ] "Add Account" signs out and shows empty phone field
- [ ] "Switch Account" shows list of saved accounts
- [ ] Tapping account signs out and pre-fills phone number
- [ ] Current account is marked in the list
- [ ] Remove account works (except current)
- [ ] Accounts persist after app restart

---

## Troubleshooting

**Issue**: Accounts not saving
- Check that `_saveUserAndNavigate` is being called after successful login
- Verify SharedPreferences permissions

**Issue**: Pre-filled phone not showing
- Ensure you've added `initialPhoneNumber` parameter to PhoneAuthScreen
- Check that phone number format matches what your UI expects

**Issue**: Can't remove current account
- This is by design - users can only remove accounts they're not currently signed into
- To remove current account, switch to another account first

---

## Future Enhancements (Optional)

1. **Profile Pictures**: Add user profile images to SavedAccount model
2. **Last Login Time**: Track when each account was last used
3. **Quick Switch**: Add a quick switch button in the app bar
4. **Account Nicknames**: Let users add custom names to accounts
5. **Biometric Auth**: Add fingerprint/face unlock for switching accounts

---

## Questions?

This implementation adds multi-account management without touching your existing Firebase Phone Auth logic. All modifications are additive only.
