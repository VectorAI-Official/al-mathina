/// Model representing a saved user account
class SavedAccount {
  final String uid;
  final String phoneNumber;

  SavedAccount({
    required this.uid,
    required this.phoneNumber,
  });

  /// Convert SavedAccount to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
    };
  }

  /// Create SavedAccount from JSON
  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      uid: json['uid'] as String,
      phoneNumber: json['phoneNumber'] as String,
    );
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
