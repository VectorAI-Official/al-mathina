import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';

/// Service for managing saved accounts in local storage
class SharedPrefsService {
  static const String _savedAccountsKey = 'saved_accounts';

  /// Save an account to the list (only if not already present)
  static Future<void> saveAccount(SavedAccount account) async {
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('🔵 SharedPrefsService.saveAccount CALLED');
    print('   📥 INPUT: uid=${account.uid}');
    print('   📥 INPUT: phone=${account.phoneNumber}');
    print('   📥 INPUT: storeName=${account.storeName}');
    print('═══════════════════════════════════════════════════════════════');
    
    final prefs = await SharedPreferences.getInstance();
    print('✅ Got SharedPreferences instance');
    
    print('');
    print('🔍 STEP 1: Loading existing accounts...');
    final accounts = await getSavedAccounts();
    print('📚 Current accounts in memory: ${accounts.length}');
    for (int i = 0; i < accounts.length; i++) {
      print('   [$i] uid=${accounts[i].uid}, phone=${accounts[i].phoneNumber}, storeName=${accounts[i].storeName}');
    }

    // Check if account already exists (by uid)
    print('');
    print('🔍 STEP 2: Checking if account exists...');
    final existingIndex = accounts.indexWhere((acc) => acc.uid == account.uid);
    
    if (existingIndex != -1) {
      print('🔄 Account FOUND at index $existingIndex');
      print('   OLD: uid=${accounts[existingIndex].uid}, phone=${accounts[existingIndex].phoneNumber}, storeName=${accounts[existingIndex].storeName}');
      accounts[existingIndex] = account;
      print('   NEW: uid=${accounts[existingIndex].uid}, phone=${accounts[existingIndex].phoneNumber}, storeName=${accounts[existingIndex].storeName}');
    } else {
      print('➕ Account NOT FOUND, adding as new');
      accounts.add(account);
    }
    
    print('');
    print('🔍 STEP 3: Converting to JSON...');
    final jsonList = accounts.map((acc) {
      final json = acc.toJson();
      print('   Converting: ${acc.phoneNumber} -> $json');
      return json;
    }).toList();
    
    final jsonString = jsonEncode(jsonList);
    print('');
    print('🔍 STEP 4: Saving to SharedPreferences...');
    print('📝 FULL JSON STRING TO SAVE:');
    print('$jsonString');
    
    final result = await prefs.setString(_savedAccountsKey, jsonString);
    print('💾 setString() returned: $result');
    
    print('');
    print('🔍 STEP 5: IMMEDIATE VERIFICATION...');
    final verifyString = prefs.getString(_savedAccountsKey);
    print('✅ Data in SharedPreferences RIGHT NOW:');
    print('$verifyString');
    
    if (verifyString == jsonString) {
      print('✅✅✅ VERIFICATION SUCCESS: Data matches!');
    } else {
      print('❌❌❌ VERIFICATION FAILED: Data does NOT match!');
      print('   Expected: $jsonString');
      print('   Got: $verifyString');
    }
    print('═══════════════════════════════════════════════════════════════');
    print('');
  }

  /// Get all saved accounts
  static Future<List<SavedAccount>> getSavedAccounts() async {
    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('🔍 SharedPrefsService.getSavedAccounts CALLED');
    print('═══════════════════════════════════════════════════════════════');
    
    final prefs = await SharedPreferences.getInstance();
    print('✅ Got SharedPreferences instance');
    
    final jsonString = prefs.getString(_savedAccountsKey);
    print('📖 Raw JSON from SharedPreferences:');
    print('$jsonString');
    
    if (jsonString == null || jsonString.isEmpty) {
      print('⚠️ No saved accounts found - returning empty list');
      print('═══════════════════════════════════════════════════════════════');
      return [];
    }

    try {
      print('');
      print('🔍 Parsing JSON...');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      print('✅ Decoded to list with ${jsonList.length} items');
      
      print('');
      print('🔍 Converting each JSON to SavedAccount...');
      final accounts = <SavedAccount>[];
      for (int i = 0; i < jsonList.length; i++) {
        print('   [$i] JSON: ${jsonList[i]}');
        final account = SavedAccount.fromJson(jsonList[i] as Map<String, dynamic>);
        print('   [$i] Result: uid=${account.uid}, phone=${account.phoneNumber}, storeName=${account.storeName}');
        accounts.add(account);
      }
      
      print('');
      print('📋 FINAL RESULT: Loaded ${accounts.length} accounts:');
      for (int i = 0; i < accounts.length; i++) {
        print('   [$i] ${accounts[i].phoneNumber}: storeName=${accounts[i].storeName}');
      }
      print('═══════════════════════════════════════════════════════════════');
      print('');
      
      return accounts;
    } catch (e) {
      print('❌ Error parsing saved accounts: $e');
      print('═══════════════════════════════════════════════════════════════');
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Remove an account by uid
  static Future<void> removeAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();

    accounts.removeWhere((acc) => acc.uid == uid);

    final jsonList = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_savedAccountsKey, jsonEncode(jsonList));
  }

  /// Clear all saved accounts
  static Future<void> clearAllAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedAccountsKey);
  }
}
