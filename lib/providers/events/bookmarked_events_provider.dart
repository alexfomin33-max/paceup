// ────────────────────────────────────────────────────────────────────────────
//  BOOKMARKED EVENTS PROVIDER
//
//  StateNotifierProvider для управления списком событий из закладок пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import 'bookmarked_events_notifier.dart';
import 'bookmarked_events_state.dart';

/// Provider для списка событий из закладок пользователя (зависит от userId)
///
/// Использование:
/// ```dart
/// final eventsState = ref.watch(bookmarkedEventsProvider(userId));
///
/// // Загрузка данных
/// ref.read(bookmarkedEventsProvider(userId).notifier).loadInitial();
///
/// // Refresh
/// ref.read(bookmarkedEventsProvider(userId).notifier).refresh();
/// ```
final bookmarkedEventsProvider =
    StateNotifierProvider.family<BookmarkedEventsNotifier, BookmarkedEventsState, int>(
  (ref, userId) {
    final api = ref.watch(apiServiceProvider);
    final notifier = BookmarkedEventsNotifier(
      api: api,
      userId: userId,
    );
    
    // Автоматическая загрузка при создании провайдера
    Future.microtask(() {
      notifier.loadInitial();
    });
    
    return notifier;
  },
);

