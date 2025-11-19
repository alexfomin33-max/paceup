// lib/utils/equipment_date_format.dart

/// ──────────────────────────────────────────────────────────────
/// ФОРМАТТЕР ДАТЫ ДЛЯ СНАРЯЖЕНИЯ: "21 июля 2023 г."
/// ──────────────────────────────────────────────────────────────
/// Форматирует дату в формате, используемом в макете:
/// - "21 июля 2023 г." (с годом)
/// - Если дата null или пустая, возвращает пустую строку
String formatEquipmentDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) {
    return '';
  }

  try {
    // Парсим дату в формате YYYY-MM-DD
    final date = DateTime.parse(dateStr);
    final day = date.day;
    final month = _getMonthNameGenitive(date.month);
    final year = date.year;
    
    return '$day $month $year г.';
  } catch (e) {
    // Если не удалось распарсить, возвращаем исходную строку
    return dateStr;
  }
}

/// ──────────────────────────────────────────────────────────────
/// ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: месяц в родительном падеже (января, февраля...)
/// ──────────────────────────────────────────────────────────────
String _getMonthNameGenitive(int month) {
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}

/// ──────────────────────────────────────────────────────────────
/// ФОРМАТТЕР ДЛЯ ОТОБРАЖЕНИЯ: "В использовании с 21 июля 2023 г."
/// ──────────────────────────────────────────────────────────────
String formatEquipmentDateWithPrefix(String? dateStr) {
  final formatted = formatEquipmentDate(dateStr);
  if (formatted.isEmpty) {
    return 'Дата не указана';
  }
  return 'В использовании с $formatted';
}

