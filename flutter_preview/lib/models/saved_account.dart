/// Model representing a saved user account
class SavedAccount {
  final String uid;
  final String phoneNumber;
  final String? storeName;

  SavedAccount({
    required this.uid,
    required this.phoneNumber,
    this.storeName,
  });

  /// Convert SavedAccount to JSON for storage
  Map<String, dynamic> toJson() {
    final json = {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'storeName': storeName,
    };
    print('🔧 SavedAccount.toJson():');
    print('   IN:  uid=$uid, phoneNumber=$phoneNumber, storeName=$storeName');
    print('   OUT: $json');
    return json;
  }

  /// Create SavedAccount from JSON
  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    print('🔧 SavedAccount.fromJson():');
    print('   IN: $json');
    print('   Keys in JSON: ${json.keys.toList()}');
    print('   uid field: ${json['uid']}');
    print('   phoneNumber field: ${json['phoneNumber']}');
    print('   storeName field: ${json['storeName']}');
    
    final account = SavedAccount(
      uid: json['uid'] as String,
      phoneNumber: json['phoneNumber'] as String,
      storeName: json['storeName'] as String?,
    );
    print('   OUT: uid=${account.uid}, phone=${account.phoneNumber}, storeName=${account.storeName}');
    return account;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAccount &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
