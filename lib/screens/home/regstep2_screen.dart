import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/services/api_provider.dart';
import '../../service/api_service.dart' show ApiService, ApiException;
import '../../widgets/primary_button.dart';

/// 🔹 Экран регистрации — шаг 2
/// Принимает [userId] для продолжения регистрации
class Regstep2Screen extends ConsumerStatefulWidget {
  final int userId;

  const Regstep2Screen({super.key, required this.userId});

  @override
  ConsumerState<Regstep2Screen> createState() => Regstep2ScreenState();
}

/// 🔹 Публичный класс состояния для Regstep2Screen
class Regstep2ScreenState extends ConsumerState<Regstep2Screen> {
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController maxPulseController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Параметры спортсмена',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h17w6,
                  ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/lenta',
                          arguments: {'userId': widget.userId},
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerRight,
                      ),
                      child: const Text(
                        'Пропустить',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,

                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  CustomTextField(
                    controller: heightController,
                    label: 'Рост, см',
                    maxLength: 3,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: weightController,
                    label: 'Вес, кг',
                    maxLength: 3,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: maxPulseController,
                    label: 'Максимальный пульс',
                    maxLength: 3,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Данные необходимы для расчёта калорий, нагрузки, зон темпа и мощности.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // 🔹 Кнопка "Завершить" с переходом на ленту
                  Center(
                    child: PrimaryButton(
                      text: 'Завершить',
                      onPressed: () async {
                        final api = ref.read(apiServiceProvider);
                        await saveForm(
                          api,
                          widget.userId,
                          heightController,
                          weightController,
                          maxPulseController,
                        );
                        // 🔹 Проверяем, что контекст все еще смонтирован перед навигацией (после async-операции)
                        if (!mounted) return;
                        // 🔹 Переход на экран ленты
                        Navigator.pushReplacementNamed(
                          context,
                          '/lenta',
                          arguments: {'userId': widget.userId},
                        );
                      },
                      width: MediaQuery.of(context).size.width / 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 🔹 Кнопка "Назад" для возврата на предыдущий экран
                  Center(
                    child: SizedBox(
                      width: 100,
                      height: 40,
                      child: TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          '/regstep1',
                          arguments: {'userId': widget.userId},
                        ),
                        style: const ButtonStyle(
                          overlayColor: WidgetStatePropertyAll(
                            Colors.transparent,
                          ),
                          animationDuration: Duration(milliseconds: 0),
                        ),
                        child: const Text(
                          "<-- Назад",
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLength = 3,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,

          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

// ==========================
// Кнопка Продолжить/Завершить
// ==========================

/// 🔹 Метод для сохранения в базе введенных данных (перед переходом на следующую странцу)
Future<void> saveForm(
  ApiService api,
  int userId,
  dynamic height,
  dynamic weight,
  dynamic pulse,
) async {
  try {
    await api.post(
      '/save_reg_form2.php',
      body: {
        'user_id': '$userId', // 🔹 PHP ожидает строки
        'height': height.text,
        'weight': weight.text,
        'pulse': pulse.text,
      },
    );
  } on ApiException {
    // 🔹 Игнорируем ошибку сохранения (регистрация необязательна, есть кнопка "Пропустить")
    // Пользователь может продолжить работу в приложении даже при сбое сохранения
  }
}
