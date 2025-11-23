import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/services/api_provider.dart';
import '../../service/api_service.dart' show ApiService, ApiException;
import '../../widgets/primary_button.dart';
import '../../widgets/auth/custom_text_field.dart';

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

  /// 🔹 Флаг загрузки (блокирует повторные нажатия)
  bool _isLoading = false;

  /// 🔹 Сообщение об ошибке (если есть)
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 🔹 Очищаем ошибку при изменении полей
    heightController.addListener(() {
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
    weightController.addListener(() {
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
    maxPulseController.addListener(() {
      if (_errorMessage != null) {
        setState(() => _errorMessage = null);
      }
    });
  }

  @override
  void dispose() {
    // 🔹 Освобождаем все контроллеры при уничтожении виджета
    heightController.dispose();
    weightController.dispose();
    maxPulseController.dispose();
    super.dispose();
  }

  /// 🔹 Валидация числовых полей (опционально, так как форма необязательна)
  /// Проверяет, что если поля заполнены, то значения в разумных пределах
  bool get _areFieldsValid {
    final height = heightController.text.trim();
    final weight = weightController.text.trim();
    final pulse = maxPulseController.text.trim();

    // 🔹 Если все поля пустые - это нормально (форма необязательна)
    if (height.isEmpty && weight.isEmpty && pulse.isEmpty) {
      return true;
    }

    // 🔹 Если заполнено - проверяем валидность значений
    if (height.isNotEmpty) {
      final h = int.tryParse(height);
      if (h == null || h < 50 || h > 250) {
        return false;
      }
    }
    if (weight.isNotEmpty) {
      final w = int.tryParse(weight);
      if (w == null || w < 20 || w > 300) {
        return false;
      }
    }
    if (pulse.isNotEmpty) {
      final p = int.tryParse(pulse);
      if (p == null || p < 100 || p > 250) {
        return false;
      }
    }

    return true;
  }

  /// 🔹 Обработка завершения регистрации
  Future<void> _handleFinish() async {
    if (_isLoading) return;

    // 🔹 Проверяем валидность полей
    if (!_areFieldsValid) {
      setState(() {
        _errorMessage =
            'Проверьте корректность введённых данных (рост: 50-250 см, вес: 20-300 кг, пульс: 100-250 уд/мин)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      await saveForm(
        api,
        widget.userId,
        heightController,
        weightController,
        maxPulseController,
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/lenta',
        arguments: {'userId': widget.userId},
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка сохранения данных: ${e.message}';
        });
      }
      debugPrint('Ошибка при сохранении данных: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем высоту клавиатуры для адаптации контента
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    // 🔹 Базовый отступ снизу, который уменьшается при появлении клавиатуры
    final verticalPadding = 50.0 - (keyboardHeight * 0.2).clamp(0.0, 30.0);

    return Scaffold(
      // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.getBackgroundColor(context),
      body: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 30,
                vertical: verticalPadding,
              ),
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
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: weightController,
                    label: 'Вес, кг',
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  const SizedBox(height: 22),
                  CustomTextField(
                    controller: maxPulseController,
                    label: 'Максимальный пульс',
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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

                  // 🔹 Показываем ошибку, если есть
                  if (_errorMessage != null) ...[
                    SelectableText.rich(
                      TextSpan(
                        text: _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 🔹 Кнопка "Завершить" с переходом на ленту
                  Center(
                    child: PrimaryButton(
                      text: 'Завершить',
                      onPressed: _handleFinish,
                      isLoading: _isLoading,
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
