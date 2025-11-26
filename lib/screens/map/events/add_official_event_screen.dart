import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import 'location_picker_screen.dart';

class AddOfficialEventScreen extends StatefulWidget {
  const AddOfficialEventScreen({super.key});

  @override
  State<AddOfficialEventScreen> createState() => _AddOfficialEventScreenState();
}

class _AddOfficialEventScreenState extends State<AddOfficialEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
  final templateCtrl = TextEditingController(text: 'Субботний коферан');

  // выборы
  String? activity;
  DateTime? date;
  TimeOfDay? time;
  // ── контроллеры для полей ввода дистанций
  final List<TextEditingController> _distanceControllers = [];

  // чекбоксы
  bool saveTemplate = false;

  // медиа
  final picker = ImagePicker();
  File? logoFile;

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
    nameCtrl.addListener(() => _refresh());
    placeCtrl.addListener(() => _refresh());
    linkCtrl.addListener(() => _refresh());
    // ── создаём первое поле для ввода дистанции
    _distanceControllers.add(TextEditingController());
    _distanceControllers.last.addListener(() => _refresh());
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    placeCtrl.dispose();
    descCtrl.dispose();
    linkCtrl.dispose();
    templateCtrl.dispose();
    // ── освобождаем все контроллеры дистанций
    for (final controller in _distanceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── добавление нового поля для ввода дистанции
  void _addDistanceField() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => _refresh());
      _distanceControllers.add(newController);
    });
  }

  Future<void> _pickLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => logoFile = File(x.path));
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
      setState(() {
        date = temp;
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
      });
    }
  }

  Future<T?> _showCupertinoSheet<T>({required Widget child}) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => Builder(
        builder: (context) => SafeArea(
          top: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                borderRadius: const BorderRadius.vertical(
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
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: 0),

                  // 📌 ПАНЕЛЬ С КНОПКАМИ
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          child: Text(
                            'Отмена',
                            style: TextStyle(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: () => Navigator.of(sheetCtx).pop(true),
                          child: Text(
                            'Готово',
                            style: TextStyle(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
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
          linkCtrl.text = template['event_link'] as String? ?? '';
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

          // ── обработка дистанций из шаблона
          // Очищаем существующие контроллеры (кроме первого, если он пустой)
          for (final controller in _distanceControllers) {
            controller.removeListener(() => _refresh());
            controller.dispose();
          }
          _distanceControllers.clear();

          // Парсим дистанции из шаблона (формат: "5000, 10000, 21100" - все в метрах)
          final distanceStr = template['distance'] as String?;
          if (distanceStr != null && distanceStr.isNotEmpty) {
            // Разделяем по запятой и очищаем пробелы
            final distances = distanceStr
                .split(',')
                .map((d) => d.trim())
                .where((d) => d.isNotEmpty)
                .toList();

            // Создаём контроллеры для каждой дистанции
            for (final dist in distances) {
              final controller = TextEditingController(text: dist);
              controller.addListener(() => _refresh());
              _distanceControllers.add(controller);
            }
          }

          // Если дистанций нет, создаём одно пустое поле
          if (_distanceControllers.isEmpty) {
            final controller = TextEditingController();
            controller.addListener(() => _refresh());
            _distanceControllers.add(controller);
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
      // ── собираем введённые дистанции (только непустые, все в метрах)
      final distanceValues = _distanceControllers
          .map((ctrl) => ctrl.text.trim())
          .where((value) => value.isNotEmpty && value.isNotEmpty)
          .toList();
      // ── отправляем дистанции как массив (все в метрах)
      if (distanceValues.isNotEmpty) {
        // Для multipart нужно отправлять как массив
        for (int i = 0; i < distanceValues.length; i++) {
          fields['distance[$i]'] = distanceValues[i];
        }
      }
      // Добавляем ссылку на страницу мероприятия
      if (linkCtrl.text.trim().isNotEmpty) {
        fields['event_link'] = linkCtrl.text.trim();
      }
      if (saveTemplate && templateCtrl.text.trim().isNotEmpty) {
        fields['template_name'] = templateCtrl.text.trim();
      }

      // Отправляем запрос в API для официальных событий
      Map<String, dynamic> data;
      if (files.isEmpty) {
        // JSON запрос без файлов
        // Для JSON нужно отправлять массивы правильно
        final jsonBody = <String, dynamic>{
          'user_id': fields['user_id'],
          'name': fields['name'],
          'activity': fields['activity'],
          'place': fields['place'],
          'latitude': fields['latitude'],
          'longitude': fields['longitude'],
          'event_date': fields['event_date'],
          'event_time': fields['event_time'],
          'description': fields['description'],
          'event_link': fields['event_link'] ?? '',
          'template_name': fields['template_name'] ?? '',
        };
        if (distanceValues.isNotEmpty) {
          jsonBody['distance'] = distanceValues;
        }
        data = await api.post('/create_official_event.php', body: jsonBody);
      } else {
        // Multipart запрос с файлами
        data = await api.postMultipart(
          '/create_official_event.php',
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

        // Закрываем экран создания события и возвращаемся на карту с результатом
        // Экран создания события открывается с карты, поэтому возвращаем результат для обновления данных
        Navigator.of(context).pop('created');
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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Официальное событие',
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
                      : AppColors.getIconPrimaryColor(context),
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
                  if (_showTemplateBlock) ...[
                    Text(
                      'Загрузить шаблон',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _loadingTemplates
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: CupertinoActivityIndicator(
                                      radius: 9,
                                    ),
                                  ),
                                )
                              : Builder(
                                  builder: (context) => InputDecorator(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppColors.getSurfaceColor(
                                        context,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedTemplate,
                                        isExpanded: true,
                                        hint: Text(
                                          'Выберите шаблон',
                                          style: AppTextStyles.h14w4Place,
                                        ),
                                        onChanged: _templates.isNotEmpty
                                            ? (String? newValue) {
                                                setState(
                                                  () => _selectedTemplate =
                                                      newValue,
                                                );
                                              }
                                            : null,
                                        dropdownColor:
                                            AppColors.getSurfaceColor(context),
                                        menuMaxHeight: 300,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: _templates.isNotEmpty
                                              ? AppColors.getIconSecondaryColor(
                                                  context,
                                                )
                                              : AppColors.iconTertiary,
                                        ),
                                        style: AppTextStyles.h14w4.copyWith(
                                          color: AppColors.getTextPrimaryColor(
                                            context,
                                          ),
                                        ),
                                        items: _templates.map((item) {
                                          return DropdownMenuItem<String>(
                                            value: item,
                                            child: Builder(
                                              builder: (context) => Text(
                                                item,
                                                style: AppTextStyles.h14w4.copyWith(
                                                  color:
                                                      AppColors.getTextPrimaryColor(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        IntrinsicWidth(
                          child: PrimaryButton(
                            text: 'Загрузить',
                            onPressed: _selectedTemplate != null
                                ? () {
                                    if (_selectedTemplate != null) {
                                      _loadTemplateData(_selectedTemplate!);
                                    }
                                  }
                                : () {},
                            expanded: false,
                            isLoading: false,
                            enabled: _selectedTemplate != null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ---------- Медиа: только логотип ----------
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Название ----------
                  Text(
                    'Название события',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => TextField(
                      controller: nameCtrl,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Введите название события',
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
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Ссылка на страницу мероприятия ----------
                  Text(
                    'Ссылка на страницу мероприятия',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => TextField(
                      controller: linkCtrl,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'https://example.com/event',
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
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
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
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: activity,
                          isExpanded: true,
                          hint: Text(
                            'Выберите вид активности',
                            style: AppTextStyles.h14w4Place,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => activity = newValue);
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
                          items: const ['Бег', 'Велосипед', 'Плавание'].map((
                            option,
                          ) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Builder(
                                builder: (context) => Text(
                                  option,
                                  style: AppTextStyles.h14w4.copyWith(
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Место + кнопка "Карта" ----------
                  Text(
                    'Место проведения',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      // ── определяем более серый цвет для светлой темы
                      final brightness = Theme.of(context).brightness;
                      final isLight = brightness == Brightness.light;
                      final fillColor = isLight
                          ? AppColors.disabled
                          : AppColors.getSurfaceMutedColor(context);
                      final textColor = isLight
                          ? AppColors.getTextPlaceholderColor(context)
                          : AppColors.getTextSecondaryColor(context);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: placeCtrl,
                              enabled: false,
                              style: AppTextStyles.h14w4.copyWith(
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Выберите место на карте',
                                hintStyle: AppTextStyles.h14w4Place,
                                filled: true,
                                fillColor: fillColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 17,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.getBorderColor(
                                      context,
                                    ).withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.getBorderColor(
                                      context,
                                    ).withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.getBorderColor(
                                      context,
                                    ).withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _pickLocation,
                              style: OutlinedButton.styleFrom(
                                shape: const CircleBorder(),
                                side: BorderSide(
                                  color: AppColors.getBorderColor(context),
                                ),
                                foregroundColor: AppColors.getTextPrimaryColor(
                                  context,
                                ),
                                backgroundColor: AppColors.getSurfaceColor(
                                  context,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Icon(
                                CupertinoIcons.placemark,
                                size: 20,
                                color: AppColors.getIconPrimaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дата / Время ----------
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дата проведения',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) => GestureDetector(
                                onTap: _pickDateCupertino,
                                child: AbsorbPointer(
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppColors.getSurfaceColor(
                                        context,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 18,
                                          ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          right: 6,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.calendar,
                                          size: 18,
                                          color: AppColors.getIconPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                            minWidth: 18 + 14,
                                            minHeight: 18,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      date != null
                                          ? _fmtDate(date!)
                                          : 'Выберите дату',
                                      style: date != null
                                          ? AppTextStyles.h14w4.copyWith(
                                              color:
                                                  AppColors.getTextPrimaryColor(
                                                    context,
                                                  ),
                                            )
                                          : AppTextStyles.h14w4Place,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Время начала',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) => GestureDetector(
                                onTap: _pickTimeCupertino,
                                child: AbsorbPointer(
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AppColors.getSurfaceColor(
                                        context,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 18,
                                          ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          right: 6,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.time,
                                          size: 18,
                                          color: AppColors.getIconPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                            minWidth: 18 + 14,
                                            minHeight: 18,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        borderSide: BorderSide(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      time != null
                                          ? _fmtTime(time!)
                                          : 'Выберите время',
                                      style: time != null
                                          ? AppTextStyles.h14w4.copyWith(
                                              color:
                                                  AppColors.getTextPrimaryColor(
                                                    context,
                                                  ),
                                            )
                                          : AppTextStyles.h14w4Place,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дистанция ----------
                  Text(
                    'Дистанция (в метрах)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── динамические поля для ввода дистанций (в два столбца)
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: List.generate(_distanceControllers.length, (index) {
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 32 - 16) / 2,
                        child: Builder(
                          builder: (context) => TextField(
                            controller: _distanceControllers[index],
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Введите дистанцию',
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
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                borderSide: BorderSide(
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                borderSide: BorderSide(
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // ── кнопка "добавить ещё"
                  GestureDetector(
                    onTap: _addDistanceField,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.add_circled,
                          size: 20,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'добавить ещё',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Описание ----------
                  Text(
                    'Описание события',
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
                        hintText: 'Введите описание события',
                        hintStyle: AppTextStyles.h14w4Place,
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: BorderSide(
                            color: AppColors.getBorderColor(context),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Сохранить шаблон ----------
                  Builder(
                    builder: (context) => Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Transform.scale(
                            scale: 0.85,
                            alignment: Alignment.centerLeft,
                            child: Checkbox(
                              value: saveTemplate,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              activeColor: AppColors.brandPrimary,
                              checkColor: AppColors.getSurfaceColor(context),
                              side: BorderSide(
                                color: AppColors.getIconSecondaryColor(context),
                                width: 1.5,
                              ),
                              onChanged: (v) =>
                                  setState(() => saveTemplate = v ?? false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Сохранить шаблон',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (saveTemplate) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextField(
                        controller: templateCtrl,
                        enabled: saveTemplate,
                        style: AppTextStyles.h14w4.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Введите название шаблона',
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
                              color: AppColors.getBorderColor(context),
                              width: 1,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: AppColors.getBorderColor(context),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: AppColors.getBorderColor(context),
                              width: 1,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            borderSide: BorderSide(
                              color: AppColors.getBorderColor(
                                context,
                              ).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

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
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ МЕДИА-ТАЙЛЫ ---------------------------
//

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
          width: 90,
          height: 90,
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

    // 📌 Если фото выбрано — превью без рамки
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
              width: 90,
              height: 90,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 90,
                height: 90,
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
          child: Builder(
            builder: (context) => GestureDetector(
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
        ),
      ],
    );
  }
}
