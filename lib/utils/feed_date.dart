// lib/utils/feed_date.dart
import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────
/// FEED DATE FORMATTER: единый формат даты для ленты
/// ──────────────────────────────────────────────────────────────
/// Правило:
/// 1) Если пришла готовая строка с сервера/модели — нормализуем её
///    (убираем год, если это текущий год).
/// 2) Иначе форматируем локально в стиле ленты:
///    - Сегодня: "Сегодня, в HH:mm"
///    - Вчера:  "Вчера, в HH:mm"
///    - Этот год: "dd месяца, в HH:mm"
///    - Прошлый год: "dd месяца yyyy, в HH:mm"
String formatFeedDateText({
  String? serverText,
  DateTime? date,
  Locale? locale, // на будущее (ru, en и т.п.)
}) {
  // 1) Пробуем серверный/модельный текст — нормализуем год
  if (serverText != null && serverText.trim().isNotEmpty) {
    return _normalizeServerDateText(serverText.trim());
  }

  // 2) Фолбэк — локальное форматирование
  if (date == null) return '';

  final now = DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  final time = 'в $hh:$mm';

  // Сегодня/вчера
  if (d == today) return 'Сегодня, $time';
  if (d == yesterday) return 'Вчера, $time';

  // Иначе — полная дата с месяцем (родительный падеж)
  final monthName = _getMonthNameGenitive(date.month);
  
  // Если тот же год — год не показываем
  if (date.year == now.year) {
    return '${date.day} $monthName, $time';
  }
  
  // Если другой год — показываем год
  return '${date.day} $monthName ${date.year}, $time';
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
/// НОРМАЛИЗАЦИЯ СЕРВЕРНОЙ ДАТЫ: убираем год, если это текущий год
/// ──────────────────────────────────────────────────────────────
/// Пример:
///   Вход:  "29 октября 2025, в 15:40"
///   Выход: "29 октября, в 15:40" (если 2025 = текущий год)
///
/// Также обрабатывает форматы:
///   - "Сегодня, в 15:40"
///   - "Вчера, в 18:50"
String _normalizeServerDateText(String text) {
  // Если уже "Сегодня" или "Вчера" — оставляем как есть
  if (text.startsWith('Сегодня') || text.startsWith('Вчера')) {
    return text;
  }

  // Регулярка для парсинга: "dd месяца yyyy, в HH:mm" или "dd месяца, в HH:mm"
  // Пример: "29 октября 2025, в 15:40"
  final regex = RegExp(
    r'^(\d{1,2})\s+([а-яА-Я]+)(?:\s+(\d{4}))?,\s+в\s+(\d{2}):(\d{2})$',
  );

  final match = regex.firstMatch(text);
  if (match == null) return text; // не распознали — возвращаем как есть

  final day = match.group(1)!;
  final monthName = match.group(2)!;
  final yearStr = match.group(3); // может быть null
  final hour = match.group(4)!;
  final minute = match.group(5)!;

  // Если года нет в строке — возвращаем как есть
  if (yearStr == null) return text;

  final year = int.tryParse(yearStr);
  final currentYear = DateTime.now().year;

  // Если год текущий — убираем его
  if (year == currentYear) {
    return '$day $monthName, в $hour:$minute';
  }

  // Иначе — возвращаем с годом
  return text;
}
