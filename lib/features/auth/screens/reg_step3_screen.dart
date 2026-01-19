import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';
import '../../../../providers/services/api_provider.dart';

/// 🔹 Третий экран регистрации — ввод города проживания
/// Шаг 3 из 6 в процессе регистрации
class RegStep3Screen extends ConsumerStatefulWidget {
  /// 🔹 ID пользователя, передается с предыдущего экрана
  final int userId;

  const RegStep3Screen({super.key, required this.userId});

  @override
  ConsumerState<RegStep3Screen> createState() => _RegStep3ScreenState();
}

class _RegStep3ScreenState extends ConsumerState<RegStep3Screen> {
  /// 🔹 Контроллер для поля ввода города
  final TextEditingController cityController = TextEditingController();

  /// 🔹 Список городов для автокомплита (загружается из БД)
  List<String> _cities = [];

  /// 🔹 Выбранный город из списка (для валидации)
  String? _selectedCity;

  /// 🔹 Проверка корректности заполнения формы
  bool get isFormValid {
    return _selectedCity != null && _selectedCity!.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // 🔹 Очищаем ошибку при изменении поля
    Future.microtask(() {
      final formNotifier = ref.read(formStateProvider.notifier);
      cityController.addListener(() {
        formNotifier.clearGeneralError();
        formNotifier.clearFieldError('city');
        // Если текст изменился не через выбор из списка, сбрасываем выбранный город
        if (cityController.text.trim() != _selectedCity) {
          _selectedCity = null;
        }
      });
      // Загружаем список городов из БД
      _loadCities();
    });
  }

  /// 🔹 Загрузка списка городов из БД через API
  Future<void> _loadCities() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api
          .get('/get_cities.php')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Превышено время ожидания загрузки городов',
              );
            },
          );

      if (data['success'] == true && data['cities'] != null) {
        final cities = data['cities'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _cities = cities.map((city) => city.toString()).toList();
          });
        }
      }
    } catch (e) {
      // В случае ошибки оставляем пустой список
      // Пользователь все равно сможет ввести город вручную
      // Ошибка не критична, так как автокомплит работает и без списка
    }
  }

  @override
  void dispose() {
    // 🔹 Освобождаем контроллер при уничтожении виджета
    cityController.dispose();
    super.dispose();
  }

  /// 🔹 Метод проверки валидности формы и перехода на следующий экран
  Future<void> _checkAndContinue() async {
    final formState = ref.read(formStateProvider);

    // 🔹 Проверяем, что город выбран из списка
    final formNotifier = ref.read(formStateProvider.notifier);
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      formNotifier.setFieldErrors({'city': 'Выберите город из списка'});
      return;
    }

    if (!isFormValid || formState.isSubmitting) return;

    // 🔹 Проверка, что виджет ещё монтирован перед использованием context
    if (!mounted) return;

    // 🔹 Переходим на следующий экран регистрации
    Navigator.pushReplacementNamed(
      context,
      '/regstep4',
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
                                  'Город проживания',
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
                                  'Необходим для отображения лидерборда',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Inter',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 50),
                                // 🔹 Поле ввода города с автокомплитом
                                _CityAutocompleteField(
                                  controller: cityController,
                                  suggestions: _cities,
                                  hasError: formState.fieldErrors.containsKey(
                                    'city',
                                  ),
                                  errorText: formState.fieldErrors['city'],
                                  onSelected: (city) {
                                    setState(() {
                                      _selectedCity = city;
                                      cityController.text = city;
                                    });
                                    ref
                                        .read(formStateProvider.notifier)
                                        .clearFieldError('city');
                                  },
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
                                  '/reg_step2',
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
                                  widthFactor: 3 / 5,
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
                          '3/5',
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

//
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---------------------------
//

// ── автокомплит для города
class _CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;
  final bool hasError;
  final String? errorText;

  const _CityAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.hasError = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final query = textEditingValue.text.toLowerCase();
        return suggestions.where((city) {
          return city.toLowerCase().startsWith(query);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            // Инициализируем текст из внешнего контроллера
            if (textEditingController.text.isEmpty &&
                controller.text.isNotEmpty) {
              textEditingController.text = controller.text;
            }

            // Синхронизируем изменения в Autocomplete контроллере с внешним
            textEditingController.addListener(() {
              if (textEditingController.text != controller.text) {
                controller.text = textEditingController.text;
              }
            });

            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (String value) {
                onFieldSubmitted();
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontFamily: 'Inter',
              ),
              decoration: InputDecoration(
                hintText: 'Введите город',
                hintStyle: const TextStyle(
                  color: AppColors.textPlaceholder,
                  fontSize: 15,
                  fontFamily: 'Inter',
                ),
                filled: true,
                fillColor: AppColors.twinchip,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                errorText: hasError
                    ? (errorText ?? 'Выберите город из списка')
                    : null,
                errorMaxLines: 2,
              ),
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}
