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
///   - "29 октября 2025, в 15:40" (с годом)
///   - "29 октября, в 15:40" (без года)
String _normalizeServerDateText(String text) {
  // Если уже "Сегодня" или "Вчера" — оставляем как есть
  if (text.startsWith('Сегодня') || text.startsWith('Вчера')) {
    return text;
  }

  final currentYear = DateTime.now().year;

  // ──────────────────────────────────────────────────────────────
  // Более гибкая регулярка: ищем год в любом месте строки
  // ──────────────────────────────────────────────────────────────
  // Паттерн 1: "dd месяца yyyy, в HH:mm" (с годом)
  // Паттерн 2: "dd месяца, в HH:mm" (без года)
  // Примеры: "29 октября 2025, в 15:40" или "29 октября, в 15:40"
  final regexWithYear = RegExp(
    r'^(\d{1,2})\s+([а-яА-ЯёЁ]+)\s+(\d{4}),\s*в\s+(\d{1,2}):(\d{2})$',
    caseSensitive: false,
  );

  final matchWithYear = regexWithYear.firstMatch(text);
  if (matchWithYear != null) {
    final day = matchWithYear.group(1)!;
    final monthName = matchWithYear.group(2)!;
    final yearStr = matchWithYear.group(3)!;
    final hour = matchWithYear.group(4)!.padLeft(2, '0');
    final minute = matchWithYear.group(5)!;

    final year = int.tryParse(yearStr);
    if (year != null && year == currentYear) {
      // Год текущий — убираем его
      return '$day $monthName, в $hour:$minute';
    }
    // Год не текущий — возвращаем как есть
    return text;
  }

  // ──────────────────────────────────────────────────────────────
  // Паттерн без года: "dd месяца, в HH:mm"
  // ──────────────────────────────────────────────────────────────
  final regexWithoutYear = RegExp(
    r'^(\d{1,2})\s+([а-яА-ЯёЁ]+),\s*в\s+(\d{1,2}):(\d{2})$',
    caseSensitive: false,
  );

  final matchWithoutYear = regexWithoutYear.firstMatch(text);
  if (matchWithoutYear != null) {
    // Уже без года — возвращаем как есть
    return text;
  }

  // ──────────────────────────────────────────────────────────────
  // Если не распознали формат — пытаемся найти год вручную
  // ──────────────────────────────────────────────────────────────
  // Ищем паттерн: число месяца, название месяца, год (4 цифры), запятая, "в", время
  // Более гибкий поиск года между месяцем и запятой
  final flexiblePattern = RegExp(
    r'(\d{1,2})\s+([а-яА-ЯёЁ]+)\s+(\d{4})(\s*,\s*в\s+\d{1,2}:\d{2})',
    caseSensitive: false,
  );

  final flexibleMatch = flexiblePattern.firstMatch(text);
  if (flexibleMatch != null) {
    final day = flexibleMatch.group(1)!;
    final monthName = flexibleMatch.group(2)!;
    final yearStr = flexibleMatch.group(3)!;
    final timePart = flexibleMatch.group(4)!; // ", в HH:mm"

    final year = int.tryParse(yearStr);
    if (year != null && year == currentYear) {
      // Год текущий — убираем его
      return '$day $monthName$timePart';
    }
  }

  // Не распознали — возвращаем как есть
  return text;
}
