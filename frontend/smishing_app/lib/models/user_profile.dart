class UserProfile {
  final String id;
  final String role;
  final String? email;
  final List<SocialAccount> socials;

  const UserProfile({
    required this.id,
    required this.role,
    this.email,
    this.socials = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawSocials = json['socials'];
    final List<SocialAccount> socials = rawSocials is List
        ? rawSocials
            .whereType<Map>()
            .map(
              (item) => SocialAccount.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ),
            )
            .toList()
        : const [];

    return UserProfile(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'USER',
      email: json['email']?.toString(),
      socials: socials,
    );
  }
}

class SocialAccount {
  final String provider;
  final String providerId;

  const SocialAccount({required this.provider, required this.providerId});

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      provider: json['provider']?.toString() ?? '',
      providerId: json['provider_id']?.toString() ?? '',
    );
  }
}
