// lib/providers/pacepro_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
//                    PACEPRO: СТАТУС ПЛАТНОЙ ПОДПИСКИ (ЛОКАЛЬНО)
//
// ВАЖНО:
// - Сейчас это локальный флаг (SharedPreferences), чтобы уже можно было
//   ограничивать платные функции и верстать paywall.
// - Подключение реальных покупок (App Store / Google Play) добавим позже,
//   заменив логику внутри Notifier на биллинг и/или бэкенд.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                               NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

/// Управляет статусом подписки PacePro.
///
/// Почему `StateNotifier<bool>`:
/// - В проекте уже есть аналогичный паттерн для темы (`ThemeModeNotifier`),
///   поэтому это минимально-инвазивное и понятное решение.
class PaceProStatusNotifier extends StateNotifier<bool> {
  static const String _isActiveKey = 'pacepro_is_active';

  PaceProStatusNotifier() : super(false) {
    // ─────────── Инициализация: поднимаем состояние из SharedPreferences ───────────
    _loadFromPrefs();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //                              LOAD / SAVE
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_isActiveKey) ?? false;
    } catch (_) {
      // Игнорируем ошибки чтения — остаёмся в состоянии "не активна".
      state = false;
    }
  }

  /// Установить статус подписки.
  Future<void> setActive(bool isActive) async {
    // ─────────── Сразу обновляем UI ───────────
    state = isActive;

    // ─────────── Пытаемся сохранить локально ───────────
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isActiveKey, isActive);
    } catch (_) {
      // Игнорируем ошибки записи — UI уже обновлён.
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                               PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

/// Глобальный провайдер статуса PacePro.
final paceProStatusProvider =
    StateNotifierProvider<PaceProStatusNotifier, bool>((ref) {
  return PaceProStatusNotifier();
});

