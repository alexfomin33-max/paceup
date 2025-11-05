import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import 'location_picker_screen.dart';
import 'addevent_screen.dart';

/// Экран редактирования события
class EditEventScreen extends StatefulWidget {
  final int eventId;

  const EditEventScreen({super.key, required this.eventId});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final clubCtrl = TextEditingController();
  final templateCtrl = TextEditingController();

  // выборы
  String? activity;
  DateTime? date;
  TimeOfDay? time;

  // список клубов
  final List<String> clubs = ['CoffeeRun_vld', 'RunTown', 'TriClub'];
  String? selectedClub;

  // чекбоксы
  bool createFromClub = false;
  bool saveTemplate = false;

  // медиа
  final picker = ImagePicker();
  File? logoFile;
  String? logoUrl; // URL для отображения существующего логотипа
  String? logoFilename; // Имя файла существующего логотипа
  final List<File?> photos = [null, null, null];
  final List<String> photoUrls = ['', '', '']; // URL для отображения существующих фото
  final List<String> photoFilenames = ['', '', '']; // Имена файлов существующих фото

  // координаты выбранного места
  LatLng? selectedLocation;

  // ── состояние ошибок валидации (какие поля должны быть подсвечены красным)
  final Set<String> _errorFields = {};

  // ── состояние загрузки
  bool _loading = false;
  bool _loadingData = true;

  bool get isFormValid =>
      (nameCtrl.text.trim().isNotEmpty) &&
      (placeCtrl.text.trim().isNotEmpty) &&
      (activity != null) &&
      (date != null) &&
      (time != null);

  @override
  void initState() {
    super.initState();
    _loadEventData();
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    placeCtrl.addListener(() {
      _refresh();
      _clearFieldError('place');
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

  /// Загрузка данных события для редактирования
  Future<void> _loadEventData() async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка авторизации')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final data = await api.get(
        '/update_event.php',
        queryParams: {
          'event_id': widget.eventId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && data['event'] != null) {
        final event = data['event'] as Map<String, dynamic>;

        // Заполняем текстовые поля
        nameCtrl.text = event['name'] as String? ?? '';
        placeCtrl.text = event['place'] as String? ?? '';
        descCtrl.text = event['description'] as String? ?? '';
        clubCtrl.text = event['club_name'] as String? ?? '';
        templateCtrl.text = event['template_name'] as String? ?? '';

        // Заполняем выборы
        final activityStr = event['activity'] as String?;
        // Проверяем, что значение активности входит в список допустимых
        const allowedActivities = ['Бег', 'Велосипед', 'Плавание', 'Триатлон'];
        if (activityStr != null && allowedActivities.contains(activityStr)) {
          activity = activityStr;
        } else {
          activity = null; // Если значение не валидно, оставляем null
        }
        
        final clubNameStr = event['club_name'] as String? ?? '';
        createFromClub = clubNameStr.isNotEmpty;
        // Проверяем, что значение клуба входит в список допустимых
        if (createFromClub && clubs.contains(clubNameStr)) {
          selectedClub = clubNameStr;
        } else {
          selectedClub = null; // Если значение не валидно, оставляем null
        }
        
        saveTemplate = (event['template_name'] as String? ?? '').isNotEmpty;

        // Заполняем дату и время
        final eventDateStr = event['event_date'] as String? ?? '';
        if (eventDateStr.isNotEmpty) {
          try {
            final parts = eventDateStr.split('.');
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

        final eventTimeStr = event['event_time'] as String? ?? '';
        if (eventTimeStr.isNotEmpty) {
          try {
            final parts = eventTimeStr.split(':');
            if (parts.length >= 2) {
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
        final lat = event['latitude'] as num?;
        final lng = event['longitude'] as num?;
        if (lat != null && lng != null) {
          selectedLocation = LatLng(lat.toDouble(), lng.toDouble());
        }

        // Логотип
        logoUrl = event['logo_url'] as String?;
        logoFilename = event['logo_filename'] as String?;

        // Фотографии
        final photosList = event['photos'] as List<dynamic>? ?? [];
        for (int i = 0; i < 3 && i < photosList.length; i++) {
          final photo = photosList[i] as Map<String, dynamic>?;
          if (photo != null) {
            photoUrls[i] = photo['url'] as String? ?? '';
            photoFilenames[i] = photo['filename'] as String? ?? '';
          }
        }

        setState(() {
          _loadingData = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] as String? ?? 'Не удалось загрузить данные события',
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickLogo() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() {
        logoFile = File(x.path);
        logoUrl = null; // Сбрасываем URL, так как выбран новый файл
      });
    }
  }

  Future<void> _pickPhoto(int i) async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() {
        photos[i] = File(x.path);
        photoUrls[i] = ''; // Сбрасываем URL, так как выбран новый файл
        photoFilenames[i] = '';
      });
    }
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
        if (result.address != null && result.address!.isNotEmpty) {
          placeCtrl.text = result.address!;
        }
        _clearFieldError('place');
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
        _clearFieldError('date');
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
        _clearFieldError('time');
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
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),
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
      newErrors.add('place');
    }

    setState(() {
      _errorFields.clear();
      _errorFields.addAll(newErrors);
    });

    if (newErrors.isNotEmpty) {
      return;
    }

    setState(() => _loading = true);

    final api = ApiService();
    final authService = AuthService();

    try {
      final files = <String, File>{};
      final fields = <String, String>{};

      // Добавляем логотип (если выбран новый)
      if (logoFile != null) {
        files['logo'] = logoFile!;
      }

      // Добавляем фотографии (только новые)
      for (int i = 0; i < photos.length; i++) {
        if (photos[i] != null) {
          files['images[$i]'] = photos[i]!;
        }
      }

      // Добавляем поля формы
      final userId = await authService.getUserId();
      fields['event_id'] = widget.eventId.toString();
      fields['user_id'] = userId?.toString() ?? '1';
      fields['name'] = nameCtrl.text.trim();
      fields['activity'] = activity!;
      fields['place'] = placeCtrl.text.trim();
      fields['latitude'] = selectedLocation!.latitude.toString();
      fields['longitude'] = selectedLocation!.longitude.toString();
      fields['event_date'] = _fmtDate(date!);
      fields['event_time'] = _fmtTime(time!);
      fields['description'] = descCtrl.text.trim();
      
      // Флаги для сохранения существующих изображений
      if (logoUrl != null && logoFile == null && logoFilename != null) {
        fields['keep_logo'] = 'true';
      }
      
      // Собираем имена файлов для сохранения (те, которые не были заменены)
      final keepImages = <String>[];
      for (int i = 0; i < photoFilenames.length; i++) {
        if (photoFilenames[i].isNotEmpty && photos[i] == null) {
          keepImages.add(photoFilenames[i]);
        }
      }
      // Отправляем массив как keep_images[0], keep_images[1], ...
      for (int i = 0; i < keepImages.length; i++) {
        fields['keep_images[$i]'] = keepImages[i];
      }

      if (createFromClub && selectedClub != null) {
        fields['club_name'] = selectedClub!;
      }
      if (saveTemplate && templateCtrl.text.trim().isNotEmpty) {
        fields['template_name'] = templateCtrl.text.trim();
      }

      // Отправляем запрос
      Map<String, dynamic> data;
      if (files.isEmpty) {
        data = await api.post('/update_event.php', body: fields);
      } else {
        data = await api.postMultipart(
          '/update_event.php',
          files: files,
          fields: fields,
          timeout: const Duration(seconds: 60),
        );
      }

      bool success = false;
      String? errorMessage;

      if (data['success'] == true) {
        success = true;
      } else if (data['success'] == false) {
        errorMessage = data['message'] ?? 'Ошибка при обновлении события';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Событие успешно обновлено')),
        );

        // Возвращаемся на экран детализации с обновленными данными
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Ошибка при обновлении события'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сети: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const PaceAppBar(title: 'Редактирование события'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const PaceAppBar(title: 'Редактирование события'),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Медиа: логотип + 3 фото ----------
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MediaColumn(
                        label: 'Логотип',
                        file: logoFile,
                        url: logoUrl,
                        onPick: _pickLogo,
                        onRemove: () => setState(() {
                          logoFile = null;
                          logoUrl = null;
                          logoFilename = null;
                        }),
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
                                  url: photoUrls[i],
                                  onPick: () => _pickPhoto(i),
                                  onRemove: () => setState(() {
                                    photos[i] = null;
                                    photoUrls[i] = '';
                                    photoFilenames[i] = '';
                                  }),
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
                      _clearFieldError('activity');
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
                            padding: EdgeInsets.zero,
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
                    label: '',
                    value: createFromClub ? selectedClub : null,
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
                  ),

                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.center,
                    child: PrimaryButton(
                      text: 'Сохранить изменения',
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

/// Вспомогательный класс для лейбла
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

/// Медиа-колонка с поддержкой URL для существующих изображений
class _MediaColumn extends StatelessWidget {
  final String label;
  final File? file;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MediaColumn({
    required this.label,
    required this.file,
    this.url,
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
        _MediaTile(
          file: file,
          url: url,
          onPick: onPick,
          onRemove: onRemove,
        ),
      ],
    );
  }
}

/// Медиа-тайл с поддержкой URL для существующих изображений
class _MediaTile extends StatelessWidget {
  final File? file;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MediaTile({
    required this.file,
    this.url,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Если есть новый файл - показываем его
    if (file != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
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

    // Если есть URL существующего изображения - показываем его
    if (url != null && url!.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Builder(
                  builder: (context) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final side = (70 * dpr).round();
                    return CachedNetworkImage(
                      imageUrl: url!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      memCacheWidth: side,
                      memCacheHeight: side,
                      maxWidthDiskCache: side,
                      maxHeightDiskCache: side,
                      errorWidget: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        color: AppColors.border,
                        child: const Icon(Icons.image, size: 28),
                      ),
                    );
                  },
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

    // Пустая плитка для выбора
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
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
}

