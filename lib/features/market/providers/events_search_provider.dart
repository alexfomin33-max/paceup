// ────────────────────────────────────────────────────────────────────────────
//  EVENTS SEARCH PROVIDER
//
//  Провайдер для поиска событий с доступными слотами
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import '../models/event_option.dart';

/// Провайдер для поиска событий с доступными слотами
///
/// Использование:
/// ```dart
/// final events = await ref.read(eventsSearchProvider('марафон').future);
/// ```
final eventsSearchProvider = FutureProvider.family<List<EventOption>, String>(
  (ref, query) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      final api = ref.read(apiServiceProvider);
      
      // Используем существующий endpoint search_events.php
      // В будущем можно создать отдельный endpoint для поиска событий с доступными слотами
      final response = await api.post(
        '/search_events.php',
        body: {'query': query.trim()},
      );

      if (response['success'] == true) {
        final List<dynamic> eventsData = response['events'] ?? [];
        return eventsData
            .map((e) => EventOption.fromApi(e as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      // В случае ошибки возвращаем пустой список
      return [];
    }
  },
);

