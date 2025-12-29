class UserProfileHeader {
  final int id;
  final String firstName;
  final String lastName;
  final String? avatar;   // полный URL
  final String? background;   // полный URL фоновой картинки
  final String? city;
  final int? age;
  final int? followers;
  final int? following;
  final String? status;

  const UserProfileHeader({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.background,
    this.city,
    this.age,
    this.followers,
    this.following,
    this.status,
  });

  factory UserProfileHeader.fromJson(Map<String, dynamic> j) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s);
    }

    String? toStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim(); // ← безопасно, т.к. v уже не null
      return s.isEmpty ? null : s;
    }

    final Map<String, dynamic> stats = (j['stats'] is Map)
        ? Map<String, dynamic>.from(j['stats'] as Map)
        : const <String, dynamic>{};

    return UserProfileHeader(
      id: toInt(j['id']) ?? 0,
      firstName: (j['first_name'] ?? '').toString(),
      lastName: (j['last_name'] ?? '').toString(),
      avatar: toStr(j['avatar']),
      background: toStr(j['background']),
      city: toStr(j['city']),
      age: toInt(j['age']),
      followers: toInt(stats['followers']),
      following: toInt(stats['following']),
      status: (j['status'] ?? '').toString(),
    );
  }
}
