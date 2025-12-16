import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../core/providers/form_state_provider.dart';
import '../../../../core/widgets/form_error_display.dart';
import 'location_picker_screen.dart';

/// Экран редактирования официального события
class EditOfficialEventScreen extends ConsumerStatefulWidget {
  final int eventId;

  const EditOfficialEventScreen({super.key, required this.eventId});

  @override
  ConsumerState<EditOfficialEventScreen> createState() =>
      _EditOfficialEventScreenState();
}

class _EditOfficialEventScreenState
    extends ConsumerState<EditOfficialEventScreen> {
  // контроллеры
  final nameCtrl = TextEditingController();
  final placeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final linkCtrl = TextEditingController();
  final templateCtrl = TextEditingController();

  // выборы
  String? activity;
  DateTime? date;
  TimeOfDay?
  time; // ── время (необязательное для официальных событий, не показываем в UI)

  // ── контроллеры для полей ввода дистанций
  final List<TextEditingController> _distanceControllers = [];

  // чекбоксы
  bool saveTemplate = false;

  // ── отдельный фокус для пикеров, чтобы не поднимать клавиатуру после закрытия
  final _pickerFocusNode = FocusNode(debugLabel: 'editOfficialPickerFocus');

  // медиа
  File? logoFile;
  String? logoUrl; // URL для отображения существующего логотипа
  String? logoFilename; // Имя файла существующего логотипа
  File? backgroundFile;
  String? backgroundUrl; // URL для отображения существующего фона
  String? backgroundFilename; // Имя файла существующего фона

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.1;

  // координаты выбранного места
  LatLng? selectedLocation;

  bool get isFormValid =>
      (nameCtrl.text.trim().isNotEmpty) &&
      (placeCtrl.text.trim().isNotEmpty) &&
      (activity != null) &&
      (date != null) &&
      (selectedLocation != null);

  @override
  void initState() {
    super.initState();
    // Откладываем загрузку данных до завершения сборки дерева виджетов
    // чтобы избежать изменения провайдера во время build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEventData();
      }
    });
    nameCtrl.addListener(() => _refresh());
    placeCtrl.addListener(() => _refresh());
    linkCtrl.addListener(() => _refresh());
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    placeCtrl.dispose();
    descCtrl.dispose();
    linkCtrl.dispose();
    templateCtrl.dispose();
    _pickerFocusNode.dispose();
    // ── освобождаем все контроллеры дистанций
    for (final controller in _distanceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── снимаем фокус перед показом пикеров, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ── добавление нового поля для ввода дистанции
  void _addDistanceField() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => _refresh());
      _distanceControllers.add(newController);
    });
  }

  /// Загрузка данных события для редактирования
  Future<void> _loadEventData() async {
    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    await formNotifier.submitWithLoading(
      () async {
        final userId = await authService.getUserId();

        if (userId == null) {
          throw Exception('Ошибка авторизации');
        }

        final data = await api.get(
          '/update_official_event.php',
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
          linkCtrl.text = event['registration_link'] as String? ?? '';
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

          saveTemplate = (event['template_name'] as String? ?? '').isNotEmpty;

          // Заполняем дату
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

          // ── Заполняем время (необязательное для официальных событий, не показываем в UI)
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

          // Фоновая картинка
          backgroundUrl = event['background_url'] as String?;
          backgroundFilename = event['background_filename'] as String?;

          // ── обработка дистанций из события
          // Очищаем существующие контроллеры
          for (final controller in _distanceControllers) {
            controller.removeListener(() => _refresh());
            controller.dispose();
          }
          _distanceControllers.clear();

          // Парсим дистанции из события (формат: "5000, 10000, 21100" - все в метрах)
          final distanceStr = event['distance'] as String?;
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

          if (!mounted) return;
          setState(() {});
        } else {
          throw Exception(
            data['message'] as String? ?? 'Не удалось загрузить данные события',
          );
        }
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              formState.error ??
                  ErrorHandler.formatWithContext(
                    error,
                    context: 'загрузке данных',
                  ),
            ),
          ),
        );
        Navigator.of(context).pop();
      },
    );
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

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    await formNotifier.submit(
      () async {
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Ошибка: Пользователь не авторизован');
        }

        // Отправляем запрос на удаление
        final data = await api.post(
          '/delete_event.php',
          body: {'event_id': widget.eventId, 'user_id': userId},
        );

        // Проверяем ответ
        if (data['success'] == true) {
          // Успешно удалено
        } else if (data['success'] == false) {
          throw Exception(data['message'] ?? 'Ошибка при удалении события');
        } else {
          throw Exception('Неожиданный формат ответа сервера');
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Возвращаемся на предыдущий экран с результатом удаления
        Navigator.of(context).pop('deleted');
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formState.error ?? 'Ошибка при удалении события'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!isFormValid) {
      return;
    }

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

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
        // ── Время необязательное для официальных событий, отправляем только если указано
        if (time != null) {
          fields['event_time'] = _fmtTime(time!);
        }
        fields['description'] = descCtrl.text.trim();

        // Флаги для сохранения существующих изображений
        if (logoUrl != null && logoFile == null && logoFilename != null) {
          fields['keep_logo'] = 'true';
        }

        if (backgroundUrl != null &&
            backgroundFile == null &&
            backgroundFilename != null) {
          fields['keep_background'] = 'true';
        }

        // ── собираем введённые дистанции (только непустые, все в метрах)
        final distanceValues = _distanceControllers
            .map((ctrl) => ctrl.text.trim())
            .where((value) => value.isNotEmpty)
            .toList();

        // Добавляем ссылку на страницу мероприятия
        if (linkCtrl.text.trim().isNotEmpty) {
          fields['event_link'] = linkCtrl.text.trim();
        }

        if (saveTemplate && templateCtrl.text.trim().isNotEmpty) {
          fields['template_name'] = templateCtrl.text.trim();
        }

        // Отправляем запрос
        Map<String, dynamic> data;
        if (files.isEmpty) {
          // JSON запрос без файлов
          final jsonBody = <String, dynamic>{
            'event_id': fields['event_id'],
            'user_id': fields['user_id'],
            'name': fields['name'],
            'activity': fields['activity'],
            'place': fields['place'],
            'latitude': fields['latitude'],
            'longitude': fields['longitude'],
            'event_date': fields['event_date'],
            'description': fields['description'],
            'event_link': fields['event_link'] ?? '',
            'template_name': fields['template_name'] ?? '',
          };
          // ── Время необязательное для официальных событий, добавляем только если указано
          if (fields.containsKey('event_time') &&
              fields['event_time']!.isNotEmpty) {
            jsonBody['event_time'] = fields['event_time'];
          }
          if (distanceValues.isNotEmpty) {
            jsonBody['distance'] = distanceValues;
          }
          if (fields.containsKey('keep_logo')) {
            jsonBody['keep_logo'] = 'true';
          }
          if (fields.containsKey('keep_background')) {
            jsonBody['keep_background'] = 'true';
          }
          data = await api.post('/update_official_event.php', body: jsonBody);
        } else {
          // Multipart запрос с файлами
          // ── отправляем дистанции как массив (все в метрах)
          if (distanceValues.isNotEmpty) {
            // Для multipart нужно отправлять как массив
            for (int i = 0; i < distanceValues.length; i++) {
              fields['distance[$i]'] = distanceValues[i];
            }
          }
          data = await api.postMultipart(
            '/update_official_event.php',
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

        if (!success) {
          throw Exception(errorMessage ?? 'Ошибка при обновлении события');
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Возвращаемся на экран детализации с обновленными данными
        Navigator.of(context).pop(true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(formState.error ?? 'Ошибка при обновлении события'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);
    if (formState.isLoading) {
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
                              url: backgroundUrl,
                              onPick: _pickBackground,
                              onRemove: () => setState(() {
                                backgroundFile = null;
                                backgroundUrl = null;
                                backgroundFilename = null;
                              }),
                              width: 189, // Ширина для соотношения 2.1:1
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
                    builder: (context) => Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: placeCtrl,
                            enabled: false,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextSecondaryColor(context),
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
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дата ----------
                  Column(
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
                                fillColor: AppColors.getSurfaceColor(context),
                                contentPadding: const EdgeInsets.symmetric(
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
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 18 + 14,
                                  minHeight: 18,
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
                              child: Text(
                                date != null
                                    ? _fmtDate(date!)
                                    : 'Выберите дату',
                                style: date != null
                                    ? AppTextStyles.h14w4.copyWith(
                                        color: AppColors.getTextPrimaryColor(
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
                    children: List.generate(_distanceControllers.length, (
                      index,
                    ) {
                      return SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 32 - 16) / 2,
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
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  // ── кнопка "добавить ещё"
                  GestureDetector(
                    onTap: _addDistanceField,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.add_circled,
                          size: 20,
                          color: AppColors.brandPrimary,
                        ),
                        SizedBox(width: 8),
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
                  // ── Отображение ошибок
                  if (formState.hasErrors) ...[
                    FormErrorDisplay(formState: formState),
                    const SizedBox(height: 16),
                  ],
                  // ────────────────────────────────────────────────────────────────
                  // 💾 КНОПКА СОХРАНЕНИЯ
                  // ────────────────────────────────────────────────────────────────
                  Center(
                    child: Builder(
                      builder: (context) {
                        final formState = ref.watch(formStateProvider);
                        return PrimaryButton(
                          text: 'Сохранить изменения',
                          onPressed: !formState.isSubmitting ? _submit : () {},
                          width: 230,
                          isLoading: formState.isSubmitting,
                          enabled: isFormValid && !formState.isSubmitting,
                        );
                      },
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

/// Медиа-тайл с поддержкой URL для существующих изображений
class _MediaTile extends StatelessWidget {
  final File? file;
  final String? url;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final double width;
  final double height;

  const _MediaTile({
    required this.file,
    this.url,
    required this.onPick,
    required this.onRemove,
    required this.width,
    required this.height,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final targetW = (width * dpr).round();
                  final targetH = (height * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    width: width,
                    height: height,
                    memCacheWidth: targetW,
                    memCacheHeight: targetH,
                    maxWidthDiskCache: targetW,
                    maxHeightDiskCache: targetH,
                    placeholder: (context, url) => Container(
                      width: width,
                      height: height,
                      color: AppColors.getBackgroundColor(context),
                      child: const Center(child: CupertinoActivityIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: width,
                      height: height,
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
      ),
    );
  }
}
