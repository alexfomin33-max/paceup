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
  List<String> clubs = [];
  String? selectedClub;

  // чекбоксы
  bool createFromClub = false;
  bool saveTemplate = false;

  // медиа
  final picker = ImagePicker();
  File? logoFile;
  final List<File?> photos = [null, null, null];

  // координаты выбранного места
  LatLng? selectedLocation;

  // ── состояние загрузки
  bool _loading = false;

  // ── состояние блока загрузки шаблона
  bool _showTemplateBlock = false;
  List<String> _templates = [];
  String? _selectedTemplate;
  bool _loadingTemplates = false;

  bool get isFormValid =>
      (nameCtrl.text.trim().isNotEmpty) &&
      (placeCtrl.text.trim().isNotEmpty) &&
      (activity != null) &&
      (date != null) &&
      (time != null) &&
      (selectedLocation != null);

  @override
  void initState() {
    super.initState();
    _loadUserClubs(); // ── загружаем клубы пользователя при инициализации
    nameCtrl.addListener(() => _refresh());
    placeCtrl.addListener(() => _refresh());
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
      setState(() => date = temp);
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

  // ── загрузка списка клубов пользователя
  Future<void> _loadUserClubs() async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          clubs = [];
        });
        return;
      }

      final data = await api.get(
        '/get_user_clubs.php',
        queryParams: {'user_id': userId.toString()},
      );

      if (data['success'] == true && data['clubs'] != null) {
        final clubsList = data['clubs'] as List<dynamic>;
        setState(() {
          clubs = clubsList.map((c) => c.toString()).toList();
          // Если список не пустой и selectedClub не установлен, выбираем первый
          if (clubs.isNotEmpty && selectedClub == null) {
            selectedClub = clubs.first;
          }
        });
      } else {
        setState(() {
          clubs = [];
        });
      }
    } catch (e) {
      setState(() {
        clubs = [];
      });
    }
  }

  // ── загрузка списка шаблонов
  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);

    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          _templates = [];
          _loadingTemplates = false;
        });
        return;
      }

      final data = await api.get(
        '/get_templates.php',
        queryParams: {'user_id': userId.toString()},
      );

      if (data['success'] == true && data['templates'] != null) {
        final templates = data['templates'] as List<dynamic>;
        setState(() {
          _templates = templates.map((t) => t.toString()).toList();
        });
      } else {
        setState(() {
          _templates = [];
        });
      }
    } catch (e) {
      setState(() {
        _templates = [];
      });
    } finally {
      setState(() => _loadingTemplates = false);
    }
  }

  // ── загрузка данных выбранного шаблона
  Future<void> _loadTemplateData(String templateName) async {
    setState(() => _loading = true);

    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() => _loading = false);
        return;
      }

      final data = await api.get(
        '/get_template.php',
        queryParams: {
          'template_name': templateName,
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && data['template'] != null) {
        final template = data['template'] as Map<String, dynamic>;

        // Заполняем форму данными из шаблона
        setState(() {
          nameCtrl.text = template['name'] as String? ?? '';
          placeCtrl.text = template['place'] as String? ?? '';
          descCtrl.text = template['description'] as String? ?? '';
          activity = template['activity'] as String?;

          // Парсим дату
          final dateStr = template['event_date'] as String?;
          if (dateStr != null && dateStr.isNotEmpty) {
            try {
              final parts = dateStr.split('.');
              if (parts.length == 3) {
                date = DateTime(
                  int.parse(parts[2]),
                  int.parse(parts[1]),
                  int.parse(parts[0]),
                );
              }
            } catch (e) {
              // Игнорируем ошибку парсинга
            }
          }

          // Парсим время
          final timeStr = template['event_time'] as String?;
          if (timeStr != null && timeStr.isNotEmpty) {
            try {
              final parts = timeStr.split(':');
              if (parts.length == 2) {
                time = TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                );
              }
            } catch (e) {
              // Игнорируем ошибку парсинга
            }
          }

          // Координаты
          final lat = template['latitude'] as double?;
          final lng = template['longitude'] as double?;
          if (lat != null && lng != null) {
            selectedLocation = LatLng(lat, lng);
          }

          // Клуб
          final clubName = template['club_name'] as String?;
          if (clubName != null &&
              clubName.isNotEmpty &&
              clubs.contains(clubName)) {
            createFromClub = true;
            selectedClub = clubName;
            clubCtrl.text = clubName;
          } else {
            createFromClub = false;
            selectedClub = clubs.isNotEmpty ? clubs.first : null;
          }

          templateCtrl.text = templateName;
        });
      } else {
        // Если шаблон не найден, показываем сообщение
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Шаблон не найден')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки шаблона: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!isFormValid) {
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
      if (userId == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка авторизации. Необходимо войти в систему'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      fields['user_id'] = userId.toString();
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

        // Закрываем экран создания события и возвращаемся на карту
        // Экран создания события открывается с карты, поэтому просто закрываем его
        Navigator.of(context).pop();
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
        appBar: PaceAppBar(
          title: 'Добавление события',
          actions: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showTemplateBlock = !_showTemplateBlock;
                  // Загружаем шаблоны при первом открытии
                  if (_showTemplateBlock &&
                      _templates.isEmpty &&
                      !_loadingTemplates) {
                    _loadTemplates();
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  CupertinoIcons.cloud_download,
                  size: 22,
                  color: _showTemplateBlock
                      ? AppColors.brandPrimary
                      : AppColors.iconPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),

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
                  // ---------- Блок загрузки шаблона ----------
                  if (_showTemplateBlock)
                    _TemplateLoadBlock(
                      templates: _templates,
                      selectedTemplate: _selectedTemplate,
                      loadingTemplates: _loadingTemplates,
                      onTemplateSelected: (template) {
                        setState(() => _selectedTemplate = template);
                      },
                      onLoad: () {
                        if (_selectedTemplate != null) {
                          _loadTemplateData(_selectedTemplate!);
                        }
                      },
                    ),
                  if (_showTemplateBlock) const SizedBox(height: 20),

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
                  ),
                  const SizedBox(height: 25),

                  // ---------- Вид активности ----------
                  EventDropdownField(
                    label: 'Вид активности*',
                    value: activity,
                    items: const ['Бег', 'Велосипед', 'Плавание'],
                    onChanged: (v) => setState(() => activity = v),
                  ),
                  const SizedBox(height: 25),

                  // ---------- Место + кнопка "Карта" ----------
                  EventTextField(
                    controller: placeCtrl,
                    label: 'Место проведения*',
                    enabled: false,
                    textColorOverride: AppColors.textSecondary,
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

                  const SizedBox(height: 25),

                  // ---------- Дата / Время ----------
                  Row(
                    children: [
                      Expanded(
                        child: EventDateField(
                          label: 'Дата проведения*',
                          valueText: _fmtDate(date),
                          onTap: _pickDateCupertino,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: EventDateField(
                          label: 'Время',
                          valueText: _fmtTime(time),
                          icon: CupertinoIcons.time,
                          onTap: _pickTimeCupertino,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // ---------- Описание ----------
                  EventTextField(
                    controller: descCtrl,
                    label: 'Описание события',
                    minLines:
                        8, // ── минимальное количество строк для начальной высоты
                    minHeight: 200, // ── минимальная высота в пикселях
                    // maxLines не указываем, чтобы поле могло расти динамически
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
                  const SizedBox(height: 6),
                  EventDropdownField(
                    label: '', // ← пустая строка: лейбл не рисуем
                    value: selectedClub,
                    items: clubs,
                    enabled: createFromClub && clubs.isNotEmpty,
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
                  const SizedBox(height: 6),

                  EventTextField(
                    controller: templateCtrl,
                    label: '',
                    enabled: saveTemplate,
                    // ← ⚡️ вот это главное
                  ),

                  const SizedBox(height: 25),
                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Создать мероприятие',
                      onPressed: () {
                        if (!_loading) _submit();
                      },
                      expanded: false,
                      isLoading: _loading,
                      enabled: isFormValid,
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
  final int?
  minLines; // ── минимальное количество строк для динамической высоты
  final double? minHeight; // ── минимальная высота в пикселях
  final bool enabled;
  final Widget? trailing;
  final Color? textColorOverride;

  const EventTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.minLines,
    this.minHeight,
    this.enabled = true,
    this.trailing,
    this.textColorOverride,
  });

  @override
  Widget build(BuildContext context) {
    // цвета/бордеры в зависимости от enabled
    final textColor =
        textColorOverride ??
        (enabled
            ? AppColors.textPrimary
            : AppColors.textPlaceholder); // «плейсхолдер/disabled»
    final fill = enabled ? AppColors.surface : AppColors.disabled;
    final borderColor = AppColors.border;
    final disabledBorderColor = AppColors.border.withValues(alpha: 0.6);

    // ── создаём TextFormField с поддержкой динамической высоты
    final field = TextFormField(
      controller: controller,
      minLines: minLines, // ── минимальное количество строк
      maxLines: minLines != null
          ? null
          : maxLines, // ── если есть minLines, убираем ограничение maxLines для динамического роста
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

        // обычные рамки
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

    // ── если указана минимальная высота, оборачиваем в ConstrainedBox
    final constrainedField = minHeight != null
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight!),
            child: field,
          )
        : field;

    if (trailing == null) return constrainedField;

    return Row(
      crossAxisAlignment: (maxLines == 1 && minLines == null)
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Expanded(child: constrainedField),
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

  const EventDateField({
    super.key,
    required this.label,
    required this.valueText,
    this.icon = CupertinoIcons.calendar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.border;

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

  const EventDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? AppColors.textPrimary
        : AppColors.textPlaceholder;
    final fill = enabled ? AppColors.surface : AppColors.disabled;
    final borderColor = AppColors.border;
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
// --------------------------- БЛОК ЗАГРУЗКИ ШАБЛОНА ---------------------------
//

class _TemplateLoadBlock extends StatelessWidget {
  final List<String> templates;
  final String? selectedTemplate;
  final bool loadingTemplates;
  final Function(String?) onTemplateSelected;
  final VoidCallback onLoad;

  const _TemplateLoadBlock({
    required this.templates,
    required this.selectedTemplate,
    required this.loadingTemplates,
    required this.onTemplateSelected,
    required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Dropdown с шаблонами и кнопка "Загрузить"
        Row(
          children: [
            // Dropdown - используем EventDropdownField для единообразия
            Expanded(
              child: loadingTemplates
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: CupertinoActivityIndicator(radius: 9),
                      ),
                    )
                  : EventDropdownField(
                      label: 'Загрузить шаблон',
                      value: selectedTemplate,
                      items: templates,
                      enabled: templates.isNotEmpty,
                      onChanged: templates.isEmpty
                          ? (_) {}
                          : onTemplateSelected,
                    ),
            ),

            const SizedBox(width: 12),

            // Кнопка "Загрузить"
            IntrinsicWidth(
              child: PrimaryButton(
                text: 'Загрузить',
                onPressed: onLoad,
                expanded: false,
                isLoading: false,
                enabled: selectedTemplate != null,
              ),
            ),
          ],
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
