import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';
import '../services/shared_prefs_service.dart';
import '../screens/phone_auth_screen.dart';

class AccountSwitcherPage extends StatefulWidget {
  const AccountSwitcherPage({Key? key}) : super(key: key);

  @override
  State<AccountSwitcherPage> createState() => _AccountSwitcherPageState();
}

class _AccountSwitcherPageState extends State<AccountSwitcherPage> {
  List<SavedAccount> _savedAccounts = [];
  bool _isLoading = true;
  String? _currentUserUid;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    
    try {
      final accounts = await SharedPrefsService.getSavedAccounts();
      final prefs = await SharedPreferences.getInstance();
      final currentPhone = prefs.getString('userPhone');
      
      // Find current user UID from phone number
      String? currentUid;
      if (currentPhone != null) {
        final currentAccount = accounts.firstWhere(
          (acc) => acc.phoneNumber == currentPhone,
          orElse: () => SavedAccount(uid: '', phoneNumber: ''),
        );
        currentUid = currentAccount.uid.isNotEmpty ? currentAccount.uid : null;
      }
      
      setState(() {
        _savedAccounts = accounts;
        _currentUserUid = currentUid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading accounts: $e')),
        );
      }
    }
  }

  Future<void> _switchAccount(SavedAccount account) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Clear current user session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userPhone');
      await prefs.remove('isOldUser');
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Navigate to PhoneAuthScreen with pre-filled phone number
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => PhoneAuthScreenWithPrefilledPhone(
              phoneNumber: account.phoneNumber,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error switching account: $e')),
        );
      }
    }
  }

  Future<void> _removeAccount(SavedAccount account) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: Text('Remove ${account.phoneNumber} from saved accounts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SharedPrefsService.removeAccount(account.uid);
      await _loadAccounts(); // Refresh the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account removed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch Account'),
        backgroundColor: const Color(0xFF66BB6A),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedAccounts.isEmpty
              ? const Center(
                  child: Text(
                    'No saved accounts',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _savedAccounts.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final account = _savedAccounts[index];
                    final isCurrentUser = account.uid == _currentUserUid;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF66BB6A),
                          child: Text(
                            account.phoneNumber.substring(
                              account.phoneNumber.length - 2,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          account.phoneNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: isCurrentUser
                            ? const Text(
                                'Current Account',
                                style: TextStyle(
                                  color: Color(0xFF66BB6A),
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : null,
                        trailing: isCurrentUser
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF66BB6A),
                              )
                            : IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _removeAccount(account),
                                tooltip: 'Remove account',
                              ),
                        onTap: isCurrentUser
                            ? null
                            : () => _switchAccount(account),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Wrapper widget for PhoneAuthScreen with pre-filled phone number
/// This allows us to pass the phone number to pre-fill
class PhoneAuthScreenWithPrefilledPhone extends StatefulWidget {
  final String phoneNumber;

  const PhoneAuthScreenWithPrefilledPhone({
    required this.phoneNumber,
    Key? key,
  }) : super(key: key);

  @override
  State<PhoneAuthScreenWithPrefilledPhone> createState() =>
      _PhoneAuthScreenWithPrefilledPhoneState();
}

class _PhoneAuthScreenWithPrefilledPhoneState
    extends State<PhoneAuthScreenWithPrefilledPhone> {
  @override
  Widget build(BuildContext context) {
    // Return the regular PhoneAuthScreen
    // You'll need to modify PhoneAuthScreen to accept an optional initialPhoneNumber parameter
    // For now, this is a placeholder that shows how it should work
    return const PhoneAuthScreen();
    
    // After you modify PhoneAuthScreen to accept initialPhoneNumber:
    // return PhoneAuthScreen(initialPhoneNumber: widget.phoneNumber);
  }
}
