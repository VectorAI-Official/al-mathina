import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';

/// Service for managing saved accounts in local storage
class SharedPrefsService {
  static const String _savedAccountsKey = 'saved_accounts';

  /// Save an account to the list (only if not already present)
  static Future<void> saveAccount(SavedAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();

    // Check if account already exists (by uid)
    final exists = accounts.any((acc) => acc.uid == account.uid);
    if (!exists) {
      accounts.add(account);
      final jsonList = accounts.map((acc) => acc.toJson()).toList();
      await prefs.setString(_savedAccountsKey, jsonEncode(jsonList));
    }
  }

  /// Get all saved accounts
  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_savedAccountsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => SavedAccount.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
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
