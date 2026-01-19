import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/local_image_compressor.dart';

/// 🔹 Пятый экран регистрации — выбор фото профиля
/// Шаг 5 из 5 в процессе регистрации
class RegStep5Screen extends ConsumerStatefulWidget {
  /// 🔹 ID пользователя, передается с предыдущего экрана
  final int userId;

  const RegStep5Screen({super.key, required this.userId});

  @override
  ConsumerState<RegStep5Screen> createState() => _RegStep5ScreenState();
}

class _RegStep5ScreenState extends ConsumerState<RegStep5Screen> {
  /// 🔹 Выбранное фото профиля
  File? selectedPhoto;

  /// 🔹 Проверка корректности заполнения формы
  bool get isFormValid {
    return selectedPhoto != null;
  }

  /// 🔹 Метод выбора фото с обрезкой 1:1
  Future<void> _pickPhoto() async {
    final formNotifier = ref.read(formStateProvider.notifier);

    // 🔹 Выбираем фото с обрезкой в пропорции 1:1
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: 1.0,
      maxSide: ImageCompressionPreset.avatar.maxSide,
      jpegQuality: ImageCompressionPreset.avatar.quality,
      cropTitle: 'Обрезка фото профиля',
    );

    if (processed == null || !mounted) return;

    setState(() {
      selectedPhoto = processed;
    });

    // 🔹 Очищаем ошибки при успешном выборе фото
    formNotifier.clearGeneralError();
    formNotifier.clearFieldError('photo');
  }

  /// 🔹 Метод завершения регистрации и перехода на экран создания PIN-кода
  Future<void> _finishRegistration() async {
    final formState = ref.read(formStateProvider);

    if (!isFormValid || formState.isSubmitting) return;

    // 🔹 Проверка, что виджет ещё монтирован перед использованием context
    if (!mounted) return;

    // 🔹 TODO: Здесь можно добавить сохранение фото через API
    // Пока после успешного выбора фото переходим на экран создания PIN-кода
    Navigator.pushReplacementNamed(
      context,
      '/code1',
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
                                  'Ваше фото',
                                  style: TextStyle(
                                    color: AppColors.surface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 30),
                                // 🔹 Кнопка выбора фото
                                _PhotoPickerButton(
                                  selectedPhoto: selectedPhoto,
                                  onTap: _pickPhoto,
                                  hasError: formState.fieldErrors.containsKey(
                                    'photo',
                                  ),
                                  errorText: formState.fieldErrors['photo'],
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
                                  '/regstep4',
                                  arguments: {'userId': widget.userId},
                                ),
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
                                  widthFactor: 5 / 5,
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
                          '5/5',
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
                  // ─────────── Кнопка "Завершить" внизу экрана ───────────
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    left: MediaQuery.of(context).size.width * 0.1,
                    right: MediaQuery.of(context).size.width * 0.1,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (!isFormValid || formState.isSubmitting)
                            ? null
                            : _finishRegistration,
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
                                'Завершить',
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

/// 🔹 Виджет кнопки выбора фото с предпросмотром
class _PhotoPickerButton extends StatelessWidget {
  /// 🔹 Выбранное фото
  final File? selectedPhoto;

  /// 🔹 Обработчик нажатия
  final VoidCallback onTap;

  /// 🔹 Флаг наличия ошибки
  final bool hasError;

  /// 🔹 Текст ошибки
  final String? errorText;

  const _PhotoPickerButton({
    required this.selectedPhoto,
    required this.onTap,
    this.hasError = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    // 🔹 Ширина кнопки (квадрат)
    final double buttonSize = MediaQuery.of(context).size.width * 0.7;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xll),
              color: AppColors.twinchip.withValues(alpha: 0.2),
              border: hasError
                  ? Border.all(color: Colors.red, width: 2)
                  : selectedPhoto != null
                  ? Border.all(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: selectedPhoto != null
                ? // 🔹 Показываем выбранное фото
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xll),
                    child: Image.file(
                      selectedPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.twinchip,
                          child: const Icon(
                            CupertinoIcons.photo,
                            size: 48,
                            color: AppColors.textPlaceholder,
                          ),
                        );
                      },
                    ),
                  )
                : // 🔹 Показываем иконку выбора фото
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.camera,
                        size: 28,
                        color: AppColors.surface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Выбрать фото',
                        style: TextStyle(
                          color: AppColors.surface.withValues(alpha: 0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        // 🔹 Надпись "Аватар" и круглая фотография (показываются только при выборе фото)
        if (selectedPhoto != null) ...[
          const SizedBox(height: 40),
          const Text(
            'Аватар',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          // 🔹 Круглое изображение 100x100 с выбранной фотографией
          const SizedBox(height: 12),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.twinchip,
              border: Border.all(
                color: AppColors.surface.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(
              child: Image.file(
                selectedPhoto!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.twinchip,
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 32,
                      color: AppColors.textPlaceholder,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        // 🔹 Показываем ошибку под кнопкой, если есть
        if (hasError && errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
