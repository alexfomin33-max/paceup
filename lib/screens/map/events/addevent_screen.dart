import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import 'location_picker_screen.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final clubCtrl = TextEditingController(text: 'CoffeeRun_vld');
  final templateCtrl = TextEditingController(text: 'Субботний коферан');

  // выборы
  String? activity = 'Бег';
  DateTime? date = DateTime.now();
  TimeOfDay? time = const TimeOfDay(hour: 12, minute: 00);

  // список клубов
  final List<String> clubs = ['CoffeeRun_vld', 'RunTown', 'TriClub'];
  String? selectedClub = 'CoffeeRun_vld';

  // чекбоксы
  bool createFromClub = false;
  bool saveTemplate = false;

  // медиа
  final picker = ImagePicker();
  File? logoFile;
  final List<File?> photos = [null, null, null];

  // координаты выбранного места
  LatLng? selectedLocation;

  // ── состояние ошибок валидации (какие поля должны быть подсвечены красным)
  final Set<String> _errorFields = {};

  // ── состояние загрузки
  bool _loading = false;

  bool get isFormValid =>
      (nameCtrl.text.trim().isNotEmpty) &&
      (placeCtrl.text.trim().isNotEmpty) &&
      (activity != null) &&
      (date != null) &&
      (time != null);

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name'); // ── очищаем ошибку при вводе
    });
    placeCtrl.addListener(() {
      _refresh();
      _clearFieldError('place'); // ── очищаем ошибку при вводе
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    placeCtrl.dispose();
    descCtrl.dispose();
    clubCtrl.dispose();
    templateCtrl.dispose();
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

  Future<void> _pickPhoto(int i) async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => photos[i] = File(x.path));
  }

  /// Открыть экран выбора места на карте
  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationResult?>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: selectedLocation),
      ),
    );

    if (result != null) {
      setState(() {
        selectedLocation = result.coordinates;
        // ⚡️ Автозаполнение поля "Место проведения" адресом из геокодинга
        if (result.address != null && result.address!.isNotEmpty) {
          placeCtrl.text = result.address!;
        }
        _clearFieldError('place'); // ── очищаем ошибку при выборе места
      });
    }
  }

  Future<void> _pickDateCupertino() async {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(date ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: today,
      maximumDate: today.add(const Duration(days: 365 * 2)),
      initialDateTime: temp.isBefore(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        date = temp;
        _clearFieldError('date'); // ── очищаем ошибку при выборе даты
      });
    }
  }

  Future<void> _pickTimeCupertino() async {
    DateTime temp = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      time?.hour ?? 12,
      time?.minute ?? 0,
    );

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      use24hFormat: true,
      initialDateTime: temp,
      onDateTimeChanged: (dt) => temp = dt,
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        time = TimeOfDay(hour: temp.hour, minute: temp.minute);
        _clearFieldError('time'); // ── очищаем ошибку при выборе времени
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

                // 📌 ПАНЕЛЬ С КНОПКАМИ
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

                // 📌 сам пикер
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

  String _fmtTime(TimeOfDay? t) {
    if (t == null) return '';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _submit() async {
    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Set<String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors.add('name');
    }
    if (placeCtrl.text.trim().isEmpty) {
      newErrors.add('place');
    }
    if (activity == null) {
      newErrors.add('activity');
    }
    if (date == null) {
      newErrors.add('date');
    }
    if (time == null) {
      newErrors.add('time');
    }
    if (selectedLocation == null) {
      newErrors.add('place'); // Помечаем место, т.к. координаты не выбраны
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

      // Добавляем фотографии
      for (int i = 0; i < photos.length; i++) {
        if (photos[i] != null) {
          files['images[$i]'] = photos[i]!;
        }
      }

      // Добавляем поля формы
      final userId = await authService.getUserId();
      fields['user_id'] = userId?.toString() ?? '1';
      fields['name'] = nameCtrl.text.trim();
      fields['activity'] = activity!;
      fields['place'] = placeCtrl.text.trim();
      fields['latitude'] = selectedLocation!.latitude.toString();
      fields['longitude'] = selectedLocation!.longitude.toString();
      fields['event_date'] = _fmtDate(date!);
      fields['event_time'] = _fmtTime(time!);
      fields['description'] = descCtrl.text.trim();
      if (createFromClub && selectedClub != null) {
        fields['club_name'] = selectedClub!;
      }
      if (saveTemplate && templateCtrl.text.trim().isNotEmpty) {
        fields['template_name'] = templateCtrl.text.trim();
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        data = await api.post('/create_event.php', body: fields);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/create_event.php',
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
        errorMessage = data['message'] ?? 'Ошибка при создании события';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        // Показываем успешное сообщение
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Событие успешно создано')),
        );

        // Закрываем экран создания события
        // После закрытия пользователь увидит карту (если она была открыта через bottom nav)
        // Маркеры событий обновятся автоматически при переключении на вкладку событий
        Navigator.of(context).pop(true); // Возвращаем true как признак успешного создания
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Ошибка при создании события'),
          ),
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
        appBar: const PaceAppBar(title: 'Добавление события'),

        body: GestureDetector(
          // 🔹 Скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Медиа: логотип + 3 фото (визуальный стиль как в newpost) ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MediaColumn(
                        label: 'Логотип',
                        file: logoFile,
                        onPick: _pickLogo,
                        onRemove: () => setState(() => logoFile = null),
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SmallLabel('Фото события'),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 70,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 3,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 12),
                                itemBuilder: (_, i) => _MediaTile(
                                  file: photos[i],
                                  onPick: () => _pickPhoto(i),
                                  onRemove: () =>
                                      setState(() => photos[i] = null),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // ---------- Название ----------
                  EventTextField(
                    controller: nameCtrl,
                    label: 'Название события*',
                    hasError: _errorFields.contains('name'),
                  ),
                  const SizedBox(height: 20),

                  // ---------- Вид активности ----------
                  EventDropdownField(
                    label: 'Вид активности*',
                    value: activity,
                    items: const ['Бег', 'Велосипед', 'Плавание', 'Триатлон'],
                    hasError: _errorFields.contains('activity'),
                    onChanged: (v) => setState(() {
                      activity = v;
                      _clearFieldError(
                        'activity',
                      ); // ── очищаем ошибку при выборе
                    }),
                  ),
                  const SizedBox(height: 20),

                  // ---------- Место + кнопка "Карта" ----------
                  EventTextField(
                    controller: placeCtrl,
                    label: 'Место проведения*',
                    hasError: _errorFields.contains('place'),
                    trailing: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: OutlinedButton(
                          onPressed: _pickLocation,
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            padding:
                                EdgeInsets.zero, // чтобы иконка была по центру
                          ),
                          child: const Icon(CupertinoIcons.placemark, size: 20),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ---------- Дата / Время ----------
                  Row(
                    children: [
                      Expanded(
                        child: EventDateField(
                          label: 'Дата проведения*',
                          valueText: _fmtDate(date),
                          onTap: _pickDateCupertino,
                          hasError: _errorFields.contains('date'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: EventDateField(
                          label: 'Время',
                          valueText: _fmtTime(time),
                          icon: CupertinoIcons.time,
                          onTap: _pickTimeCupertino,
                          hasError: _errorFields.contains('time'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---------- Описание ----------
                  EventTextField(
                    controller: descCtrl,
                    label: 'Описание события',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),

                  // ---------- Создать от имени клуба ----------
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: createFromClub,
                          onChanged: (v) =>
                              setState(() => createFromClub = v ?? false),
                          side: const BorderSide(color: AppColors.border),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Создать от имени клуба'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  EventDropdownField(
                    label: '', // ← пустая строка: лейбл не рисуем
                    value: selectedClub,
                    items: clubs,
                    enabled: createFromClub,
                    onChanged: (v) => setState(() {
                      selectedClub = v;
                      clubCtrl.text = v ?? '';
                    }),
                  ),
                  const SizedBox(height: 16),

                  // ---------- Сохранить шаблон ----------
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: saveTemplate,
                          onChanged: (v) =>
                              setState(() => saveTemplate = v ?? false),
                          side: const BorderSide(color: AppColors.border),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Сохранить шаблон'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  EventTextField(
                    controller: templateCtrl,
                    label: '',
                    enabled: saveTemplate,
                    // ← ⚡️ вот это главное
                  ),

                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Создать мероприятие',
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
// --------------------------- ЛОКАЛЬНЫЕ ВИДЖЕТЫ В СТИЛЕ regstep1 ---------------------------
//

class EventTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool enabled;
  final Widget? trailing;
  final bool hasError; // ── состояние ошибки валидации

  const EventTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.enabled = true,
    this.trailing,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    // цвета/бордеры в зависимости от enabled и hasError
    final textColor = enabled
        ? AppColors.textPrimary
        : AppColors.textPlaceholder; // «плейсхолдер/disabled»
    final fill = enabled ? AppColors.surface : AppColors.disabled;
    // ── если есть ошибка — красный бордер, иначе обычный
    final borderColor = hasError ? AppColors.error : AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: textColor, fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        // если label пустой — не показываем подпись
        label: label.isEmpty ? null : _labelWithStar(label),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),

        // обычные рамки (с учётом ошибки)
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

        // 🔸 рамка, когда поле отключено
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

class EventDateField extends StatelessWidget {
  final String label;
  final String valueText;
  final IconData icon;
  final VoidCallback onTap;
  final bool hasError; // ── состояние ошибки валидации

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
    // ── если есть ошибка — красный бордер, иначе обычный
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
  final String label; // может быть пустым
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final bool enabled;
  final bool hasError; // ── состояние ошибки валидации

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
    // ── если есть ошибка — красный бордер, иначе обычный
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
        // 🔸 рамка, когда поле отключено
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: disabledBorderColor),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          // бледная стрелка, когда выключено
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppColors.iconSecondary : AppColors.iconTertiary,
          ),
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          style: TextStyle(color: textColor, fontFamily: 'Inter'),
          // показываем текущее значение в бледном виде, если disabled
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
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ (как в newpost) ---------------------------
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
  final VoidCallback onRemove; // ← новое

  const _MediaColumn({
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 6),
        _MediaTile(file: file, onPick: onPick, onRemove: onRemove),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // 📌 Если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: 70,
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

    // 📌 Если фото выбрано — превью без рамки
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onPick, // тап по фото — заменить
          child: Container(
            width: 70,
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
// --------------------------- УТИЛИТА: лейбл с красной звёздочкой ---------------------------
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
      // children: [
      //   if (label.contains('*'))
      //     const TextSpan(
      //       text: '*',
      //       style: TextStyle(color: AppColors.error, fontSize: 16),
      //     ),
      // ],
    ),
  );
}
