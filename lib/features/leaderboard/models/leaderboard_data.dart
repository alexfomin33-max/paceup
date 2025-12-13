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
      value: json['distance_formatted'] as String? ?? 
             (json['value'] as String? ?? '0,0'),
      avatarUrl: json['avatar_url'] as String,
      userId: json['user_id'] as int?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ДЕМО-ДАННЫЕ ДЛЯ ТАБЛИЦЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Демо-данные для лидерборда (временно, будет заменено на данные из API)
/// Примечание: эти данные больше не используются, так как данные загружаются из API
const kDemoLeaderboardRows = <LeaderboardRowData>[
  LeaderboardRowData(
    rank: 1,
    name: 'Алексей Лукашин',
    value: '272,8',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
  LeaderboardRowData(
    rank: 2,
    name: 'Татьяна Свиридова',
    value: '214,7',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
  LeaderboardRowData(
    rank: 3,
    name: 'Борис Жарких',
    value: '197,2',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
  LeaderboardRowData(
    rank: 4,
    name: 'Евгений Бойко',
    value: '145,8',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
  LeaderboardRowData(
    rank: 5,
    name: 'Екатерина Виноградова',
    value: '108,5',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
  LeaderboardRowData(
    rank: 6,
    name: 'Юрий Селиванов',
    value: '96,4',
    avatarUrl: 'http://uploads.paceup.ru/images/users/avatars/def.png',
  ),
];

