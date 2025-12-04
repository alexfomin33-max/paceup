// ────────────────────────────────────────────────────────────────────────────
//  THINGS PROVIDER
//
//  StateNotifierProvider для управления списком вещей с пагинацией
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/services/api_provider.dart';
import 'things_notifier.dart';
import 'things_state.dart';

/// Provider для списка вещей (один стабильный provider без family)
///
/// Использование:
/// ```dart
/// final thingsState = ref.watch(thingsProvider);
/// final notifier = ref.read(thingsProvider.notifier);
///
/// // Обновление фильтра
/// notifier.updateFilter(ThingsFilter(category: 'Кроссовки'));
///
/// // Загрузка следующей страницы
/// notifier.loadMore();
/// ```
final thingsProvider = StateNotifierProvider<ThingsNotifier, ThingsState>(
  (ref) {
    final api = ref.watch(apiServiceProvider);
    return ThingsNotifier(api: api);
  },
);

