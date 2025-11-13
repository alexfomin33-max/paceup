// ────────────────────────────────────────────────────────────────────────────
//  EVENT MODEL
//
//  Модель события для вкладки "Мои события"
// ────────────────────────────────────────────────────────────────────────────

/// Модель события пользователя
class Event {
  /// ID события
  final int id;

  /// Название события
  final String name;

  /// URL логотипа события
  final String? logoUrl;

  /// Отформатированная дата (например, "10 июня 2025")
  final String dateFormatted;

  /// Дата события в формате YYYY-MM-DD
  final String eventDate;

  /// Количество участников
  final int participantsCount;

  /// Место проведения
  final String place;

  const Event({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.dateFormatted,
    required this.eventDate,
    required this.participantsCount,
    required this.place,
  });

  /// Создание из JSON ответа API
  factory Event.fromApi(Map<String, dynamic> json) {
    return Event(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
      dateFormatted: json['date_formatted']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      participantsCount: _asInt(json['participants_count']),
      place: json['place']?.toString() ?? '',
    );
  }

  /// Парсинг даты события в DateTime
  DateTime? get parsedDate {
    try {
      return DateTime.parse(eventDate);
    } catch (_) {
      return null;
    }
  }
}

// ──────────────────────────── УТИЛИТЫ ────────────────────────────

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  if (value is double) return value.toInt();
  return 0;
}

