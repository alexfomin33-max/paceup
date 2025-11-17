import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// 🔹 Виджет для ввода 6-значного SMS-кода
/// Автоматически переключается между полями при вводе
class SmsCodeInput extends StatefulWidget {
  /// 🔹 Callback когда код полностью введён (6 цифр)
  final ValueChanged<String>? onCodeComplete;

  /// 🔹 Callback при изменении кода (даже частичном)
  final ValueChanged<String>? onCodeChanged;

  /// 🔹 Флаг блокировки ввода (например, во время отправки)
  final bool enabled;

  const SmsCodeInput({
    super.key,
    this.onCodeComplete,
    this.onCodeChanged,
    this.enabled = true,
  });

  @override
  State<SmsCodeInput> createState() => SmsCodeInputState();
}

class SmsCodeInputState extends State<SmsCodeInput> {
  /// 🔹 Контроллеры для каждого из 6 полей ввода кода
  final controllers = List.generate(6, (_) => TextEditingController());

  /// 🔹 FocusNode для каждого поля для автоматического переключения
  final nodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // 🔹 Устанавливаем фокус на первое поле после отрисовки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) {
        nodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    // 🔹 Освобождаем все ресурсы
    for (final c in controllers) {
      c.dispose();
    }
    for (final n in nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// 🔹 Очистка всех полей ввода
  void clear() {
    for (final c in controllers) {
      c.clear();
    }
    if (mounted) {
      nodes[0].requestFocus();
    }
  }

  /// 🔹 Генерация отдельного поля для ввода одной цифры кода
  Widget _buildCodeField(int index) {
    return SizedBox(
      width: 45,
      height: 50,
      child: TextFormField(
        controller: controllers[index],
        focusNode: nodes[index],
        enabled: widget.enabled,
        style: const TextStyle(
          color: AppColors.surface,
          fontSize: 20,
        ),
        cursorColor: AppColors.surface,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1, // 🔹 Ограничение на одну цифру
        decoration: InputDecoration(
          counterText: "", // 🔹 Скрываем счётчик символов
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.surface),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          disabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.surface.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(0),
        ),
        onChanged: (v) {
          if (!widget.enabled) return;

          // 🔹 Логика автоматического перехода между полями
          if (v.isNotEmpty && index < 5) {
            // Если введена цифра и это не последний индекс — переходим к следующему полю
            nodes[index + 1].requestFocus();
          } else if (v.isEmpty && index > 0) {
            // Если удалили цифру — возвращаемся к предыдущему полю
            nodes[index - 1].requestFocus();
          } else if (index == 5 && v.isNotEmpty) {
            // 🔹 Если последний символ введён — объединяем код и вызываем callback
            final code = controllers.map((c) => c.text).join();
            if (code.length == 6) {
              widget.onCodeComplete?.call(code);
            }
          }

          // 🔹 Уведомляем об изменении кода (даже частичном)
          final currentCode = controllers.map((c) => c.text).join();
          widget.onCodeChanged?.call(currentCode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) => _buildCodeField(index)),
    );
  }
}

