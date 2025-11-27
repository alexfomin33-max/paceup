import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/interactive_back_swipe.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';
import 'location_picker_screen.dart';

class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({super.key});

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final clubCtrl = TextEditingController(text: 'CoffeeRun_vld');
  final templateCtrl = TextEditingController(text: 'Субботний коферан');

  // выборы
  String? activity;
  DateTime? date;
  TimeOfDay? time;

  // список клубов
  List<String> clubs = [];
  String? selectedClub;

  // чекбоксы
  bool createFromClub = false;
  bool saveTemplate = false;

  // медиа
  File? logoFile;
  final List<File?> photos = [null, null, null];

  // ──────────── фиксированные пропорции для обрезки логотипа ────────────
  static const double _logoAspectRatio = 1;

  // координаты выбранного места
  LatLng? selectedLocation;

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
    // ── выбираем логотип с обрезкой в фиксированную пропорцию 1:1
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _logoAspectRatio,
      maxSide: 900,
      jpegQuality: 85,
      cropTitle: 'Обрезка логотипа',
    );
    if (processed == null || !mounted) return;

    setState(() => logoFile = processed);
  }

  Future<void> _pickPhoto(int i) async {
    // ── забираем фото события и сжимаем его перед загрузкой (без обрезки)
    final compressed = await ImagePickerHelper.pickImageWithoutCrop(
      maxSide: 1600,
      jpegQuality: 80,
    );
    if (compressed == null || !mounted) return;

    setState(() => photos[i] = compressed);
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

  // ── загрузка списка клубов пользователя
  Future<void> _loadUserClubs() async {
    try {
      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
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
      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
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
    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submitWithLoading(
      () async {
        final api = ref.read(apiServiceProvider);
        final authService = ref.read(authServiceProvider);
        final userId = await authService.getUserId();

        if (userId == null) {
          throw Exception('Пользователь не авторизован');
        }

        final templateData = await api.get(
          '/get_template.php',
          queryParams: {
            'template_name': templateName,
            'user_id': userId.toString(),
          },
        );

        if (templateData['success'] != true || templateData['template'] == null) {
          throw Exception('Шаблон не найден');
        }

        final template = templateData['template'] as Map<String, dynamic>;

        // Заполняем форму данными из шаблона
        if (mounted) {
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
        }
      },
      onError: (error) {
        if (mounted) {
          final formState = ref.read(formStateProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка загрузки шаблона: ${formState.error ?? error.toString()}'),
            ),
          );
        }
      },
    );
  }

  Future<void> _submit() async {
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!isFormValid) {
      return;
    }

    // ── форма валидна — отправляем на сервер
    final formNotifier = ref.read(formStateProvider.notifier);
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

      // Добавляем фотографии
      for (int i = 0; i < photos.length; i++) {
        if (photos[i] != null) {
          files['images[$i]'] = photos[i]!;
        }
      }

        // Добавляем поля формы
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Ошибка авторизации. Необходимо войти в систему');
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
        if (data['success'] != true) {
          final errorMessage = data['message'] ?? 'Ошибка при создании события';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Закрываем экран создания события и возвращаемся на карту с результатом
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
                                        hint: const Text(
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

                  // ---------- Медиа: логотип + 3 фото ----------
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
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Фото события',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
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
                          hint: const Text(
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

                  // ---------- Создать от имени клуба ----------
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
                              value: createFromClub,
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
                                  setState(() => createFromClub = v ?? false),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Создать от имени клуба',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (createFromClub) ...[
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
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedClub,
                            isExpanded: true,
                            hint: const Text(
                              'Выберите клуб',
                              style: AppTextStyles.h14w4Place,
                            ),
                            onChanged: (createFromClub && clubs.isNotEmpty)
                                ? (String? newValue) {
                                    setState(() {
                                      selectedClub = newValue;
                                      clubCtrl.text = newValue ?? '';
                                    });
                                  }
                                : null,
                            dropdownColor: AppColors.getSurfaceColor(context),
                            menuMaxHeight: 300,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: (createFromClub && clubs.isNotEmpty)
                                  ? AppColors.getIconSecondaryColor(context)
                                  : AppColors.iconTertiary,
                            ),
                            style: AppTextStyles.h14w4.copyWith(
                              color: (createFromClub && clubs.isNotEmpty)
                                  ? AppColors.getTextPrimaryColor(context)
                                  : AppColors.getTextPlaceholderColor(context),
                            ),
                            items: clubs.map((item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Builder(
                                  builder: (context) => Text(
                                    item,
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
                  ],
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

                  // Показываем ошибки, если есть
                  if (formState.hasErrors) ...[
                    FormErrorDisplay(formState: formState),
                    const SizedBox(height: 16),
                  ],

                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Создать мероприятие',
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
