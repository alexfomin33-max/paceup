import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/providers/registration_data_provider.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Первый экран регистрации — ввод имени пользователя
/// Шаг 1 из 6 в процессе регистрации
class RegStep1Screen extends ConsumerStatefulWidget {
  /// 🔹 ID пользователя, передается с предыдущего экрана
  final int userId;

  const RegStep1Screen({super.key, required this.userId});

  @override
  ConsumerState<RegStep1Screen> createState() => _RegStep1ScreenState();
}

class _RegStep1ScreenState extends ConsumerState<RegStep1Screen> {
  /// 🔹 Контроллер для поля ввода имени
  final TextEditingController nameController = TextEditingController();

  /// 🔹 Контроллер для поля ввода фамилии
  final TextEditingController surnameController = TextEditingController();

  /// 🔹 Выбранный пол
  String? selectedGender;

  /// 🔹 Проверка корректности заполнения формы
  bool get isFormValid {
    return nameController.text.trim().isNotEmpty &&
        surnameController.text.trim().isNotEmpty &&
        selectedGender != null;
  }

  @override
  void initState() {
    super.initState();
    // 🔹 Очищаем ошибку при изменении полей
    Future.microtask(() {
      final formNotifier = ref.read(formStateProvider.notifier);
      nameController.addListener(() {
        formNotifier.clearGeneralError();
        formNotifier.clearFieldError('name');
      });
      surnameController.addListener(() {
        formNotifier.clearGeneralError();
        formNotifier.clearFieldError('surname');
      });
    });
  }

  @override
  void dispose() {
    // 🔹 Освобождаем контроллеры при уничтожении виджета
    nameController.dispose();
    surnameController.dispose();
    super.dispose();
  }

  /// 🔹 Метод проверки валидности формы и перехода на следующий экран
  Future<void> _checkAndContinue() async {
    final formState = ref.read(formStateProvider);
    if (!isFormValid || formState.isSubmitting) return;

    // 🔹 Сохраняем данные в провайдер регистрации
    final registrationNotifier = ref.read(registrationDataProvider.notifier);
    registrationNotifier.setFirstName(nameController.text.trim());
    registrationNotifier.setLastName(surnameController.text.trim());
    registrationNotifier.setGender(selectedGender!);

    // 🔹 Проверка, что виджет ещё монтирован перед использованием context
    if (!mounted) return;

    // 🔹 Переходим на следующий экран регистрации
    Navigator.pushReplacementNamed(
      context,
      '/reg_step2',
      arguments: {'userId': widget.userId},
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем состояние формы
    final formState = ref.watch(formStateProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.darkSurface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          // 🔹 Отключаем изменение размера при открытии клавиатуры для фиксации кнопки
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final screenSize = MediaQuery.of(context).size;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ─────────── Фоновая картинка (заполняет весь экран включая системные области) ───────────
                  Positioned.fill(
                    child: Opacity(
                      opacity: 1.0,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Image.asset(
                          'assets/back.jpg',
                          width: screenSize.width,
                          height: screenSize.height,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                        ),
                      ),
                    ),
                  ),
                  // ─────────── Темный градиент поверх фоновой картинки ───────────
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(
                              alpha: 0.6,
                            ), // Сверху менее прозрачный (темнее)
                            Colors.black.withValues(
                              alpha: 0.2,
                            ), // Снизу более прозрачный (светлее)
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ─────────── Контент ───────────
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      // ─────────── Форма внизу ───────────
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).size.height * 0,
                            left: MediaQuery.of(context).size.width * 0.1,
                            right: MediaQuery.of(context).size.width * 0.1,
                          ),
                          child: SingleChildScrollView(
                            // 🔹 Прокручиваем контент при появлении клавиатуры
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.12,
                                ),
                                // 🔹 Текст с вопросом
                                const Text(
                                  'Как вас зовут?',
                                  style: TextStyle(
                                    color: AppColors.surface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // 🔹 Подсказка
                                const Text(
                                  'Понадобится для верификации профиля',
                                  style: TextStyle(
                                    color: AppColors.surface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 50),
                                // 🔹 Поле ввода имени
                                TextFormField(
                                  controller: nameController,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Введите имя',
                                    hintStyle: const TextStyle(
                                      color: AppColors.textPlaceholder,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // 🔹 Поле ввода фамилии
                                TextFormField(
                                  controller: surnameController,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontFamily: 'Inter',
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Введите фамилию',
                                    hintStyle: const TextStyle(
                                      color: AppColors.textPlaceholder,
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                    ),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        width: 0,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 50),
                                // 🔹 Секция "Ваш пол"
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Пол',
                                    style: TextStyle(
                                      color: AppColors.surface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 🔹 Переключатели пола
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedGender = 'Мужской';
                                          });
                                          ref
                                              .read(formStateProvider.notifier)
                                              .clearGeneralError();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              selectedGender == 'Мужской'
                                              ? AppColors.surface
                                              : AppColors.surface.withValues(
                                                  alpha: 0.25,
                                                ),
                                          foregroundColor:
                                              selectedGender == 'Мужской'
                                              ? AppColors.textPrimary
                                              : AppColors.surface,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.xxl,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Мужской',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedGender = 'Женский';
                                          });
                                          ref
                                              .read(formStateProvider.notifier)
                                              .clearGeneralError();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              selectedGender == 'Женский'
                                              ? AppColors.surface
                                              : AppColors.surface.withValues(
                                                  alpha: 0.25,
                                                ),
                                          foregroundColor:
                                              selectedGender == 'Женский'
                                              ? AppColors.textPrimary
                                              : AppColors.surface,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.xxl,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Женский',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // 🔹 Показываем ошибку, если есть
                                Builder(
                                  builder: (context) {
                                    if (formState.hasErrors) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: FormErrorDisplay(
                                          formState: formState,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ─────────── Прогресс-бар и кнопка назад в верхней части ───────────
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.065,
                    left: MediaQuery.of(context).size.width * 0.05,
                    right: MediaQuery.of(context).size.width * 0.05,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🔹 Кнопка "Назад" слева
                        IconButton(
                          onPressed: formState.isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.surface,
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        // 🔹 Прогресс-бар по центру
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 120,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 1 / 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 🔹 Индикатор шага справа
                        const Text(
                          '1/5',
                          style: TextStyle(
                            color: AppColors.surface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ─────────── Кнопка "Далее" внизу экрана ───────────
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    left: MediaQuery.of(context).size.width * 0.1,
                    right: MediaQuery.of(context).size.width * 0.1,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!isFormValid || formState.isSubmitting)
                            ? null
                            : _checkAndContinue,
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return AppColors.surface.withValues(alpha: 0.3);
                            }
                            return AppColors.getSurfaceColor(context);
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return AppColors.surface.withValues(alpha: 0.5);
                            }
                            return AppColors.textPrimary;
                          }),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(vertical: 15),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.xxl,
                              ),
                            ),
                          ),
                          elevation: const WidgetStatePropertyAll(0),
                        ),
                        child: formState.isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CupertinoActivityIndicator(
                                  radius: 10,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Text(
                                'Далее',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
