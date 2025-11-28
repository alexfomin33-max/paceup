// ────────────────────────────────────────────────────────────────────────────
//  EVENT DETAIL PROVIDER
//
//  StateNotifierProvider для управления состоянием экрана детальной информации о событии
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';
import 'event_detail_notifier.dart';
import 'event_detail_state.dart';

/// Provider для EventDetail (зависит от eventId)
///
/// Использование:
/// ```dart
/// final eventState = ref.watch(eventDetailProvider(eventId));
///
/// // Загрузка данных
/// ref.read(eventDetailProvider(eventId).notifier).loadEvent();
///
/// // Переключение закладки
/// ref.read(eventDetailProvider(eventId).notifier).toggleBookmark();
///
/// // Переключение участия
/// ref.read(eventDetailProvider(eventId).notifier).toggleParticipation();
/// ```
final eventDetailProvider = StateNotifierProvider.family<
    EventDetailNotifier, EventDetailState, int>((ref, eventId) {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);
  final notifier = EventDetailNotifier(
    api: api,
    auth: auth,
    eventId: eventId,
  );

  // Автоматическая загрузка при создании провайдера
  Future.microtask(() => notifier.loadEvent());

  return notifier;
});

