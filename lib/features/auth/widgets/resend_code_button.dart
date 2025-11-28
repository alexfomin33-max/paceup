import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 🔹 Кнопка повторной отправки SMS-кода с таймером
/// Показывает оставшееся время до возможности повторной отправки
class ResendCodeButton extends StatefulWidget {
  /// 🔹 Callback при нажатии на кнопку
  final VoidCallback? onPressed;

  /// 🔹 Начальное время таймера в секундах (по умолчанию 60)
  final int initialSeconds;

  const ResendCodeButton({super.key, this.onPressed, this.initialSeconds = 60});

  @override
  State<ResendCodeButton> createState() => ResendCodeButtonState();
}

class ResendCodeButtonState extends State<ResendCodeButton> {
  /// 🔹 Таймер для обратного отсчёта
  Timer? _timer;

  /// 🔹 Оставшееся время до возможности повторной отправки (в секундах)
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    // 🔹 Запускаем таймер при инициализации
    _startTimer();
  }

  @override
  void dispose() {
    // 🔹 Отменяем таймер при уничтожении виджета
    _timer?.cancel();
    super.dispose();
  }

  /// 🔹 Запуск таймера обратного отсчёта
  void _startTimer() {
    _remainingSeconds = widget.initialSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// 🔹 Перезапуск таймера (вызывается после успешной отправки)
  void resetTimer() {
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = _remainingSeconds == 0 && widget.onPressed != null;

    return TextButton(
      // 🔹 Кнопка активна только когда таймер истёк
      onPressed: isEnabled ? widget.onPressed : null,
      style: const ButtonStyle(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 15)),
      ),
      child: Text(
        // 🔹 Показываем оставшееся время или текст кнопки
        _remainingSeconds > 0
            ? "Отправить заново ($_remainingSecondsс)"
            : "Отправить заново",
        style: TextStyle(
          color: isEnabled
              ? AppColors.surface
              : AppColors.surface.withValues(alpha: 0.5),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}

