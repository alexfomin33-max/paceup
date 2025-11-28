// ────────────────────────────────────────────────────────────────────────────
//  EDIT EVENT PROVIDER
//
//  StateNotifierProvider для управления состоянием экрана редактирования события
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_provider.dart';
import '../services/auth_provider.dart';
import 'edit_event_notifier.dart';
import 'edit_event_state.dart';

/// Provider для EditEvent (зависит от eventId)
///
/// Использование:
/// ```dart
/// final editState = ref.watch(editEventProvider(eventId));
///
/// // Загрузка данных
/// ref.read(editEventProvider(eventId).notifier).loadEventData();
///
/// // Установка значений
/// ref.read(editEventProvider(eventId).notifier).setActivity('Бег');
/// ```
final editEventProvider = StateNotifierProvider.family<
    EditEventNotifier, EditEventState, int>((ref, eventId) {
  final api = ref.watch(apiServiceProvider);
  final auth = ref.watch(authServiceProvider);
  final notifier = EditEventNotifier(
    api: api,
    auth: auth,
    eventId: eventId,
  );

  // Автоматическая загрузка клубов при создании провайдера
  // Данные события будут загружены в виджете для заполнения контроллеров
  Future.microtask(() async {
    await notifier.loadUserClubs();
  });

  return notifier;
});

