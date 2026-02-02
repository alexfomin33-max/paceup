import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

/// 🔹 Экран для создания кода доступа (4-значный PIN)
class Code1Screen extends ConsumerStatefulWidget {
  const Code1Screen({super.key});

  @override
  ConsumerState<Code1Screen> createState() => _Code1ScreenState();
}

class _Code1ScreenState extends ConsumerState<Code1Screen> {
  /// 🔹 Введённый код доступа (максимум 4 цифры)
  String _code = '';

  /// 🔹 Обработка нажатия на цифру
  void _onNumberPressed(String number) {
    if (_code.length < 4) {
      setState(() {
        _code += number;
      });

      // 🔹 Если код полностью введён (4 цифры), переходим на следующий экран
      if (_code.length == 4) {
        // 🔹 Получаем userId из аргументов маршрута
        final args = ModalRoute.of(context)?.settings.arguments;
        final userId = (args is Map && args.containsKey('userId'))
            ? args['userId'] as int
            : null;

        if (userId != null) {
          // 🔹 Переходим на экран повторения кода с передачей кода и userId
          Navigator.pushReplacementNamed(
            context,
            '/code2',
            arguments: {'firstCode': _code, 'userId': userId},
          );
        }
      }
    }
  }

  /// 🔹 Обработка удаления последней цифры
  void _onDeletePressed() {
    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
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
      child: Scaffold(
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
                            'assets/white_logo.png',
                            width: 180,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                    // ─────────── Заголовок и индикаторы ввода кода с отступом 40% от верха ───────────
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.35,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔹 Заголовок
                          const Text(
                            "Задайте код доступа",
                            style: TextStyle(
                              color: AppColors.surface,
                              fontSize: 18,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          // 🔹 Индикаторы ввода кода (4 кружочка)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final isFilled = index < _code.length;
                              return Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled
                                      ? AppColors.surface
                                      : AppColors.textPrimary.withValues(
                                          alpha: 0.3,
                                        ),
                                  border: Border.all(
                                    color: AppColors.surface.withValues(
                                      alpha: 0.7,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    // ─────────── Цифровая клавиатура с отступом 10% от низа ───────────
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.1,
                      left: 0,
                      right: 0,
                      child: _buildNumpad(screenSize),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 🔹 Построение цифровой клавиатуры
  Widget _buildNumpad(Size screenSize) {
    // 🔹 Адаптивные размеры: промежуток между кнопками = 4% от ширины экрана
    final buttonSpacing = screenSize.width * 0.06;
    // 🔹 Адаптивный размер кнопки = 15% от ширины экрана
    final buttonSize = screenSize.width * 0.15;
    // 🔹 Адаптивный вертикальный отступ между строками = 2.5% от ширины экрана
    final rowSpacing = screenSize.width * 0.03;

    return Column(
      children: [
        // Первая строка: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('1', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('2', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('3', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Вторая строка: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('4', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('5', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('6', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Третья строка: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('7', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('8', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('9', buttonSize),
          ],
        ),
        SizedBox(height: rowSpacing),
        // Четвёртая строка: пустое место, 0, кнопка удаления
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Невидимая кнопка-заглушка для симметрии
            SizedBox(width: buttonSize, height: buttonSize),
            SizedBox(width: buttonSpacing),
            _buildNumberButton('0', buttonSize),
            SizedBox(width: buttonSpacing),
            _buildDeleteButton(buttonSize),
          ],
        ),
      ],
    );
  }

  /// 🔹 Создание кнопки с цифрой
  Widget _buildNumberButton(String number, double size) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Создание кнопки удаления
  Widget _buildDeleteButton(double size) {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textPrimary.withValues(alpha: 0.3),
          border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            color: AppColors.surface,
            size: 24,
          ),
        ),
      ),
    );
  }
}
