import 'dart:ui';
import "package:flutter/material.dart";
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/phone_input_field.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';

/// 🔹 Обёртка для экрана входа
/// Используется для маршрутизации и возможного расширения функционала
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Возвращаем основной экран входа с вводом телефона
    return const EnterAccScreen();
  }
}

/// 🔹 Основной экран входа с вводом телефона
class EnterAccScreen extends ConsumerStatefulWidget {
  const EnterAccScreen({super.key});

  @override
  ConsumerState<EnterAccScreen> createState() => _EnterAccScreenState();
}

class _EnterAccScreenState extends ConsumerState<EnterAccScreen> {
  /// 🔹 Контроллер для поля ввода телефона
  final TextEditingController phoneController = TextEditingController();

  /// 🔹 Флаг валидности телефона
  bool _isPhoneValid = false;

  @override
  void dispose() {
    // 🔹 Освобождаем контроллер при уничтожении виджета
    phoneController.dispose();
    super.dispose();
  }

  /// 🔹 Обработка нажатия кнопки "Войти"
  void _handleLogin() {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // 🔹 Проверяем валидность телефона
    if (!_isPhoneValid) {
      ref
          .read(formStateProvider.notifier)
          .setError('Введите корректный номер телефона');
      return;
    }

    // 🔹 Переходим на экран ввода SMS-кода
    Navigator.pushReplacementNamed(
      context,
      '/loginsms',
      arguments: {'phone': phoneController.text},
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // 🔹 Отключаем автоматическую прокрутку Scaffold, используем свою
          resizeToAvoidBottomInset: true,
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
                      // ─────────── Логотип на 1/3 от высоты экрана ───────────
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).size.height * 0.085,
                          ),
                          child: Opacity(
                            opacity: 0.9,
                            child: Image.asset(
                              'assets/gorizont.png',
                              width: 180,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      // ─────────── Форма внизу ───────────
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).size.height * 0.1,
                            left: MediaQuery.of(context).size.width * 0.1,
                            right: MediaQuery.of(context).size.width * 0.1,
                          ),
                          child: SingleChildScrollView(
                            // 🔹 Прокручиваем контент при появлении клавиатуры
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🔹 Используем общий виджет для ввода телефона
                                PhoneInputField(
                                  controller: phoneController,
                                  onValidationChanged: (isValid) {
                                    setState(() {
                                      _isPhoneValid = isValid;
                                    });
                                    // 🔹 Очищаем ошибку при изменении валидности
                                    if (isValid) {
                                      ref
                                          .read(formStateProvider.notifier)
                                          .clearErrors();
                                    }
                                  },
                                ),
                                // 🔹 Показываем ошибки, если есть
                                Builder(
                                  builder: (context) {
                                    final formState = ref.watch(
                                      formStateProvider,
                                    );
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
                                const SizedBox(height: 20),
                                Builder(
                                  builder: (context) {
                                    final formState = ref.watch(
                                      formStateProvider,
                                    );
                                    return SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            (formState.isSubmitting ||
                                                !_isPhoneValid)
                                            ? null
                                            : _handleLogin,
                                        style: ButtonStyle(
                                          backgroundColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.disabled,
                                                )) {
                                                  return AppColors.disabledBg
                                                      .withValues(alpha: 0.5);
                                                }
                                                return AppColors.getSurfaceColor(
                                                  context,
                                                );
                                              }),
                                          foregroundColor:
                                              WidgetStateProperty.resolveWith((
                                                states,
                                              ) {
                                                if (states.contains(
                                                  WidgetState.disabled,
                                                )) {
                                                  return AppColors.textPrimary
                                                      .withValues(alpha: 0.5);
                                                }
                                                return AppColors.textPrimary;
                                              }),
                                          padding: const WidgetStatePropertyAll(
                                            EdgeInsets.symmetric(vertical: 15),
                                          ),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.xxl,
                                                  ),
                                            ),
                                          ),
                                          elevation:
                                              const WidgetStatePropertyAll(0),
                                        ),
                                        child: formState.isSubmitting
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CupertinoActivityIndicator(
                                                      radius: 10,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                              )
                                            : const Text(
                                                "Получить код",
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ─────────── Кнопка "Назад" в верхнем левом углу ───────────
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.076,
                    left: 16,
                    child: Builder(
                      builder: (context) {
                        final formState = ref.watch(formStateProvider);
                        return TextButton(
                          onPressed: formState.isSubmitting
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  '/home',
                                ),
                          style: const ButtonStyle(
                            overlayColor: WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                            animationDuration: Duration(milliseconds: 0),
                            padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
                            minimumSize: WidgetStatePropertyAll(Size(40, 40)),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.surface,
                            size: 24,
                          ),
                        );
                      },
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
