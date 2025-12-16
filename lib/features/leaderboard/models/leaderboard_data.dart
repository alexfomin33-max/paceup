// lib/features/leaderboard/models/leaderboard_data.dart
// ─────────────────────────────────────────────────────────────────────────────
// Модели данных и константы для лидерборда
// ─────────────────────────────────────────────────────────────────────────────

// ── Параметры статистики для выпадающего списка
const kLeaderboardParameters = [
  'Расстояние',
  'Тренировок',
  'Общее время',
  'Набор высоты',
  'Средний темп',
  'Средний пульс',
];

// ── Периоды для выпадающего списка
const kPeriods = [
  'Текущая неделя',
  'Текущий месяц',
  'Текущий год',
  'Выбранный период',
];

// ─────────────────────────────────────────────────────────────────────────────
//                     МОДЕЛЬ ДАННЫХ СТРОКИ ЛИДЕРБОРДА
// ─────────────────────────────────────────────────────────────────────────────
/// Модель данных для строки лидерборда
class LeaderboardRowData {
  final int rank;
  final String name;
  final String value;
  final String avatarUrl; // URL аватарки
  final int? userId; // ID пользователя для выделения текущего пользователя

  const LeaderboardRowData({
    required this.rank,
    required this.name,
    required this.value,
    required this.avatarUrl,
    this.userId,
  });

  /// Создает из JSON ответа API
  factory LeaderboardRowData.fromJson(Map<String, dynamic> json) {
    return LeaderboardRowData(
      rank: json['rank'] as int,
      name: json['name'] as String,
      // ── Принудительно форматируем значение с двумя знаками после запятой
      // ── Даже если вторая цифра ноль (пример: 142,90), сохраняем его
      value: _formatValue(
        json['distance_formatted'] as String? ??
            (json['value'] as String? ?? '0,0'),
      ),
      avatarUrl: json['avatar_url'] as String,
      userId: json['user_id'] as int?,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //                     ФОРМАТИРОВАНИЕ ЗНАЧЕНИЙ
  // ─────────────────────────────────────────────────────────────────────────────
  /// Приводит строку числа к виду с двумя знаками после запятой
  /// и запятой в качестве разделителя десятичной части.
  static String _formatValue(String raw) {
    final normalized = raw.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);

    if (parsed == null) {
      // ── Если распарсить не удалось, возвращаем исходное,
      // ── но заменяем точку на запятую для единообразия
      return raw.contains(',') ? raw : raw.replaceAll('.', ',');
    }

    final fixed = parsed.toStringAsFixed(2); // всегда 2 знака после запятой
    final withComma = fixed.replaceAll('.', ',');

    // ── Добавляем пробелы как разделители тысяч в целой части
    final parts = withComma.split(',');
    final integerPart = parts[0];
    final fractionPart = parts.length > 1 ? parts[1] : '00';

    final buffer = StringBuffer();
    final length = integerPart.length;
    for (var i = 0; i < length; i++) {
      buffer.write(integerPart[i]);
      final remaining = length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(' ');
      }
    }

    return '${buffer.toString()},$fractionPart';
  }
}
