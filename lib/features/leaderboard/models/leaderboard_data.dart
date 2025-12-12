// lib/features/leaderboard/models/leaderboard_data.dart
// ─────────────────────────────────────────────────────────────────────────────
// Модели данных и константы для лидерборда
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

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
  final AssetImage avatar;

  const LeaderboardRowData(
    this.rank,
    this.name,
    this.value,
    this.avatar,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//                     ДЕМО-ДАННЫЕ ДЛЯ ТАБЛИЦЫ
// ─────────────────────────────────────────────────────────────────────────────
/// Демо-данные для лидерборда (временно, будет заменено на данные из API)
const kDemoLeaderboardRows = <LeaderboardRowData>[
  LeaderboardRowData(
    1,
    'Алексей Лукашин',
    '272,8',
    AssetImage('assets/avatar_1.png'),
  ),
  LeaderboardRowData(
    2,
    'Татьяна Свиридова',
    '214,7',
    AssetImage('assets/avatar_3.png'),
  ),
  LeaderboardRowData(
    3,
    'Борис Жарких',
    '197,2',
    AssetImage('assets/avatar_2.png'),
  ),
  LeaderboardRowData(
    4,
    'Евгений Бойко',
    '145,8',
    AssetImage('assets/avatar_0.png'),
  ),
  LeaderboardRowData(
    5,
    'Екатерина Виноградова',
    '108,5',
    AssetImage('assets/avatar_4.png'),
  ),
  LeaderboardRowData(
    6,
    'Юрий Селиванов',
    '96,4',
    AssetImage('assets/avatar_5.png'),
  ),
];

