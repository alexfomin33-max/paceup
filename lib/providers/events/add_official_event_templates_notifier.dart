// ────────────────────────────────────────────────────────────────────────────
//  ADD OFFICIAL EVENT TEMPLATES NOTIFIER
//
//  AsyncNotifier для загрузки шаблонов событий
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';

/// Модель шаблона события
class EventTemplate {
  final String name;
  final String place;
  final String description;
  final String? link;
  final String? activity;
  final DateTime? date;
  final TimeOfDay? time;
  final double? latitude;
  final double? longitude;
  final List<String> distances;

  const EventTemplate({
    required this.name,
    required this.place,
    required this.description,
    this.link,
    this.activity,
    this.date,
    this.time,
    this.latitude,
    this.longitude,
    this.distances = const [],
  });

  factory EventTemplate.fromApi(Map<String, dynamic> data) {
    // Парсинг даты (формат: "dd.mm.yyyy")
    DateTime? parsedDate;
    final dateStr = data['event_date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          parsedDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {
        // Игнорируем ошибку парсинга
      }
    }

    // Парсинг времени (формат: "hh:mm")
    TimeOfDay? parsedTime;
    final timeStr = data['event_time'] as String?;
    if (timeStr != null && timeStr.isNotEmpty) {
      try {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          parsedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {
        // Игнорируем ошибку парсинга
      }
    }

    // Парсинг дистанций
    List<String> parsedDistances = [];
    final distanceStr = data['distance'] as String?;
    if (distanceStr != null && distanceStr.isNotEmpty) {
      parsedDistances = distanceStr
          .split(',')
          .map((d) => d.trim())
          .where((d) => d.isNotEmpty)
          .toList();
    }

    return EventTemplate(
      name: data['name'] as String? ?? '',
      place: data['place'] as String? ?? '',
      description: data['description'] as String? ?? '',
      link: data['event_link'] as String?,
      activity: data['activity'] as String?,
      date: parsedDate,
      time: parsedTime,
      latitude: data['latitude'] as double?,
      longitude: data['longitude'] as double?,
      distances: parsedDistances,
    );
  }
}

/// AsyncNotifier для загрузки списка шаблонов
class TemplatesListNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authServiceProvider);
    final userId = await auth.getUserId();

    if (userId == null) {
      return [];
    }

    try {
      final data = await api.get(
        '/get_templates.php',
        queryParams: {'user_id': userId.toString()},
      );

      if (data['success'] == true && data['templates'] != null) {
        final templates = data['templates'] as List<dynamic>;
        return templates.map((t) => t.toString()).toList();
      }

      return [];
    } catch (e) {
      throw Exception('Ошибка загрузки шаблонов: $e');
    }
  }

  /// Перезагрузка списка шаблонов
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(apiServiceProvider);
      final auth = ref.read(authServiceProvider);
      final userId = await auth.getUserId();

      if (userId == null) {
        return [];
      }

      final data = await api.get(
        '/get_templates.php',
        queryParams: {'user_id': userId.toString()},
      );

      if (data['success'] == true && data['templates'] != null) {
        final templates = data['templates'] as List<dynamic>;
        return templates.map((t) => t.toString()).toList();
      }

      return [];
    });
  }
}

/// AsyncNotifier для загрузки данных конкретного шаблона
class TemplateDataNotifier extends FamilyAsyncNotifier<EventTemplate, String> {
  @override
  Future<EventTemplate> build(String templateName) async {
    final api = ref.read(apiServiceProvider);
    final auth = ref.read(authServiceProvider);
    final userId = await auth.getUserId();

    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      final data = await api.get(
        '/get_template.php',
        queryParams: {
          'template_name': templateName,
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && data['template'] != null) {
        final template = data['template'] as Map<String, dynamic>;
        return EventTemplate.fromApi(template);
      }

      throw Exception('Шаблон не найден');
    } catch (e) {
      throw Exception('Ошибка загрузки шаблона: $e');
    }
  }
}
