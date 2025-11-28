// lib/models/chat_user.dart
// ────────────────────────────────────────────────────────────────────────────
// Модель пользователя для чатов
// ────────────────────────────────────────────────────────────────────────────

/// Модель пользователя для списка чатов и поиска
class ChatUser {
  final int id;
  final String name;
  final String surname;
  final String fullName;
  final int age;
  final String city;
  final String avatar;

  const ChatUser({
    required this.id,
    required this.name,
    required this.surname,
    required this.fullName,
    required this.age,
    required this.city,
    required this.avatar,
  });

  /// Парсинг из JSON API
  factory ChatUser.fromJson(Map<String, dynamic> j) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s) ?? 0;
    }

    String toStr(dynamic v, [String defaultValue = '']) {
      if (v == null) return defaultValue;
      final s = v.toString().trim();
      return s.isEmpty ? defaultValue : s;
    }

    return ChatUser(
      id: toInt(j['id']),
      name: toStr(j['name'], ''),
      surname: toStr(j['surname'], ''),
      fullName: toStr(j['full_name'], 'Пользователь'),
      age: toInt(j['age']),
      city: toStr(j['city'], ''),
      avatar: toStr(j['avatar'], '1.webp'),
    );
  }
}

