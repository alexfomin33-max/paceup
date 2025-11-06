import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  // ── контроллеры
  final nameCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // ── выборы
  String? activity = 'Бег';
  DateTime? foundationDate = DateTime.now();
  bool isOpenCommunity =
      false; // false = закрытое сообщество (по умолчанию выбрано)

  // ── список городов для автокомплита
  static const List<String> _cities = [
    'Москва',
    'Санкт-Петербург',
    'Владимир',
    'Суздаль',
    'Ярославль',
    'Нижний Новгород',
    'Иваново',
    'Казань',
    'Рязань',
    'Тула',
    'Тверь',
    'Орёл',
    'Кострома',
    'Воронеж',
    'Ростов',
    'Краснодар',
    'Сочи',
    'Новосибирск',
    'Екатеринбург',
    'Челябинск',
    'Пермь',
    'Самара',
    'Уфа',
    'Омск',
    'Красноярск',
    'Владивосток',
    'Хабаровск',
  ];

  // ── медиа
  final picker = ImagePicker();
  File? logoFile;
  File? backgroundFile;

  // ── состояние ошибок валидации
  final Set<String> _errorFields = {};

  // ── состояние загрузки
  bool _loading = false;

  bool get isFormValid =>
      nameCtrl.text.trim().isNotEmpty &&
      cityCtrl.text.trim().isNotEmpty &&
      activity != null &&
      foundationDate != null;

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    cityCtrl.addListener(() {
      _refresh();
      _clearFieldError('city');
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    cityCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── очистка ошибки для конкретного поля при взаимодействии
  void _clearFieldError(String fieldName) {
    if (_errorFields.contains(fieldName)) {
      setState(() => _errorFields.remove(fieldName));
    }
  }

  Future<void> _pickLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => logoFile = File(x.path));
  }

  Future<void> _pickBackground() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => backgroundFile = File(x.path));
  }

  Future<void> _pickDateCupertino() async {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(foundationDate ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      maximumDate: today, // дата основания не может быть в будущем
      initialDateTime: temp.isAfter(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        foundationDate = temp;
        _clearFieldError('foundationDate');
      });
    }
  }

  Future<T?> _showCupertinoSheet<T>({required Widget child}) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                // маленькая серая полоска сверху (grabber)
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),

                // ── панель с кнопками
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        child: const Text('Отмена'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        child: const Text('Готово'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                // ── сам пикер
                SizedBox(height: 260, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  Future<void> _submit() async {
    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Set<String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors.add('name');
    }
    if (cityCtrl.text.trim().isEmpty) {
      newErrors.add('city');
    }
    if (activity == null) {
      newErrors.add('activity');
    }
    if (foundationDate == null) {
      newErrors.add('foundationDate');
    }

    setState(() {
      _errorFields.clear();
      _errorFields.addAll(newErrors);
    });

    // ── если есть ошибки — не отправляем форму
    if (newErrors.isNotEmpty) {
      return;
    }

    // ── форма валидна — отправляем на сервер
    setState(() => _loading = true);

    final api = ApiService();
    final authService = AuthService();

    try {
      // Формируем данные
      final files = <String, File>{};
      final fields = <String, String>{};

      // Добавляем логотип
      if (logoFile != null) {
        files['logo'] = logoFile!;
      }

      // Добавляем фоновую картинку
      if (backgroundFile != null) {
        files['background'] = backgroundFile!;
      }

      // Добавляем поля формы
      final userId = await authService.getUserId();
      fields['user_id'] = userId?.toString() ?? '1';
      fields['name'] = nameCtrl.text.trim();
      fields['city'] = cityCtrl.text.trim();
      fields['description'] = descCtrl.text.trim();
      fields['activity'] = activity!;
      fields['is_open'] = isOpenCommunity ? '1' : '0';
      fields['foundation_date'] = _fmtDate(foundationDate!);
      // Координаты не обязательны - будут получены по городу на сервере

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        data = await api.post('/create_club.php', body: fields);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/create_club.php',
          files: files,
          fields: fields,
          timeout: const Duration(seconds: 60),
        );
      }

      // Проверяем ответ
      bool success = false;
      String? errorMessage;

      if (data['success'] == true) {
        success = true;
      } else if (data['success'] == false) {
        errorMessage = data['message'] ?? 'Ошибка при создании клуба';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        // Показываем успешное сообщение
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Клуб успешно создан')));

        // Закрываем экран создания клуба и возвращаемся на карту
        // Экран создания клуба открывается с карты, поэтому просто закрываем его
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage ?? 'Ошибка при создании клуба')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сети: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: PaceAppBar(title: 'Создание клуба'),
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
                  // ── Медиа: логотип + фоновая картинка
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MediaColumn(
                          label: 'Логотип клуба',
                          file: logoFile,
                          onPick: _pickLogo,
                          onRemove: () => setState(() => logoFile = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MediaColumn(
                          label: 'Фоновая картинка',
                          file: backgroundFile,
                          onPick: _pickBackground,
                          onRemove: () => setState(() => backgroundFile = null),
                          width: 140,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ── Название клуба
                  EventTextField(
                    controller: nameCtrl,
                    label: 'Название клуба*',
                    hasError: _errorFields.contains('name'),
                  ),
                  const SizedBox(height: 25),

                  // ── Вид активности
                  EventDropdownField(
                    label: 'Вид активности*',
                    value: activity,
                    items: const ['Бег', 'Велосипед', 'Плавание'],
                    hasError: _errorFields.contains('activity'),
                    onChanged: (v) => setState(() {
                      activity = v;
                      _clearFieldError('activity');
                    }),
                  ),
                  const SizedBox(height: 25),

                  // ── Радиокнопки: Открытое/Закрытое сообщество
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: true,
                          groupValue: isOpenCommunity,
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Открытое сообщество'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: false,
                          groupValue: isOpenCommunity,
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Закрытое сообщество'),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ── Город
                  EventAutocompleteField(
                    controller: cityCtrl,
                    label: 'Город*',
                    suggestions: _cities,
                    hasError: _errorFields.contains('city'),
                    onSelected: (city) {
                      cityCtrl.text = city;
                      _clearFieldError('city');
                    },
                  ),
                  const SizedBox(height: 25),

                  // ── Дата основания клуба
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: EventDateField(
                          label: 'Дата основания клуба*',
                          valueText: _fmtDate(foundationDate),
                          onTap: _pickDateCupertino,
                          hasError: _errorFields.contains('foundationDate'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ── Описание
                  EventTextField(
                    controller: descCtrl,
                    label: 'Описание',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Создать сообщество',
                      onPressed: () {
                        if (!_loading) _submit();
                      },
                      expanded: false,
                      isLoading: _loading,
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
// ── ЛОКАЛЬНЫЕ ВИДЖЕТЫ (переиспользуем из add_event_screen.dart)
//

class EventTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool enabled;
  final Widget? trailing;
  final bool hasError;
  final Color? textColorOverride;

  const EventTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.enabled = true,
    this.trailing,
    this.hasError = false,
    this.textColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        textColorOverride ??
        (enabled ? AppColors.textPrimary : AppColors.textPlaceholder);
    final fill = enabled ? AppColors.surface : AppColors.disabled;
    final borderColor = hasError ? AppColors.error : AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: textColor, fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        label: label.isEmpty ? null : _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
    );

    if (trailing == null) return field;

    return Row(
      crossAxisAlignment: maxLines == 1
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        trailing!,
      ],
    );
  }
}

class EventAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final List<String> suggestions;
  final Function(String) onSelected;
  final bool hasError;

  const EventAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestions,
    required this.onSelected,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? AppColors.error : AppColors.border;

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

            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
              },
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Inter',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                label: _labelWithStar(label),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: borderColor),
                ),
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
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: AppColors.textPrimary,
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

class EventDateField extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;
  final bool hasError;

  const EventDateField({
    super.key,
    required this.label,
    required this.valueText,
    this.icon = CupertinoIcons.calendar,
    required this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError ? AppColors.error : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: TextEditingController(text: valueText),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            label: _labelWithStar(label),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6),
              child: Icon(icon, size: 18, color: AppColors.iconPrimary),
            ),
            prefixIconConstraints: const BoxConstraints(
              minHeight: 18,
              minWidth: 18 + 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ),
    );
  }
}

class EventDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final bool enabled;
  final bool hasError;

  const EventDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? AppColors.textPrimary
        : AppColors.textPlaceholder;
    final fill = enabled ? AppColors.surface : AppColors.disabled;
    final borderColor = hasError ? AppColors.error : AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        label: label.isEmpty ? null : _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.iconSecondary : AppColors.iconTertiary,
          ),
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
          disabledHint: value == null
              ? const SizedBox.shrink()
              : Text(
                  value!,
                  style: TextStyle(color: textColor, fontFamily: 'Inter'),
                ),
          onChanged: enabled ? onChanged : null,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

//
// ── ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ
//

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _MediaColumn extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double width;

  const _MediaColumn({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
    this.width = 70,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 6),
        _MediaTile(
          file: file,
          onPick: onPick,
          onRemove: onRemove,
          width: width,
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double width;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
    this.width = 70,
  });

  @override
  Widget build(BuildContext context) {
    // ── если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: width,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.background,
            border: Border.all(color: AppColors.border), // ← рамка только здесь
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.photo,
              size: 28,
              color: AppColors.iconTertiary,
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
          onTap: onPick, // тап по фото — заменить
          child: Container(
            width: width,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              image: DecorationImage(
                image: FileImage(file!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.surface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

//
// ── УТИЛИТА: лейбл с красной звёздочкой
//

Widget _labelWithStar(String label) {
  return RichText(
    text: TextSpan(
      text: label.replaceAll('*', ''),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
