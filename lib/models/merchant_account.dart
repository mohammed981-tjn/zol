class MerchantAccount {
  const MerchantAccount({
    required this.name,
    required this.storeName,
    required this.email,
  });

  final String name;
  final String storeName;
  final String email;

  Map<String, dynamic> toJson() => {
    'name': name,
    'storeName': storeName,
    'email': email,
  };

  factory MerchantAccount.fromJson(Map<String, dynamic> json) =>
      MerchantAccount(
        name: json['name'] as String? ?? '',
        storeName: json['storeName'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}
