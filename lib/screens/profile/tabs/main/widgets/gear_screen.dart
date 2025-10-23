import 'package:flutter/widgets.dart';

/// Глобальные настройки видимости блоков снаряжения
class GearPrefs extends ChangeNotifier {
  bool _showShoes = true;
  bool _showBikes = true;

  bool get showShoes => _showShoes;
  set showShoes(bool v) {
    if (_showShoes == v) return;
    _showShoes = v;
    notifyListeners();
  }

  bool get showBikes => _showBikes;
  set showBikes(bool v) {
    if (_showBikes == v) return;
    _showBikes = v;
    notifyListeners();
  }
}

/// Провайдер стейта через InheritedNotifier
class GearPrefsScope extends InheritedNotifier<GearPrefs> {
  const GearPrefsScope({
    super.key,
    required GearPrefs super.notifier,
    required super.child,
  });

  static GearPrefs of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GearPrefsScope>();
    assert(scope != null, 'GearPrefsScope not found in context');
    return scope!.notifier!;
  }
}
