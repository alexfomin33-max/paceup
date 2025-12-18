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
import '../../../core/widgets/primary_button.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  // ── контроллеры
  final nameCtrl = TextEditingController();
  final shortDescCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final parameterValueCtrl = TextEditingController();

  // ── выборы
  String? activity;
  String? activityParameter; // Параметр активности: distance, elevation, duration, steps, count, days, weeks

  // ── медиа
  File? logoFile;
  File? backgroundFile;

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.3;

  bool get isFormValid =>
      nameCtrl.text.trim().isNotEmpty &&
      shortDescCtrl.text.trim().isNotEmpty &&
      descCtrl.text.trim().isNotEmpty &&
      activity != null &&
      activityParameter != null &&
      parameterValueCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    shortDescCtrl.addListener(() {
      _refresh();
      _clearFieldError('short_description');
    });
    descCtrl.addListener(() {
      _refresh();
      _clearFieldError('full_description');
    });
    parameterValueCtrl.addListener(() {
      _refresh();
      _clearFieldError('parameterValue');
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    shortDescCtrl.dispose();
    descCtrl.dispose();
    parameterValueCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── очистка ошибки для конкретного поля при взаимодействии
  void _clearFieldError(String fieldName) {
    ref.read(formStateProvider.notifier).clearFieldError(fieldName);
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

    setState(() => logoFile = processed);
  }

  Future<void> _pickBackground() async {
    // ── выбираем фон с обрезкой 2.3:1 и сжатием до оптимального размера
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _backgroundAspectRatio,
      maxSide: ImageCompressionPreset.background.maxSide,
      jpegQuality: ImageCompressionPreset.background.quality,
      cropTitle: 'Обрезка фонового фото',
    );
    if (processed == null || !mounted) return;

    setState(() => backgroundFile = processed);
  }

  Future<void> _submit() async {
    final formNotifier = ref.read(formStateProvider.notifier);

    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Map<String, String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors['name'] = 'Введите название задачи';
    }
    if (shortDescCtrl.text.trim().isEmpty) {
      newErrors['short_description'] = 'Введите короткое описание';
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
        fields['short_description'] = shortDescCtrl.text.trim();
        fields['full_description'] = descCtrl.text.trim();
        fields['type'] = activity!;
        fields['metric_type'] = activityParameter!;
        final targetValue = double.tryParse(parameterValueCtrl.text.trim());
        if (targetValue == null || targetValue <= 0) {
          throw Exception('Введите корректное значение параметра');
        }
        fields['target_value'] = targetValue.toString();
        
        // Устанавливаем даты (можно будет добавить выбор дат в форме позже)
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        fields['date_start'] = startOfMonth.toIso8601String().substring(0, 19).replaceAll('T', ' ');
        fields['date_end'] = endOfMonth.toIso8601String().substring(0, 19).replaceAll('T', ' ');

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
          final errorMessage = data['message']?.toString() ?? 'Ошибка при создании задачи';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Закрываем экран создания задачи и возвращаемся на экран задач с результатом
        Navigator.of(context).pop('created');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Создание задачи'),
        body: GestureDetector(
          // ── скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
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
                            'Логотип задачи',
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
                                  207, // Ширина для соотношения 2.3:1 (90 * 2.3)
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
                  TextField(
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
                        vertical: 17,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: formState.fieldErrors.containsKey('name')
                              ? AppColors.error
                              : AppColors.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: formState.fieldErrors.containsKey('name')
                              ? AppColors.error
                              : AppColors.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(
                          color: formState.fieldErrors.containsKey('name')
                              ? AppColors.error
                              : AppColors.getBorderColor(context),
                          width: 1,
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
                  Builder(
                    builder: (context) => InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('activity')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('activity')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('activity')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
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
                          borderRadius: BorderRadius.circular(AppRadius.md),
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
                          ],
                        ),
                      ),
                    ),
                  ),
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
                            Builder(
                              builder: (context) => InputDecorator(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.getSurfaceColor(context),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color:
                                          formState.fieldErrors.containsKey(
                                            'activityParameter',
                                          )
                                          ? AppColors.error
                                          : AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color:
                                          formState.fieldErrors.containsKey(
                                            'activityParameter',
                                          )
                                          ? AppColors.error
                                          : AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color:
                                          formState.fieldErrors.containsKey(
                                            'activityParameter',
                                          )
                                          ? AppColors.error
                                          : AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
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
                                      AppRadius.md,
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // ── текстовое поле для значения параметра
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 31),
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
                                  vertical: 17,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color:
                                        formState.fieldErrors.containsKey(
                                          'parameterValue',
                                        )
                                        ? AppColors.error
                                        : AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color:
                                        formState.fieldErrors.containsKey(
                                          'parameterValue',
                                        )
                                        ? AppColors.error
                                        : AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color:
                                        formState.fieldErrors.containsKey(
                                          'parameterValue',
                                        )
                                        ? AppColors.error
                                        : AppColors.getBorderColor(context),
                                    width: 1,
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

                  // ---------- Короткое описание ----------
                  Text(
                    'Короткое описание задачи',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => TextField(
                      controller: shortDescCtrl,
                      maxLines: 3,
                      minLines: 2,
                      textAlignVertical: TextAlignVertical.top,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Введите короткое описание задачи',
                        hintStyle: AppTextStyles.h14w4Place,
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('short_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('short_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('short_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Полное описание ----------
                  Text(
                    'Полное описание',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => TextField(
                      controller: descCtrl,
                      maxLines: 12,
                      minLines: 7,
                      textAlignVertical: TextAlignVertical.top,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Введите полное описание задачи',
                        hintStyle: AppTextStyles.h14w4Place,
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('full_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('full_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: formState.fieldErrors.containsKey('full_description')
                                ? AppColors.error
                                : AppColors.getBorderColor(context),
                            width: 1,
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

                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Создать задачу',
                      onPressed: () {
                        if (!formState.isSubmitting) _submit();
                      },
                      expanded: false,
                      isLoading: formState.isSubmitting,
                      enabled: isFormValid && !formState.isSubmitting,
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
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.getSurfaceColor(context),
            border: Border.all(color: AppColors.getBorderColor(context)),
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 28,
              color: AppColors.getIconSecondaryColor(context),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                border: Border.all(color: AppColors.getBorderColor(context)),
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
