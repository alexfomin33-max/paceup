import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/providers/form_state_provider.dart';
import '../../../../core/widgets/form_error_display.dart';
import 'location_picker_screen.dart';

/// Экран редактирования события
class EditEventScreen extends ConsumerStatefulWidget {
  final int eventId;

  const EditEventScreen({super.key, required this.eventId});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final clubCtrl = TextEditingController();
  final templateCtrl = TextEditingController();
  final distanceCtrl1 = TextEditingController();
  final distanceCtrl2 = TextEditingController();

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
  File? backgroundFile;
  String? backgroundUrl; // URL для отображения существующей фоновой картинки
  String? backgroundFilename; // Имя файла существующей фоновой картинки
  final List<File?> photos = [null, null, null];
  
  // ── исходные значения дистанций для сохранения при отправке формы
  String? _originalDistanceFrom;
  String? _originalDistanceTo;
  // ── отдельный фокус для пикеров, чтобы не поднимать клавиатуру после закрытия
  final _pickerFocusNode = FocusNode(debugLabel: 'editEventPickerFocus');

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.1;
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

  // ── состояние загрузки данных
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
    distanceCtrl1.dispose();
    distanceCtrl2.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── загрузка списка клубов пользователя
  Future<void> _loadUserClubs() async {
    try {
      final api = ref.read(apiServiceProvider);
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
      final api = ref.read(apiServiceProvider);
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

        // ── безопасное чтение времени (колонка может отсутствовать в старых записях)
        try {
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
        } catch (e) {
          // Игнорируем ошибку, если поле отсутствует в ответе
          time = null;
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

        // Фоновая картинка
        backgroundUrl = event['background_url'] as String?;
        backgroundFilename = event['background_filename'] as String?;

        // Фотографии
        final photosList = event['photos'] as List<dynamic>? ?? [];
        for (int i = 0; i < 3 && i < photosList.length; i++) {
          final photo = photosList[i] as Map<String, dynamic>?;
          if (photo != null) {
            photoUrls[i] = photo['url'] as String? ?? '';
            photoFilenames[i] = photo['filename'] as String? ?? '';
          }
        }

        // Дистанции "от" и "до"
        // Сначала проверяем прямые поля distance_from и distance_to
        final distanceFrom = event['distance_from'];
        final distanceTo = event['distance_to'];
        
        // Загружаем distance_from
        if (distanceFrom != null) {
          final distanceFromStr = distanceFrom.toString().trim();
          if (distanceFromStr.isNotEmpty) {
            distanceCtrl1.text = distanceFromStr;
            _originalDistanceFrom = distanceFromStr; // Сохраняем исходное значение
          }
        }
        
        // Загружаем distance_to
        if (distanceTo != null) {
          final distanceToStr = distanceTo.toString().trim();
          if (distanceToStr.isNotEmpty) {
            distanceCtrl2.text = distanceToStr;
            _originalDistanceTo = distanceToStr; // Сохраняем исходное значение
          }
        }
        
        // Если прямые поля не заполнены, проверяем массив distances (для обратной совместимости)
        // Проверяем distance_from из массива, если оно еще не загружено
        if (_originalDistanceFrom == null) {
          final distancesList = event['distances'] as List<dynamic>? ?? [];
          if (distancesList.isNotEmpty) {
            final distFromStr = distancesList[0].toString().trim();
            if (distFromStr.isNotEmpty) {
              distanceCtrl1.text = distFromStr;
              _originalDistanceFrom = distFromStr; // Сохраняем исходное значение
            }
          }
        }
        
        // Проверяем distance_to из массива, если оно еще не загружено
        if (_originalDistanceTo == null) {
          final distancesList = event['distances'] as List<dynamic>? ?? [];
          if (distancesList.length > 1) {
            final distToStr = distancesList[1].toString().trim();
            if (distToStr.isNotEmpty) {
              distanceCtrl2.text = distToStr;
              _originalDistanceTo = distToStr; // Сохраняем исходное значение
            }
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
          SnackBar(
            content: Text(
              ErrorHandler.formatWithContext(e, context: 'загрузке данных'),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickLogo() async {
    // ── выбираем логотип с круглой обрезкой
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _logoAspectRatio,
      maxSide: ImageCompressionPreset.logo.maxSide,
      jpegQuality: ImageCompressionPreset.logo.quality,
      cropTitle: 'Обрезка логотипа',
      isCircular: true,
    );
    if (processed == null || !mounted) return;

    setState(() {
      logoFile = processed;
      logoUrl = null; // Сбрасываем URL, так как выбран новый файл
    });
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

    setState(() {
      backgroundFile = processed;
      backgroundUrl = null; // Сбрасываем URL, так как выбран новый файл
    });
  }

  Future<void> _pickPhoto(int i) async {
    // ── выбираем новое фото и уменьшаем размер для ускорения загрузки
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final compressed = await compressLocalImage(
      sourceFile: File(picked.path),
      maxSide: ImageCompressionPreset.eventPhoto.maxSide,
      jpegQuality: ImageCompressionPreset.eventPhoto.quality,
    );
    if (!mounted) return;

    setState(() {
      photos[i] = compressed;
      photoUrls[i] = ''; // Сбрасываем URL, так как выбран новый файл
      photoFilenames[i] = '';
    });
  }

  /// Открыть экран выбора места на карте
  Future<void> _pickLocation() async {
    _unfocusKeyboard();
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

  // ── снимаем фокус перед показом пикеров, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickDateCupertino() async {
    _unfocusKeyboard();
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
    _unfocusKeyboard();
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
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: 0),
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

    final api = ref.read(apiServiceProvider);
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
          content: Text(ErrorHandler.format(e)),
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

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = AuthService();

    await formNotifier.submit(
      () async {
        final files = <String, File>{};
        final fields = <String, String>{};

        // Добавляем логотип (если выбран новый)
        if (logoFile != null) {
          files['logo'] = logoFile!;
        }

        // Добавляем фоновую картинку (если выбран новый)
        if (backgroundFile != null) {
          files['background'] = backgroundFile!;
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
          throw Exception('Ошибка авторизации. Необходимо войти в систему');
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

        // Добавляем дистанции "от" и "до"
        // ВАЖНО: Всегда отправляем значения, если они были загружены из БД,
        // чтобы не потерять данные при обновлении других полей (например, фоновой картинки)
        final distanceFromValue = distanceCtrl1.text.trim();
        if (distanceFromValue.isNotEmpty) {
          // Пользователь ввел новое значение - используем его
          fields['distances[0]'] = distanceFromValue;
        } else if (_originalDistanceFrom != null && _originalDistanceFrom!.isNotEmpty) {
          // Поле пустое, но было исходное значение - сохраняем его, чтобы не обнулить в БД
          fields['distances[0]'] = _originalDistanceFrom!;
        }
        // Если и текущее значение пустое, и исходное значение не было установлено,
        // поле не отправляется, и PHP установит null (это нормально для новых событий)
        
        final distanceToValue = distanceCtrl2.text.trim();
        if (distanceToValue.isNotEmpty) {
          // Пользователь ввел новое значение - используем его
          fields['distances[1]'] = distanceToValue;
        } else if (_originalDistanceTo != null && _originalDistanceTo!.isNotEmpty) {
          // Поле пустое, но было исходное значение - сохраняем его, чтобы не обнулить в БД
          fields['distances[1]'] = _originalDistanceTo!;
        }
        // Если и текущее значение пустое, и исходное значение не было установлено,
        // поле не отправляется, и PHP установит null (это нормально для новых событий)

        // Флаги для сохранения существующих изображений
        if (logoUrl != null && logoFile == null && logoFilename != null) {
          fields['keep_logo'] = 'true';
        }

        if (backgroundUrl != null &&
            backgroundFile == null &&
            backgroundFilename != null) {
          fields['keep_background'] = 'true';
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

        // Проверяем ответ
        if (data['success'] != true) {
          final errorMessage =
              data['message'] ?? 'Ошибка при обновлении события';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Возвращаемся на экран детализации с обновленными данными
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);

    if (_loadingData) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Редактирование события',
          showBack: true,
          showBottomDivider: true,
          actions: [
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.delete,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: _deleteEvent,
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: PaceAppBar(
          title: 'Редактирование события',
          showBack: true,
          showBottomDivider: true,
          actions: [
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.delete,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: _deleteEvent,
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Stack(
              children: [
                // ───────── Скроллируемый контент
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 60),
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
                                url: logoUrl,
                                onPick: _pickLogo,
                                onRemove: () => setState(() {
                                  logoFile = null;
                                  logoUrl = null;
                                  logoFilename = null;
                                }),
                                isCircular: true,
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
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _MediaTile(
                                  file: backgroundFile,
                                  url: backgroundUrl,
                                  onPick: _pickBackground,
                                  onRemove: () => setState(() {
                                    backgroundFile = null;
                                    backgroundUrl = null;
                                    backgroundFilename = null;
                                  }),
                                  width: 189, // Ширина для соотношения 2.1:1 (90 * 2.1)
                                  height: 90,
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
                              items: const ['Бег', 'Велосипед', 'Плавание'].map(
                                (option) {
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
                                },
                              ).toList(),
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
                        builder: (context) => Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: placeCtrl,
                                enabled: false,
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextSecondaryColor(
                                    context,
                                  ),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Выберите место на карте',
                                  hintStyle: AppTextStyles.h14w4Place,
                                  filled: true,
                                  fillColor: AppColors.getSurfaceMutedColor(
                                    context,
                                  ),
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
                                  foregroundColor:
                                      AppColors.getTextPrimaryColor(context),
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
                        ),
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
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
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
                                              color:
                                                  AppColors.getIconPrimaryColor(
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
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
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
                                              color:
                                                  AppColors.getIconPrimaryColor(
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
                      // ── два поля для ввода дистанций (в два столбца)
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) => TextField(
                                controller: distanceCtrl1,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: '0 метров',
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
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '—',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Builder(
                              builder: (context) => TextField(
                                controller: distanceCtrl2,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: AppTextStyles.h14w4.copyWith(
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: '0 метров',
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
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    borderSide: BorderSide(
                                      color: AppColors.getBorderColor(context),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ---------- Фото события ----------
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
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                          maxLines: 30,
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

                      const SizedBox(height: 25),
                      // Показываем ошибки, если есть
                      if (formState.hasErrors) ...[
                        FormErrorDisplay(formState: formState),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),

                // ───────── Плавающая кнопка поверх контента
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: Builder(
                        builder: (context) {
                          final formState = ref.watch(formStateProvider);
                          final isEnabled =
                              isFormValid && !formState.isSubmitting;
                          return Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            elevation: 0,
                            child: InkWell(
                              onTap: isEnabled && !formState.isSubmitting
                                  ? _submit
                                  : null,
                              borderRadius: BorderRadius.circular(
                                AppRadius.xxl,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 50,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isEnabled
                                      ? AppColors.brandPrimary
                                      : AppColors.brandPrimary.withValues(
                                          alpha: 0.5,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xxl,
                                  ),
                                ),
                                child: formState.isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.surface,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        'Сохранить',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.surface,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
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
  final bool isCircular;
  final double? width;
  final double? height;

  const _MediaTile({
    required this.file,
    this.url,
    required this.onPick,
    required this.onRemove,
    this.isCircular = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final tileWidth = width ?? 90;
    final tileHeight = height ?? 90;
    
    // Если есть новый файл - показываем его
    if (file != null) {
      return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onPick,
              child: isCircular
                  ? ClipOval(
                      child: Image.file(
                        file!,
                        fit: BoxFit.cover,
                        width: tileWidth,
                        height: tileHeight,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: tileWidth,
                          height: tileHeight,
                          color: AppColors.getBackgroundColor(context),
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(
                        file!,
                        fit: BoxFit.cover,
                        width: tileWidth,
                        height: tileHeight,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: tileWidth,
                          height: tileHeight,
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
              child: isCircular
                  ? ClipOval(
                      child: Builder(
                        builder: (context) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final side = (tileWidth * dpr).round();
                          return CachedNetworkImage(
                            imageUrl: url!,
                            fit: BoxFit.cover,
                            width: tileWidth,
                            height: tileHeight,
                            memCacheWidth: side,
                            maxWidthDiskCache: side,
                            placeholder: (context, url) => Container(
                              width: tileWidth,
                              height: tileHeight,
                              color: AppColors.getBackgroundColor(context),
                              child: const Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: tileWidth,
                              height: tileHeight,
                              color: AppColors.getBackgroundColor(context),
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 24,
                                color: AppColors.getIconSecondaryColor(context),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Builder(
                        builder: (context) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final side = (tileWidth * dpr).round();
                          return CachedNetworkImage(
                            imageUrl: url!,
                            fit: BoxFit.cover,
                            width: tileWidth,
                            height: tileHeight,
                            memCacheWidth: side,
                            maxWidthDiskCache: side,
                            placeholder: (context, url) => Container(
                              width: tileWidth,
                              height: tileHeight,
                              color: AppColors.getBackgroundColor(context),
                              child: const Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: tileWidth,
                              height: tileHeight,
                              color: AppColors.getBackgroundColor(context),
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 24,
                                color: AppColors.getIconSecondaryColor(context),
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
              child: Builder(
                builder: (context) => GestureDetector(
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
            ),
          ],
        );
    }

    // Пустая плитка для выбора
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onPick,
        child: Container(
            width: tileWidth,
            height: tileHeight,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular
                  ? null
                  : BorderRadius.circular(AppRadius.sm),
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
        ),
      );
  }
}
