// ────────────────────────────────────────────────────────────────────────────
//  EVENT OPTION MODEL
//
//  Модель события для использования в выпадающих списках и поиске
// ────────────────────────────────────────────────────────────────────────────

/// Модель события для выпадающих списков
class EventOption {
  /// ID события
  final int id;

  /// Название события
  final String name;

  /// Место проведения
  final String place;

  /// Дата события
  final String eventDate;

  /// URL изображения события (логотип)
  final String? logoUrl;

  /// Специальный флаг для пункта "Мои"
  final bool isMySlots;

  const EventOption({
    required this.id,
    required this.name,
    required this.place,
    required this.eventDate,
    this.logoUrl,
    this.isMySlots = false,
  });

  /// Создание пункта "Мои"
  factory EventOption.mySlots() {
    return const EventOption(
      id: -1,
      name: 'Мои',
      place: '',
      eventDate: '',
      logoUrl: null,
      isMySlots: true,
    );
  }

  /// Создание из JSON ответа API
  factory EventOption.fromApi(Map<String, dynamic> json) {
    return EventOption(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventOption &&
        other.id == id &&
        other.isMySlots == isMySlots;
  }

  @override
  int get hashCode => Object.hash(id, isMySlots);
}

