// lib/utils/feed_date.dart
import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────
/// FEED DATE FORMATTER: единый формат даты для ленты
/// ──────────────────────────────────────────────────────────────
/// Правило:
/// 1) Если пришла готовая строка с сервера/модели — используем её.
/// 2) Иначе форматируем локально в стиле ленты:
///    - Сегодня: "Сегодня, HH:mm"
///    - Вчера:  "Вчера, HH:mm"
///    - Иное:   "dd.MM.yyyy, HH:mm"
String formatFeedDateText({
  String? serverText,
  DateTime? date,
  Locale? locale, // на будущее (ru, en и т.п.)
}) {
  // 1) Пробуем серверный/модельный текст
  if (serverText != null && serverText.trim().isNotEmpty) {
    return serverText.trim();
  }

  // 2) Фолбэк — локальное форматирование
  if (date == null) return '';

  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');

  if (d == today) return 'Сегодня, $hh:$mm';
  if (d == yesterday) return 'Вчера, $hh:$mm';

  final dd = date.day.toString().padLeft(2, '0');
  final mon = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  return '$dd.$mon.$yyyy, $hh:$mm';
}
