// ────────────────────────────────────────────────────────────────────────────
//  AVATAR VERSION PROVIDER
//
//  Глобальный provider для синхронизации версии аватарки пользователя
//  между всеми экранами (профиль, лента, редактирование)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier для управления версией аватарки текущего пользователя
/// 
/// Используется для cache-busting: при изменении версии все виджеты
/// с аватаркой обновляются и загружают новое изображение.
/// 
/// ⚠️ Версия = 0 при старте для offline режима (кэш без ?v=timestamp)
/// Версия меняется ТОЛЬКО при явном обновлении аватарки через bump()
class AvatarVersionNotifier extends StateNotifier<int> {
  AvatarVersionNotifier() : super(0); // ✅ Старт с 0 для offline режима

  /// Обновить версию аватарки (вызывается после загрузки новой аватарки)
  void bump() {
    state = DateTime.now().millisecondsSinceEpoch;
  }
  
  /// Сбросить версию
  void reset() {
    state = 0;
  }
}

/// Provider для версии аватарки текущего пользователя
/// 
/// Использование:
/// ```dart
/// final avatarVersion = ref.watch(avatarVersionProvider);
/// final url = '$baseUrl?v=$avatarVersion'; // cache-busting
/// ```
final avatarVersionProvider = StateNotifierProvider<AvatarVersionNotifier, int>((ref) {
  return AvatarVersionNotifier();
});

