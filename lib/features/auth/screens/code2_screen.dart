import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../lenta/providers/lenta_provider.dart';
import '../../../providers/services/api_provider.dart';

/// 🔹 Экран для повторения кода доступа (4-значный PIN)
class Code2Screen extends ConsumerStatefulWidget {
  /// 🔹 Код, введённый на предыдущем экране (Code1Screen)
  final String firstCode;

  /// 🔹 ID пользователя для передачи на экран ленты
  final int userId;

  const Code2Screen({super.key, required this.firstCode, required this.userId});

  @override
  ConsumerState<Code2Screen> createState() => _Code2ScreenState();
}

class _Code2ScreenState extends ConsumerState<Code2Screen> {
  /// 🔹 Введённый код доступа (максимум 4 цифры)
  String _code = '';

  /// 🔹 Состояние анимации индикаторов: null - нет анимации, 'success' - успех, 'error' - ошибка
  String? _animationState;

  /// 🔹 Текущий индекс индикатора для анимации (0-3)
  int _animationIndex = -1;

  /// 🔹 Обработка нажатия на цифру
  void _onNumberPressed(String number) {
    // 🔹 Блокируем ввод во время анимации
    if (_animationState != null) return;

    if (_code.length < 4) {
      setState(() {
        _code += number;
      });

      // 🔹 Если код полностью введён (4 цифры), проверяем совпадение
      if (_code.length == 4) {
        _checkCode();
      }
    }
  }

  /// 🔹 Проверка совпадения кода и запуск анимации индикаторов
  Future<void> _checkCode() async {
    // 🔹 Определяем тип анимации в зависимости от результата проверки
    final isMatch = _code == widget.firstCode;
    _animationState = isMatch ? 'success' : 'error';

    // 🔹 Все индикаторы окрашиваются одновременно (зеленый при успехе, красный при ошибке)
    setState(() {
      _animationIndex = 3; // Все индикаторы окрашены одновременно
    });

    if (isMatch) {
      // 🔹 При успехе: сохраняем PIN-код в базу данных
      await _savePinCode(_code);

      // 🔹 Загружаем данные ленты перед переходом
      // Это предотвращает показ skeleton loader на экране ленты
      developer.log(
        '[CODE2_SCREEN] Начинаем загрузку данных ленты перед переходом',
        name: 'Code2Screen',
      );

      try {
        // Загружаем сохраненные фильтры из SharedPreferences
        // Используем те же ключи, что и в lenta_screen.dart
        final prefs = await SharedPreferences.getInstance();
        final showTrainings =
            prefs.getBool('lenta_filter_show_trainings') ?? true;
        final showPosts = prefs.getBool('lenta_filter_show_posts') ?? true;
        final showOwn = prefs.getBool('lenta_filter_show_own') ?? true;
        final showOthers = prefs.getBool('lenta_filter_show_others') ?? true;

        // Загружаем данные ленты через провайдер
        await ref
            .read(lentaProvider(widget.userId).notifier)
            .loadInitial(
              showTrainings: showTrainings,
              showPosts: showPosts,
              showOwn: showOwn,
              showOthers: showOthers,
            );
        developer.log(
          '[CODE2_SCREEN] loadInitial() завершен',
          name: 'Code2Screen',
        );

        // ✅ Проверяем, что данные действительно загружены
        // Ждем, пока состояние провайдера обновится
        final stateAfter = ref.read(lentaProvider(widget.userId));
        developer.log(
          '[CODE2_SCREEN] Состояние провайдера ПОСЛЕ loadInitial: '
          'items.length=${stateAfter.items.length}, '
          'isRefreshing=${stateAfter.isRefreshing}, '
          'currentPage=${stateAfter.currentPage}, '
          'hasMore=${stateAfter.hasMore}, '
          'error=${stateAfter.error}',
          name: 'Code2Screen',
        );

        if (stateAfter.items.isEmpty) {
          developer.log(
            '[CODE2_SCREEN] ⚠️ Данные пустые после loadInitial, ждем 100ms...',
            name: 'Code2Screen',
          );
          // Если данные не загрузились, ждем еще немного
          await Future.delayed(const Duration(milliseconds: 100));
          final stateAfterDelay = ref.read(lentaProvider(widget.userId));
          developer.log(
            '[CODE2_SCREEN] Состояние после задержки: '
            'items.length=${stateAfterDelay.items.length}, '
            'isRefreshing=${stateAfterDelay.isRefreshing}',
            name: 'Code2Screen',
          );
        } else {
          developer.log(
            '[CODE2_SCREEN] ✅ Данные успешно загружены: ${stateAfter.items.length} элементов',
            name: 'Code2Screen',
          );
        }
      } catch (e, stackTrace) {
        developer.log(
          '[CODE2_SCREEN] ❌ Ошибка при загрузке данных: $e',
          name: 'Code2Screen',
          error: e,
          stackTrace: stackTrace,
        );
        // Игнорируем ошибки загрузки - данные загрузятся на экране ленты
      }

      // 🔹 После загрузки данных переходим на экран ленты
      if (!mounted) {
        developer.log(
          '[CODE2_SCREEN] ⚠️ Виджет unmounted, не переходим на экран ленты',
          name: 'Code2Screen',
        );
        return;
      }

      developer.log(
        '[CODE2_SCREEN] Переходим на экран ленты...',
        name: 'Code2Screen',
      );

      Navigator.pushReplacementNamed(
        context,
        '/lenta',
        arguments: {'userId': widget.userId},
      );
    } else {
      // 🔹 При ошибке: после задержки сбрасываем состояние и очищаем поле
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _code = '';
          _animationState = null;
          _animationIndex = -1;
        });
      });
    }
  }

  /// 🔹 Обработка удаления последней цифры
  void _onDeletePressed() {
    // 🔹 Блокируем удаление во время анимации
    if (_animationState != null) return;

    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
      });
    }
  }

  /// 🔹 Сохранение PIN-кода в базу данных
  /// Вызывается после успешного подтверждения PIN-кода
  Future<void> _savePinCode(String pinCode) async {
    try {
      final api = ref.read(apiServiceProvider);
      
      final data = await api.post(
        '/save_pin_code.php',
        body: {
          'pin_code': pinCode,
          'user_id': widget.userId,
        },
      );

      if (kDebugMode) {
        debugPrint('save_pin_code response: $data');
      }

      if (data['success'] == true) {
        developer.log(
          '[CODE2_SCREEN] PIN-код успешно сохранен в базу данных',
          name: 'Code2Screen',
        );
      } else {
        developer.log(
          '[CODE2_SCREEN] Ошибка сохранения PIN-кода: ${data['message']}',
          name: 'Code2Screen',
        );
        // Не блокируем переход, даже если сохранение не удалось
        // PIN-код можно будет сохранить позже или пользователь сможет установить его заново
      }
    } catch (e, stackTrace) {
      developer.log(
        '[CODE2_SCREEN] Ошибка при сохранении PIN-кода: $e',
        name: 'Code2Screen',
        error: e,
        stackTrace: stackTrace,
      );
      // Не блокируем переход при ошибке сохранения
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
                            "Повторите код доступа",
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

                              // 🔹 Определяем цвет индикатора в зависимости от состояния анимации
                              Color indicatorColor;
                              Color borderColor;

                              if (_animationState != null &&
                                  _animationIndex >= index) {
                                // 🔹 Индикатор окрашен в цвет результата (зеленый/красный)
                                if (_animationState == 'success') {
                                  indicatorColor = AppColors.success;
                                  borderColor = AppColors.success;
                                } else {
                                  indicatorColor = AppColors.error;
                                  borderColor = AppColors.error;
                                }
                              } else if (isFilled) {
                                // 🔹 Обычное состояние: индикатор заполнен
                                indicatorColor = AppColors.surface;
                                borderColor = AppColors.surface.withValues(
                                  alpha: 0.7,
                                );
                              } else {
                                // 🔹 Индикатор пустой
                                indicatorColor = AppColors.textPrimary
                                    .withValues(alpha: 0.3);
                                borderColor = AppColors.surface.withValues(
                                  alpha: 0.7,
                                );
                              }

                              return Container(
                                width: 16,
                                height: 16,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: indicatorColor,
                                  border: Border.all(
                                    color: borderColor,
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
