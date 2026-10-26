class UserProfile {
  final String id;
  final String email;
  final String username;
  final String? avatarUrl;

  UserProfile({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'],
    );
  }
}
