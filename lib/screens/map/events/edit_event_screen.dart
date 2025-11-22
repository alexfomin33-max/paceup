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
  List<String> clubs = [];
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
  final List<String> photoUrls = [
    '',
    '',
    '',
  ]; // URL для отображения существующих фото
  final List<String> photoFilenames = [
    '',
    '',
    '',
  ]; // Имена файлов существующих фото

  // координаты выбранного места
  LatLng? selectedLocation;

  // ── состояние загрузки
  bool _loading = false;
  bool _loadingData = true;
  bool _deleting = false; // ── состояние удаления

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
    _loadEventData();
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

  /// Загрузка данных события для редактирования
  Future<void> _loadEventData() async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Ошибка авторизации')));
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
        final placeText = event['place'] as String? ?? '';
        placeCtrl.text = placeText;
        descCtrl.text = event['description'] as String? ?? '';
        clubCtrl.text = event['club_name'] as String? ?? '';
        templateCtrl.text = event['template_name'] as String? ?? '';

        // Заполняем выборы
        final activityStr = event['activity'] as String?;
        // Проверяем, что значение активности входит в список допустимых
        const allowedActivities = ['Бег', 'Велосипед', 'Плавание'];
        if (activityStr != null && allowedActivities.contains(activityStr)) {
          activity = activityStr;
        } else {
          activity = null; // Если значение не валидно, оставляем null
        }

        final clubNameStr = event['club_name'] as String? ?? '';
        createFromClub = clubNameStr.isNotEmpty;
        // Проверяем, что значение клуба входит в список допустимых
        // Если клубы ещё не загружены, сохраняем название и проверим позже
        if (createFromClub) {
          if (clubs.contains(clubNameStr)) {
            selectedClub = clubNameStr;
          } else if (clubs.isEmpty) {
            // Если клубы ещё не загружены, сохраняем название
            // Оно будет проверено после загрузки клубов
            selectedClub = clubNameStr;
          } else {
            selectedClub = null; // Если значение не валидно, оставляем null
          }
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
                data['message'] as String? ??
                    'Не удалось загрузить данные события',
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

  /// ──────────────────────── Удаление события ────────────────────────
  /// Показываем диалог подтверждения удаления
  Future<bool> _confirmDelete() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удалить событие?'),
        content: const Text(
          'Событие будет скрыто из приложения. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Удаление события
  Future<void> _deleteEvent() async {
    // ── показываем диалог подтверждения
    final confirmed = await _confirmDelete();
    if (!confirmed) return;

    // ── защита от повторных нажатий
    if (_deleting) return;
    setState(() => _deleting = true);

    final api = ApiService();
    final authService = AuthService();

    try {
      final userId = await authService.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Отправляем запрос на удаление
      final data = await api.post(
        '/delete_event.php',
        body: {'event_id': widget.eventId, 'user_id': userId},
      );

      // Проверяем ответ
      bool success = false;
      String? errorMessage;

      if (data['success'] == true) {
        success = true;
      } else if (data['success'] == false) {
        errorMessage = data['message'] ?? 'Ошибка при удалении события';
      } else {
        errorMessage = 'Неожиданный формат ответа сервера';
      }

      if (success) {
        if (!mounted) return;

        // Возвращаемся на предыдущий экран с результатом удаления
        Navigator.of(context).pop('deleted');
      } else {
        if (!mounted) return;
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Ошибка при удалении события'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сети: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submit() async {
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!isFormValid) {
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
      fields['event_id'] = widget.eventId.toString();
      fields['user_id'] = userId.toString();
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Логотип',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MediaTile(
                            file: logoFile,
                            url: logoUrl,
                            onPick: _pickLogo,
                            onRemove: () => setState(() {
                              logoFile = null;
                              logoUrl = null;
                              logoFilename = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Фото события',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 24),

                  // ---------- Название ----------
                  const Text(
                    'Название события',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    style: AppTextStyles.h14w4,
                    decoration: InputDecoration(
                      hintText: 'Введите название события',
                      hintStyle: AppTextStyles.h14w4Place,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 17,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Вид активности ----------
                  const Text(
                    'Вид активности',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
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
                        dropdownColor: AppColors.surface,
                        menuMaxHeight: 300,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.iconSecondary,
                        ),
                        style: AppTextStyles.h14w4,
                        items: const ['Бег', 'Велосипед', 'Плавание'].map((
                          option,
                        ) {
                          return DropdownMenuItem<String>(
                            value: option,
                            child: Text(option, style: AppTextStyles.h14w4),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Место + кнопка "Карта" ----------
                  const Text(
                    'Место проведения',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: placeCtrl,
                          enabled: false,
                          style: AppTextStyles.h14w4.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Выберите место на карте',
                            hintStyle: AppTextStyles.h14w4Place,
                            filled: true,
                            fillColor: AppColors.disabled,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 17,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              borderSide: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.6),
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
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                            backgroundColor: AppColors.surface,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(CupertinoIcons.placemark, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дата / Время ----------
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Дата проведения',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickDateCupertino,
                              child: AbsorbPointer(
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 18,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 12,
                                        right: 6,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.calendar,
                                        size: 18,
                                        color: AppColors.iconPrimary,
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 18 + 14,
                                      minHeight: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    date != null
                                        ? _fmtDate(date!)
                                        : 'Выберите дату',
                                    style: date != null
                                        ? AppTextStyles.h14w4
                                        : AppTextStyles.h14w4Place,
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
                            const Text(
                              'Время начала',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickTimeCupertino,
                              child: AbsorbPointer(
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 18,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(
                                        left: 12,
                                        right: 6,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.time,
                                        size: 18,
                                        color: AppColors.iconPrimary,
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 18 + 14,
                                      minHeight: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
                                      ),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    time != null
                                        ? _fmtTime(time!)
                                        : 'Выберите время',
                                    style: time != null
                                        ? AppTextStyles.h14w4
                                        : AppTextStyles.h14w4Place,
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
                  const Text(
                    'Описание события',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descCtrl,
                    maxLines: 12,
                    minLines: 7,
                    textAlignVertical: TextAlignVertical.top,
                    style: AppTextStyles.h14w4,
                    decoration: InputDecoration(
                      hintText: 'Введите описание события',
                      hintStyle: AppTextStyles.h14w4Place,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                  // ── Кнопки: Сохранить и Удалить событие
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: PrimaryButton(
                          text: 'Сохранить',
                          onPressed: () {
                            if (!_loading && !_deleting) _submit();
                          },
                          expanded: true,
                          isLoading: _loading,
                          enabled: isFormValid,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _deleting || _loading ? null : _deleteEvent,
                        child: const Text(
                          'Удалить событие',
                          style: TextStyle(
                            color: AppColors.error,
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.background,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                file!,
                fit: BoxFit.cover,
                width: 90,
                height: 90,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.background,
                  child: const Icon(
                    CupertinoIcons.photo,
                    size: 24,
                    color: AppColors.iconSecondary,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
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

    // Если есть URL существующего изображения - показываем его
    if (url != null && url!.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onPick,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.background,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final side = (90 * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    memCacheWidth: side,
                    maxWidthDiskCache: side,
                    placeholder: (context, url) => Container(
                      color: AppColors.background,
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.background,
                      child: const Icon(
                        CupertinoIcons.photo,
                        size: 24,
                        color: AppColors.iconSecondary,
                      ),
                    ),
                  );
                },
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
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

    // Пустая плитка для выбора
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: 90,
        height: 90,
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
