// ────────────────────────────────────────────────────────────────────────────
//  CLUB MODEL
//
//  Модель данных клуба для профиля пользователя
//  Используется для отображения клубов во вкладке "Клубы"
// ────────────────────────────────────────────────────────────────────────────

/// Модель клуба для отображения в профиле
class Club {
  final int id;
  final String name;
  final String? logoUrl;
  final int membersCount;
  final String? city;
  final int userId; // ID создателя клуба
  final bool isOpen; // Открытый или закрытый клуб

  const Club({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.membersCount,
    this.city,
    required this.userId,
    required this.isOpen,
  });

  /// Создание модели из JSON ответа API
  factory Club.fromJson(Map<String, dynamic> j) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s);
    }

    String? toStr(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    bool toBool(dynamic v) {
      if (v == null) return true; // По умолчанию открытый
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is num) return v.toInt() != 0;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1';
    }

    return Club(
      id: toInt(j['id']) ?? 0,
      name: (j['name'] ?? '').toString(),
      logoUrl: toStr(j['logo_url']),
      membersCount: toInt(j['members_count']) ?? 0,
      city: toStr(j['city']),
      userId: toInt(j['user_id']) ?? 0,
      isOpen: toBool(j['is_open']),
    );
  }
}

