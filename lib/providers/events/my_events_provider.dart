// ────────────────────────────────────────────────────────────────────────────
//  MY EVENTS PROVIDER
//
//  StateNotifierProvider для управления списком событий пользователя
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import 'my_events_notifier.dart';
import 'my_events_state.dart';

/// Provider для списка событий пользователя (зависит от userId)
///
/// Использование:
/// ```dart
/// final eventsState = ref.watch(myEventsProvider(userId));
///
/// // Загрузка данных
/// ref.read(myEventsProvider(userId).notifier).loadInitial();
///
/// // Refresh
/// ref.read(myEventsProvider(userId).notifier).refresh();
/// ```
final myEventsProvider =
    StateNotifierProvider.family<MyEventsNotifier, MyEventsState, int>(
  (ref, userId) {
    final api = ref.watch(apiServiceProvider);
    final notifier = MyEventsNotifier(
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

