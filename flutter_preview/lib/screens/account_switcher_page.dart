import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';
import '../services/shared_prefs_service.dart';
import '../screens/phone_auth_screen.dart';
import '../api_service.dart';

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
    print('');
    print('███████████████████████████████████████████████████████████████');
    print('🚀 ACCOUNT SWITCHER: _loadAccounts() STARTED');
    print('███████████████████████████████████████████████████████████████');
    
    setState(() => _isLoading = true);
    
    try {
      // Get preferences
      print('');
      print('📋 PHASE 1: Loading SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final currentPhone = prefs.getString('userPhone');
      final currentStoreName = prefs.getString('userStoreName');
      
      print('✅ SharedPreferences loaded:');
      print('   📱 userPhone: $currentPhone');
      print('   🏪 userStoreName: $currentStoreName');
      
      // Check raw JSON first to see if migration needed
      print('');
      print('📋 PHASE 2: Checking if migration needed...');
      final rawJson = prefs.getString('saved_accounts');
      print('📖 Raw saved_accounts: $rawJson');
      
      // Simple check: if JSON doesn't contain "storeName" string, we need to migrate
      final needsMigration = rawJson != null && !rawJson.contains('storeName');
      print('🔍 needsMigration = $needsMigration');
      
      List<SavedAccount> accounts;
      
      if (needsMigration) {
        print('');
        print('🔨🔨🔨 MIGRATION REQUIRED: Old format detected 🔨🔨🔨');
        print('🔨 Old format does not have storeName field');
        
        // Load accounts to get phone numbers
        print('');
        print('📋 PHASE 3: Loading old accounts for phone numbers...');
        final oldAccounts = await SharedPrefsService.getSavedAccounts();
        print('✅ Loaded ${oldAccounts.length} old accounts');
        
        // Extract phone numbers
        final phoneNumbers = oldAccounts.map((acc) => acc.phoneNumber).toList();
        print('📞 Phone numbers to migrate: $phoneNumbers');
        
        // CRITICAL: Clear old data COMPLETELY before rebuilding
        print('');
        print('🗑️🗑️🗑️ CLEARING ALL OLD DATA 🗑️🗑️🗑️');
        final removed = await prefs.remove('saved_accounts');
        print('🗑️ remove() returned: $removed');
        
        // Force commit by getting instance again
        await prefs.reload();
        print('🔄 Called prefs.reload() to force refresh');
        
        final verifyCleared = prefs.getString('saved_accounts');
        print('🗑️ Verify cleared - saved_accounts is now: $verifyCleared');
        
        // NOW rebuild from scratch with NEW storage
        print('');
        print('🔨 REBUILDING: Processing ${phoneNumbers.length} accounts with NEW format...');
        accounts = [];
        
        for (int i = 0; i < phoneNumbers.length; i++) {
          final phoneNumber = phoneNumbers[i];
          final uid = 'user_${phoneNumber.replaceAll('+', '')}';
          
          print('');
          print('──────────────────────────────────────────────────────────');
          print('🔄 Processing account ${i + 1}/${phoneNumbers.length}');
          print('   Phone: $phoneNumber');
          print('   UID: $uid');
          print('──────────────────────────────────────────────────────────');
          
          // If this is current user and we have store name cached, use it
          if (phoneNumber == currentPhone && currentStoreName != null && currentStoreName.isNotEmpty) {
            print('💾 This is CURRENT USER - using cached store name');
            print('   Cached storeName: $currentStoreName');
            
            final account = SavedAccount(
              uid: uid,
              phoneNumber: phoneNumber,
              storeName: currentStoreName,
            );
            print('✅ Created SavedAccount: ${account.toJson()}');
            accounts.add(account);
            
            print('💾 Calling SharedPrefsService.saveAccount()...');
            await SharedPrefsService.saveAccount(account);
            print('✅ saveAccount() completed');
            
            // Verify it was saved with storeName
            await prefs.reload();
            final checkJson = prefs.getString('saved_accounts');
            print('🔍 After save, saved_accounts contains: $checkJson');
            continue;
          }
          
          // Otherwise fetch from backend
          print('🔍 NOT current user - fetching from backend...');
          try {
            print('📡 Calling ApiService.getStoreDetails($phoneNumber)...');
            final storeDetails = await ApiService.getStoreDetails(phoneNumber);
            print('📡 API Response: $storeDetails');
            
            final storeName = storeDetails['store_name']?.toString();
            print('📦 Extracted store_name: $storeName');
            
            final account = SavedAccount(
              uid: uid,
              phoneNumber: phoneNumber,
              storeName: storeName,
            );
            print('✅ Created SavedAccount: ${account.toJson()}');
            accounts.add(account);
            
            print('💾 Calling SharedPrefsService.saveAccount()...');
            await SharedPrefsService.saveAccount(account);
            print('✅ saveAccount() completed');
            
            // Verify it was saved with storeName
            await prefs.reload();
            final checkJson = prefs.getString('saved_accounts');
            print('🔍 After save, saved_accounts contains: $checkJson');
          } catch (e) {
            print('❌ API FAILED for $phoneNumber: $e');
            // Keep account even if fetch fails
            final account = SavedAccount(
              uid: uid,
              phoneNumber: phoneNumber,
              storeName: null,
            );
            print('⚠️ Created SavedAccount without storeName: ${account.toJson()}');
            accounts.add(account);
            
            print('💾 Calling SharedPrefsService.saveAccount()...');
            await SharedPrefsService.saveAccount(account);
            print('✅ saveAccount() completed');
          }
        }
        
        print('');
        print('✅✅✅ MIGRATION COMPLETE ✅✅✅');
        print('   Migrated ${accounts.length} accounts to new format');
      } else {
        print('');
        print('📋 PHASE 3: Loading accounts (no migration needed)...');
        accounts = await SharedPrefsService.getSavedAccounts();
        print('✅ Loaded ${accounts.length} accounts with new format');
      }
      
      // Verify what was saved
      print('');
      print('📋 PHASE 4: Final verification...');
      final verifyJson = prefs.getString('saved_accounts');
      print('🔍 Current saved_accounts in SharedPrefs:');
      print('$verifyJson');
      
      // Find current user UID
      print('');
      print('📋 PHASE 5: Finding current user UID...');
      String? currentUid;
      if (currentPhone != null) {
        final currentAccount = accounts.firstWhere(
          (acc) => acc.phoneNumber == currentPhone,
          orElse: () => SavedAccount(uid: '', phoneNumber: ''),
        );
        currentUid = currentAccount.uid.isNotEmpty ? currentAccount.uid : null;
        print('✅ Current user UID: $currentUid');
      } else {
        print('⚠️ No current phone - currentUid will be null');
      }
      
      print('');
      print('📋 PHASE 6: Preparing UI display...');
      print('✨ Accounts to display:');
      for (int i = 0; i < accounts.length; i++) {
        print('   [$i] ${accounts[i].phoneNumber} -> storeName: ${accounts[i].storeName}');
      }
      
      print('');
      print('📋 PHASE 7: Calling setState()...');
      setState(() {
        _savedAccounts = accounts;
        _currentUserUid = currentUid;
        _isLoading = false;
      });
      print('✅ setState() completed');
      
      print('');
      print('███████████████████████████████████████████████████████████████');
      print('🎉 ACCOUNT SWITCHER: _loadAccounts() FINISHED SUCCESSFULLY');
      print('███████████████████████████████████████████████████████████████');
      print('');
    } catch (e) {
      print('');
      print('❌❌❌ ERROR IN _loadAccounts() ❌❌❌');
      print('💥 Exception: $e');
      print('💥 Stack trace: ${StackTrace.current}');
      print('███████████████████████████████████████████████████████████████');
      
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading accounts: $e')),
        );
      }
    }
  }

  Future<void> _switchAccount(SavedAccount account) async {
    final switchStartTime = DateTime.now();
    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║         ACCOUNT SWITCH STARTED                            ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('🔄 [SWITCH] Target: ${account.phoneNumber}');
    print('🔄 [SWITCH] Store: ${account.storeName ?? "N/A"}');
    print('');
    
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
      // Step 1: Get current user info
      final step1Start = DateTime.now();
      print('📋 [SWITCH] Step 1/4: Getting current user info...');
      final prefs = await SharedPreferences.getInstance();
      final oldPhone = prefs.getString('userPhone');
      final step1Duration = DateTime.now().difference(step1Start);
      print('   ✅ Current user: ${oldPhone ?? "none"} (${step1Duration.inMilliseconds}ms)');
      
      // Step 2: Clear API cache
      final step2Start = DateTime.now();
      print('\n🗑️  [SWITCH] Step 2/4: Clearing API cache...');
      ApiService.clearCache();
      final step2Duration = DateTime.now().difference(step2Start);
      print('   ✅ Cache cleared (${step2Duration.inMilliseconds}ms)');
      
      // Step 3: Clear user session
      final step3Start = DateTime.now();
      print('\n🧹 [SWITCH] Step 3/4: Clearing user session...');
      await prefs.remove('userPhone');
      await prefs.remove('isOldUser');
      final step3Duration = DateTime.now().difference(step3Start);
      print('   ✅ Session cleared (${step3Duration.inMilliseconds}ms)');
      
      // Step 4: Navigate to login
      final step4Start = DateTime.now();
      print('\n🚀 [SWITCH] Step 4/4: Navigating to login screen...');
      print('   From: ${oldPhone ?? "none"}');
      print('   To: ${account.phoneNumber}');
      
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
      
      final step4Duration = DateTime.now().difference(step4Start);
      final totalDuration = DateTime.now().difference(switchStartTime);
      
      print('   ✅ Navigation initiated (${step4Duration.inMilliseconds}ms)');
      print('');
      print('╔═══════════════════════════════════════════════════════════╗');
      print('║  ACCOUNT SWITCH COMPLETED IN ${totalDuration.inMilliseconds}ms');
      print('╚═══════════════════════════════════════════════════════════╝');
      print('   Step 1 (Get Info):     ${step1Duration.inMilliseconds}ms');
      print('   Step 2 (Clear Cache):  ${step2Duration.inMilliseconds}ms');
      print('   Step 3 (Clear Session): ${step3Duration.inMilliseconds}ms');
      print('   Step 4 (Navigate):     ${step4Duration.inMilliseconds}ms');
      print('   TOTAL:                 ${totalDuration.inMilliseconds}ms');
      print('═══════════════════════════════════════════════════════════\n');
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
        content: Text(
          'Remove ${account.storeName != null && account.storeName!.isNotEmpty ? account.storeName : account.phoneNumber} from saved accounts?'
        ),
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
                    
                    // Debug: Print account details when building UI
                    print('');
                    print('🎨🎨🎨 BUILDING UI FOR ACCOUNT $index 🎨🎨🎨');
                    print('   uid: ${account.uid}');
                    print('   phoneNumber: ${account.phoneNumber}');
                    print('   storeName: ${account.storeName}');
                    print('   isCurrentUser: $isCurrentUser (uid == $_currentUserUid)');
                    print('   Card is ${isCurrentUser ? "DISABLED (current user)" : "ENABLED (can switch)"}');
                    print('🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨');
                    print('');
                    print('   storeName is null: ${account.storeName == null}');
                    print('   storeName is empty: ${account.storeName?.isEmpty}');
                    print('   hasStoreName: ${account.storeName != null && account.storeName!.isNotEmpty}');
                    print('   Will display: ${account.storeName != null && account.storeName!.isNotEmpty ? account.storeName! : account.phoneNumber}');
                    print('🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨🎨');
                    print('');

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
                            account.storeName != null && account.storeName!.isNotEmpty
                                ? account.storeName!.substring(0, 1).toUpperCase()
                                : account.phoneNumber.substring(
                                    account.phoneNumber.length - 2,
                                  ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          account.storeName != null && account.storeName!.isNotEmpty
                              ? account.storeName!
                              : account.phoneNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.phoneNumber,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            if (isCurrentUser)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Current Account',
                                  style: TextStyle(
                                    color: Color(0xFF66BB6A),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                            ? () {
                                print('⚠️ Tapped current user card - ignoring (already logged in as ${account.phoneNumber})');
                              }
                            : () {
                                print('✅ Tapped account card - initiating switch to ${account.phoneNumber}');
                                _switchAccount(account);
                              },
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
