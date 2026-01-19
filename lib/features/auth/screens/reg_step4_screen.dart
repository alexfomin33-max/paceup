import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Четвертый экран регистрации — выбор основного вида спорта
/// Шаг 4 из 6 в процессе регистрации
class RegStep4Screen extends ConsumerStatefulWidget {
  /// 🔹 ID пользователя, передается с предыдущего экрана
  final int userId;

  const RegStep4Screen({super.key, required this.userId});

  @override
  ConsumerState<RegStep4Screen> createState() => _RegStep4ScreenState();
}

class _RegStep4ScreenState extends ConsumerState<RegStep4Screen> {
  /// 🔹 Выбранный вид спорта
  String? selectedSport;

  /// 🔹 Проверка корректности заполнения формы
  bool get isFormValid {
    return selectedSport != null;
  }

  /// 🔹 Получение названия выбранного вида спорта
  String? get selectedSportName {
    switch (selectedSport) {
      case 'running':
        return 'Бег';
      case 'cycling':
        return 'Велосипед';
      case 'swimming':
        return 'Плавание';
      case 'skiing':
        return 'Лыжи';
      default:
        return null;
    }
  }

  /// 🔹 Метод проверки валидности формы и перехода на следующий экран
  Future<void> _checkAndContinue() async {
    final formState = ref.read(formStateProvider);
    if (!isFormValid || formState.isSubmitting) return;

    // 🔹 Проверка, что виджет ещё монтирован перед использованием context
    if (!mounted) return;

    // 🔹 Переходим на следующий экран регистрации
    Navigator.pushReplacementNamed(
      context,
      '/regstep5',
      arguments: {'userId': widget.userId},
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Получаем состояние формы
    final formState = ref.watch(formStateProvider);

    // 🔹 Ширина кнопок для сетки 2x2
    final double buttonWidth =
        (MediaQuery.of(context).size.width * 0.8) / 2 - 6;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: GestureDetector(
        // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          // 🔹 Отключаем изменение размера при открытии клавиатуры для фиксации кнопки
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.twinBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // ─────────── Контент ───────────
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      // ─────────── Форма ───────────
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
                                  'Основной вид спорта',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                // 🔹 Подсказка
                                const Text(
                                  'Для отображения необходимой статистики',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 50),
                                // 🔹 Сетка кнопок-изображений 2x2
                                Column(
                                  children: [
                                    // 🔹 Первая строка
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // 🔹 Бег
                                        _SportButton(
                                          imagePath: 'assets/running.jpg',
                                          isSelected:
                                              selectedSport == 'running',
                                          onTap: () {
                                            setState(() {
                                              selectedSport = 'running';
                                            });
                                            ref
                                                .read(
                                                  formStateProvider.notifier,
                                                )
                                                .clearGeneralError();
                                          },
                                          width: buttonWidth,
                                        ),
                                        const SizedBox(width: 12),
                                        // 🔹 Велосипед
                                        _SportButton(
                                          imagePath: 'assets/cycling.jpg',
                                          isSelected:
                                              selectedSport == 'cycling',
                                          onTap: () {
                                            setState(() {
                                              selectedSport = 'cycling';
                                            });
                                            ref
                                                .read(
                                                  formStateProvider.notifier,
                                                )
                                                .clearGeneralError();
                                          },
                                          width: buttonWidth,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // 🔹 Вторая строка
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // 🔹 Плавание
                                        _SportButton(
                                          imagePath: 'assets/swimming.webp',
                                          isSelected:
                                              selectedSport == 'swimming',
                                          onTap: () {
                                            setState(() {
                                              selectedSport = 'swimming';
                                            });
                                            ref
                                                .read(
                                                  formStateProvider.notifier,
                                                )
                                                .clearGeneralError();
                                          },
                                          width: buttonWidth,
                                        ),
                                        const SizedBox(width: 12),
                                        // 🔹 Лыжи
                                        _SportButton(
                                          imagePath: 'assets/skiing.jpg',
                                          isSelected: selectedSport == 'skiing',
                                          onTap: () {
                                            setState(() {
                                              selectedSport = 'skiing';
                                            });
                                            ref
                                                .read(
                                                  formStateProvider.notifier,
                                                )
                                                .clearGeneralError();
                                          },
                                          width: buttonWidth,
                                        ),
                                      ],
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
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  '/regstep3',
                                  arguments: {'userId': widget.userId},
                                ),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
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
                                  color: AppColors.twinchip,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 4 / 5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.textPrimary,
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
                          '4/5',
                          style: TextStyle(
                            color: AppColors.textPrimary,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔹 Название выбранного вида спорта
                        if (selectedSportName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              selectedSportName!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // 🔹 Кнопка "Далее"
                        SizedBox(
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
                                  return AppColors.twinchip;
                                }
                                return AppColors.textPrimary;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.disabled)) {
                                  return AppColors.textPlaceholder;
                                }
                                return AppColors.surface;
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
                                      color: AppColors.surface,
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
                      ],
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

/// 🔹 Виджет кнопки с изображением вида спорта
class _SportButton extends StatelessWidget {
  /// 🔹 Путь к изображению
  final String imagePath;

  /// 🔹 Флаг выбранности
  final bool isSelected;

  /// 🔹 Обработчик нажатия
  final VoidCallback onTap;

  /// 🔹 Ширина кнопки
  final double width;

  const _SportButton({
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: isSelected
              ? // 🔹 Цветное изображение без фильтров
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.twinchip,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 24,
                        color: AppColors.textPlaceholder,
                      ),
                    );
                  },
                )
              : // 🔹 Черно-белое изображение для невыбранных с прозрачностью
                Opacity(
                  opacity: 0.7,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0, // R
                      0.2126, 0.7152, 0.0722, 0, 0, // G
                      0.2126, 0.7152, 0.0722, 0, 0, // B
                      0, 0, 0, 1, 0, // A
                    ]),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.twinchip,
                          child: const Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.textPlaceholder,
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
