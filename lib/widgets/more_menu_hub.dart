import 'package:flutter/foundation.dart';

/// Глобальный «хаб» для закрытия активного всплывающего меню.
/// Любое меню при показе регистрирует свой hide-колбэк,
/// а экран/список может в любой момент сказать: MoreMenuHub.hide();
class MoreMenuHub {
  static VoidCallback? _hideActive;

  /// Регистрирует текущее активное меню.
  static void register(VoidCallback hide) {
    _hideActive = hide;
  }

  /// Снимает регистрацию, если закрываем именно активное меню.
  static void unregister(VoidCallback hide) {
    if (identical(_hideActive, hide)) {
      _hideActive = null;
    }
  }

  /// Закрывает текущее активное меню (если есть).
  static void hide() {
    _hideActive?.call();
    _hideActive = null;
  }
}
