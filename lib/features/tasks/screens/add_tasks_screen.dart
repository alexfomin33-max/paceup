import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/interactive_back_swipe.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';
import '../../leaderboard/widgets/date_range_picker.dart';
import '../providers/tasks_provider.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  // ── контроллеры
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final parameterValueCtrl = TextEditingController();
  final startDateCtrl = TextEditingController();
  final endDateCtrl = TextEditingController();

  // ── FocusNode для полей дат
  final startDateFocusNode = FocusNode();
  final endDateFocusNode = FocusNode();

  // ── выборы
  String? activity;
  String?
  activityParameter; // Параметр активности: distance, elevation, duration, steps, count, days, weeks
  String? periodType; // Тип периода: "Месяц" или "Выбранный период"
  String? selectedMonth; // Выбранный месяц (1-12) для типа "Месяц"

  // ── медиа
  File? logoFile;
  File? backgroundFile;

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.1;

  bool get isFormValid {
    if (nameCtrl.text.trim().isEmpty ||
        descCtrl.text.trim().isEmpty ||
        activity == null ||
        activityParameter == null ||
        parameterValueCtrl.text.trim().isEmpty ||
        periodType == null) {
      return false;
    }
    // ── если выбран "Месяц", должен быть выбран месяц
    if (periodType == 'Месяц' && selectedMonth == null) {
      return false;
    }
    // ── если выбран "Выбранный период", должны быть заполнены обе даты
    if (periodType == 'Выбранный период') {
      final startDigits = startDateCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final endDigits = endDateCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      if (startDigits.length != 8 || endDigits.length != 8) {
        return false;
      }
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    descCtrl.addListener(() {
      _refresh();
      _clearFieldError('full_description');
    });
    parameterValueCtrl.addListener(() {
      _refresh();
      _clearFieldError('parameterValue');
    });
    startDateCtrl.addListener(() {
      _refresh();
      _clearFieldError('startDate');
    });
    endDateCtrl.addListener(() {
      _refresh();
      _clearFieldError('endDate');
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    parameterValueCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    startDateFocusNode.dispose();
    endDateFocusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── очистка ошибки для конкретного поля при взаимодействии
  void _clearFieldError(String fieldName) {
    ref.read(formStateProvider.notifier).clearFieldError(fieldName);
  }

  // ── форматирует дату в формат "dd.MM.yyyy"
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  Future<void> _pickLogo() async {
    // ── выбираем логотип с обрезкой в фиксированную пропорцию 1:1
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _logoAspectRatio,
      maxSide: ImageCompressionPreset.logo.maxSide,
      jpegQuality: ImageCompressionPreset.logo.quality,
      cropTitle: 'Обрезка логотипа',
    );
    if (processed == null || !mounted) return;

    if (mounted) {
      setState(() => logoFile = processed);
    }
  }

  Future<void> _pickBackground() async {
    // ── выбираем фон с обрезкой 2.1:1 и сжатием до оптимального размера
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _backgroundAspectRatio,
      maxSide: ImageCompressionPreset.background.maxSide,
      jpegQuality: ImageCompressionPreset.background.quality,
      cropTitle: 'Обрезка фонового фото',
    );
    if (processed == null || !mounted) return;

    if (mounted) {
      setState(() => backgroundFile = processed);
    }
  }

  Future<void> _submit() async {
    final formNotifier = ref.read(formStateProvider.notifier);

    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Map<String, String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors['name'] = 'Введите название задачи';
    }
    if (descCtrl.text.trim().isEmpty) {
      newErrors['full_description'] = 'Введите полное описание';
    }
    if (activity == null) {
      newErrors['activity'] = 'Выберите вид активности';
    }
    if (activityParameter == null) {
      newErrors['activityParameter'] = 'Выберите параметр';
    }
    if (parameterValueCtrl.text.trim().isEmpty) {
      newErrors['parameterValue'] = 'Введите значение';
    }
    if (periodType == null) {
      newErrors['periodType'] = 'Выберите период';
    } else if (periodType == 'Месяц' && selectedMonth == null) {
      newErrors['selectedMonth'] = 'Выберите месяц';
    } else if (periodType == 'Выбранный период') {
      final startDigits = startDateCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      final endDigits = endDateCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
      if (startDigits.length != 8) {
        newErrors['startDate'] = 'Введите дату начала';
      }
      if (endDigits.length != 8) {
        newErrors['endDate'] = 'Введите дату окончания';
      }
    }

    // ── если есть ошибки — не отправляем форму
    if (newErrors.isNotEmpty) {
      formNotifier.setFieldErrors(newErrors);
      return;
    }

    // ── форма валидна — отправляем на сервер
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    await formNotifier.submit(
      () async {
        // Формируем данные
        final files = <String, File>{};
        final fields = <String, String>{};

        // Добавляем логотип
        if (logoFile != null) {
          files['logo'] = logoFile!;
        }

        // Добавляем фоновую картинку (image)
        if (backgroundFile != null) {
          files['image'] = backgroundFile!;
        }

        // Добавляем поля формы
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Ошибка авторизации. Необходимо войти в систему');
        }
        fields['user_id'] = userId.toString();
        fields['name'] = nameCtrl.text.trim();
        fields['full_description'] = descCtrl.text.trim();
        fields['type'] = activity!;
        fields['metric_type'] = activityParameter!;
        final targetValue = double.tryParse(parameterValueCtrl.text.trim());
        if (targetValue == null || targetValue <= 0) {
          throw Exception('Введите корректное значение параметра');
        }
        fields['target_value'] = targetValue.toString();

        // ── Устанавливаем даты в зависимости от выбранного периода
        if (periodType == 'Месяц' && selectedMonth != null) {
          // ── Выбран месяц: используем начало и конец выбранного месяца текущего года
          final month = int.parse(selectedMonth!);
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, month, 1);
          final endOfMonth = DateTime(now.year, month + 1, 0, 23, 59, 59);
          fields['date_start'] = startOfMonth
              .toIso8601String()
              .substring(0, 19)
              .replaceAll('T', ' ');
          fields['date_end'] = endOfMonth
              .toIso8601String()
              .substring(0, 19)
              .replaceAll('T', ' ');
        } else if (periodType == 'Выбранный период') {
          // ── Выбранный период: парсим даты из полей ввода
          final startDateStr = startDateCtrl.text;
          final endDateStr = endDateCtrl.text;
          final startParts = startDateStr.split('.');
          final endParts = endDateStr.split('.');

          if (startParts.length == 3 && endParts.length == 3) {
            final startDate = DateTime(
              int.parse(startParts[2]), // год
              int.parse(startParts[1]), // месяц
              int.parse(startParts[0]), // день
            );
            final endDate = DateTime(
              int.parse(endParts[2]), // год
              int.parse(endParts[1]), // месяц
              int.parse(endParts[0]), // день
              23,
              59,
              59, // конец дня
            );
            fields['date_start'] = startDate
                .toIso8601String()
                .substring(0, 19)
                .replaceAll('T', ' ');
            fields['date_end'] = endDate
                .toIso8601String()
                .substring(0, 19)
                .replaceAll('T', ' ');
          } else {
            throw Exception('Ошибка парсинга дат');
          }
        } else {
          throw Exception('Не выбран период');
        }

        // Отправляем запрос
        Map<String, dynamic> data;
        if (files.isEmpty) {
          // JSON запрос без файлов
          data = await api.post('/create_task.php', body: fields);
        } else {
          // Multipart запрос с файлами
          data = await api.postMultipart(
            '/create_task.php',
            files: files,
            fields: fields,
            timeout: const Duration(seconds: 60),
          );
        }

        // Проверяем ответ
        // Обрабатываем разные форматы ответа: success может быть bool или String
        final successValue = data['success'];
        final isSuccess = successValue == true || successValue == 'true';
        if (!isSuccess) {
          final errorMessage =
              data['message']?.toString() ?? 'Ошибка при создании задачи';
          throw Exception(errorMessage);
        }

        // Инвалидируем провайдеры списков задач, чтобы экраны active_content и available_content обновились при возврате
        ref.invalidate(userTasksProvider);
        ref.invalidate(tasksProvider);
      },
      onSuccess: () {
        if (!mounted) return;
        // Закрываем экран создания задачи и возвращаемся на экран задач с результатом
        Navigator.of(context).pop('created');
      },
    );
  }

  /// Кнопка сохранения
  /// При загрузке: только индикатор (без текста), тёмный фон, блокировка нажатий.
  /// Активна только когда все поля заполнены и меню выбраны.
  Widget _buildSaveButton() {
    final formState = ref.watch(formStateProvider);
    final textColor = AppColors.getSurfaceColor(context);
    final isLoading = formState.isSubmitting;
    final isValid = isFormValid;

    // ────────────────────────────────────────────────────────────────
    // 💾 КНОПКА СОХРАНЕНИЯ (единый стиль с экраном редактирования)
    // ────────────────────────────────────────────────────────────────
    // disabledBackgroundColor = AppColors.button — кнопка остаётся тёмной при загрузке
    // При невалидной форме: уменьшенная непрозрачность для визуальной индикации
    final button = Opacity(
      opacity: isValid ? 1.0 : 0.5,
      child: ElevatedButton(
        onPressed: isLoading || !isValid ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: textColor,
          disabledBackgroundColor: AppColors.button,
          disabledForegroundColor: textColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          shape: const StadiumBorder(),
          minimumSize: const Size(double.infinity, 50),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.center,
        ),
        child: isLoading
            ? CupertinoActivityIndicator(radius: 9, color: textColor)
            : Text(
                'Создать задачу',
                style: AppTextStyles.h15w5.copyWith(
                  color: textColor,
                  height: 1.0,
                ),
              ),
      ),
    );

    // Блокировка нажатий во время загрузки (onPressed: null уже отключает, дублируем на всякий)
    if (isLoading) {
      return IgnorePointer(child: button);
    }

    return button;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Создание задачи',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: GestureDetector(
          // ── скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Медиа: логотип + фоновая картинка ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Логотип',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MediaTile(
                            file: logoFile,
                            onPick: _pickLogo,
                            onRemove: () => setState(() => logoFile = null),
                            width: 90,
                            height: 90,
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Фоновая картинка',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MediaTile(
                              file: backgroundFile,
                              onPick: _pickBackground,
                              onRemove: () =>
                                  setState(() => backgroundFile = null),
                              width:
                                  189, // Ширина для соотношения 2.1:1 (90 * 2.1)
                              height: 90,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Название задачи ----------
                  Text(
                    'Название задачи',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: formState.fieldErrors.containsKey('name')
                            ? AppColors.error
                            : AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: TextField(
                      controller: nameCtrl,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Введите название задачи',
                        hintStyle: AppTextStyles.h14w4Place,
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 22,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Вид активности ----------
                  Text(
                    'Вид активности',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: formState.fieldErrors.containsKey('activity')
                            ? AppColors.error
                            : AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: Builder(
                      builder: (context) => InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.getSurfaceColor(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activity,
                            isExpanded: true,
                            hint: const Text(
                              'Выберите вид активности',
                              style: AppTextStyles.h14w4Place,
                            ),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  activity = newValue;
                                  _clearFieldError('activity');
                                });
                              }
                            },
                            dropdownColor: AppColors.getSurfaceColor(context),
                            menuMaxHeight: 300,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'general',
                                child: Text('Общий'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'run',
                                child: Text('Бег'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'bike',
                                child: Text('Велосипед'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'swim',
                                child: Text('Плавание'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'walk',
                                child: Text('Ходьба'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ski',
                                child: Text('Лыжи'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Период ----------
                  Text(
                    'Период',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: formState.fieldErrors.containsKey('periodType')
                            ? AppColors.error
                            : AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: Builder(
                      builder: (context) => InputDecorator(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.getSurfaceColor(context),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: periodType,
                            isExpanded: true,
                            hint: const Text(
                              'Выберите период',
                              style: AppTextStyles.h14w4Place,
                            ),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  periodType = newValue;
                                  if (newValue != 'Месяц') {
                                    selectedMonth = null;
                                  }
                                  if (newValue != 'Выбранный период') {
                                    startDateCtrl.clear();
                                    endDateCtrl.clear();
                                  }
                                  _clearFieldError('periodType');
                                });
                              }
                            },
                            dropdownColor: AppColors.getSurfaceColor(context),
                            menuMaxHeight: 300,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.getIconSecondaryColor(context),
                            ),
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                            items: const [
                              DropdownMenuItem<String>(
                                value: 'Месяц',
                                child: Text('Месяц'),
                              ),
                              DropdownMenuItem<String>(
                                value: 'Выбранный период',
                                child: Text('Выбранный период'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Выпадающий список месяцев (появляется при выборе "Месяц")
                  if (periodType == 'Месяц') ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: formState.fieldErrors.containsKey(
                            'selectedMonth',
                          )
                              ? AppColors.error
                              : AppColors.twinchip,
                          width: 0.7,
                        ),
                      ),
                      child: Builder(
                        builder: (context) => InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.getSurfaceColor(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedMonth,
                              isExpanded: true,
                              hint: const Text(
                                'Выберите месяц',
                                style: AppTextStyles.h14w4Place,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedMonth = newValue;
                                    _clearFieldError('selectedMonth');
                                  });
                                }
                              },
                              dropdownColor: AppColors.getSurfaceColor(context),
                              menuMaxHeight: 300,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                              style: AppTextStyles.h14w4.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                              items: const [
                                DropdownMenuItem<String>(
                                  value: '1',
                                  child: Text('Январь'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '2',
                                  child: Text('Февраль'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '3',
                                  child: Text('Март'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '4',
                                  child: Text('Апрель'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '5',
                                  child: Text('Май'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '6',
                                  child: Text('Июнь'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '7',
                                  child: Text('Июль'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '8',
                                  child: Text('Август'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '9',
                                  child: Text('Сентябрь'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '10',
                                  child: Text('Октябрь'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '11',
                                  child: Text('Ноябрь'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '12',
                                  child: Text('Декабрь'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  // ── Поля для выбора дат (появляются при выборе "Выбранный период")
                  if (periodType == 'Выбранный период') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          flex: 2,
                          child: DateField(
                            controller: startDateCtrl,
                            focusNode: startDateFocusNode,
                            hintText: _formatDate(DateTime.now()),
                            onComplete: () {
                              endDateFocusNode.requestFocus();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '—',
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: DateField(
                            controller: endDateCtrl,
                            focusNode: endDateFocusNode,
                            hintText: _formatDate(DateTime.now()),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ---------- Параметр ----------
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Параметр',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                  color: formState.fieldErrors.containsKey(
                                    'activityParameter',
                                  )
                                      ? AppColors.error
                                      : AppColors.twinchip,
                                  width: 0.7,
                                ),
                              ),
                              child: Builder(
                                builder: (context) => InputDecorator(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.getSurfaceColor(context),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: activityParameter,
                                      isExpanded: true,
                                      hint: const Text(
                                        'Выберите параметр',
                                        style: AppTextStyles.h14w4Place,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            activityParameter = newValue;
                                            _clearFieldError('activityParameter');
                                          });
                                        }
                                      },
                                      dropdownColor: AppColors.getSurfaceColor(
                                        context,
                                      ),
                                      menuMaxHeight: 300,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: AppColors.getIconSecondaryColor(
                                          context,
                                        ),
                                      ),
                                      style: AppTextStyles.h14w4.copyWith(
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: 'distance',
                                          child: Text('Дистанция'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'elevation',
                                          child: Text('Набор высоты'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'duration',
                                          child: Text('Длительность'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'steps',
                                          child: Text('Количество шагов'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'count',
                                          child: Text('Количество'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'days',
                                          child: Text('Количество дней'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'weeks',
                                          child: Text('Количество недель'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ── текстовое поле для значения параметра
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 31),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: formState.fieldErrors.containsKey(
                                  'parameterValue',
                                )
                                    ? AppColors.error
                                    : AppColors.twinchip,
                                width: 0.7,
                              ),
                            ),
                            child: Builder(
                              builder: (context) => TextField(
                                controller: parameterValueCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: activityParameter == 'distance'
                                      ? '0 км'
                                      : activityParameter == 'elevation'
                                      ? '0 метров'
                                      : activityParameter == 'duration'
                                      ? '0 минут'
                                      : activityParameter == 'steps'
                                      ? '0 шагов'
                                      : activityParameter == 'count'
                                      ? '0'
                                      : activityParameter == 'days'
                                      ? '0 дней'
                                      : activityParameter == 'weeks'
                                      ? '0 недель'
                                      : '0',
                                  hintStyle: AppTextStyles.h14w4Place,
                                  filled: true,
                                  fillColor: AppColors.getSurfaceColor(context),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 22,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Полное описание ----------
                  Text(
                    'Описание задачи',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: formState.fieldErrors.containsKey(
                          'full_description',
                        )
                            ? AppColors.error
                            : AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: Builder(
                      builder: (context) => TextField(
                        controller: descCtrl,
                        maxLines: 12,
                        minLines: 8,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Добавьте описание задачи',
                          hintStyle: AppTextStyles.h14w4Place.copyWith(
                            color: AppColors.getTextPlaceholderColor(context),
                          ),
                          filled: true,
                          fillColor: AppColors.getSurfaceColor(context),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Показываем ошибки, если есть
                  if (formState.hasErrors) ...[
                    FormErrorDisplay(formState: formState),
                    const SizedBox(height: 16),
                  ],

                  Center(
                    child: _buildSaveButton(),
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

//
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ ---------------------------
//

class _MediaTile extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double width;
  final double height;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // ── если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: AppColors.twinphoto,
            border: Border.all(
              color: AppColors.twinchip,
              width: 0.7,
            ),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.camera_fill,
              size: 24,
              color: AppColors.scrim20,
            ),
          ),
        ),
      );
    }

    // ── если фото выбрано — превью без рамки
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: AppColors.getBackgroundColor(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              file!,
              fit: BoxFit.cover,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) => Container(
                width: width,
                height: height,
                color: AppColors.getBackgroundColor(context),
                child: Icon(
                  CupertinoIcons.photo,
                  size: 24,
                  color: AppColors.getIconSecondaryColor(context),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.getBorderColor(context),
                ),
              ),
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                size: 20,
                color: AppColors.error,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
