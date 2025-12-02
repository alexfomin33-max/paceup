// ────────────────────────────────────────────────────────────────────────────
//  SLOTS PROVIDER
//
//  StateNotifierProvider для управления списком слотов с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import 'slots_notifier.dart';
import 'slots_state.dart';

/// Provider для списка слотов (один стабильный provider без family)
///
/// Использование:
/// ```dart
/// final slotsState = ref.watch(slotsProvider);
/// final notifier = ref.read(slotsProvider.notifier);
///
/// // Обновление фильтра
/// notifier.updateFilter(const SlotsFilter(search: 'марафон'));
///
/// // Загрузка следующей страницы
/// notifier.loadMore();
/// ```
final slotsProvider = StateNotifierProvider<SlotsNotifier, SlotsState>(
  (ref) {
    final api = ref.watch(apiServiceProvider);
    return SlotsNotifier(api: api);
  },
);

