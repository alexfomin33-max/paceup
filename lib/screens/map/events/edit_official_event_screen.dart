import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/widgets/app_bar.dart';
import '../../../core/widgets/interactive_back_swipe.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/providers/form_state_provider.dart';
import '../../../core/widgets/form_error_display.dart';
import '../../../providers/events/edit_official_event_provider.dart';
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

  // ── контроллеры для полей ввода дистанций
  final List<TextEditingController> _distanceControllers = [];

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.3;

  bool _controllersInitialized = false;

  bool get isFormValid {
    final state = ref.read(editOfficialEventProvider(widget.eventId));
    return (nameCtrl.text.trim().isNotEmpty) &&
        (placeCtrl.text.trim().isNotEmpty) &&
        (state.activity != null) &&
        (state.date != null) &&
        (state.time != null) &&
        (state.selectedLocation != null);
  }

  @override
  void initState() {
    super.initState();
    nameCtrl.addListener(() => setState(() {}));
    placeCtrl.addListener(() => setState(() {}));
    linkCtrl.addListener(() => setState(() {}));
    // Инициализируем контроллеры после первой загрузки данных
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
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

  /// Инициализация контроллеров из загруженных данных
  Future<void> _initializeControllers() async {
    if (_controllersInitialized) return;

    final textFields = await ref
        .read(editOfficialEventProvider(widget.eventId).notifier)
        .loadEventData();

    if (textFields != null && mounted) {
      nameCtrl.text = textFields['name'] ?? '';
      placeCtrl.text = textFields['place'] ?? '';
      descCtrl.text = textFields['description'] ?? '';
      linkCtrl.text = textFields['link'] ?? '';
      templateCtrl.text = textFields['template_name'] ?? '';

      // Обработка дистанций
      for (final controller in _distanceControllers) {
        controller.removeListener(() => setState(() {}));
        controller.dispose();
      }
      _distanceControllers.clear();

      final distanceStr = textFields['distance'] ?? '';
      if (distanceStr.isNotEmpty) {
        final distances = distanceStr
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .toList();

        for (final dist in distances) {
          final controller = TextEditingController(text: dist);
          controller.addListener(() => setState(() {}));
          _distanceControllers.add(controller);
        }
      }

      // Если дистанций нет, создаём одно пустое поле
      if (_distanceControllers.isEmpty) {
        final controller = TextEditingController();
        controller.addListener(() => setState(() {}));
        _distanceControllers.add(controller);
      }

      _controllersInitialized = true;
    }
  }

  // ── добавление нового поля для ввода дистанции
  void _addDistanceField() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => setState(() {}));
      _distanceControllers.add(newController);
    });
  }

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

    ref
        .read(editOfficialEventProvider(widget.eventId).notifier)
        .setLogoFile(processed);
  }

  Future<void> _pickBackground() async {
    // ── выбираем фон с обрезкой 2.3:1 и сжатием до оптимального размера
    final processed = await ImagePickerHelper.pickAndProcessImage(
      context: context,
      aspectRatio: _backgroundAspectRatio,
      maxSide: 1600,
      jpegQuality: 80,
      cropTitle: 'Обрезка фонового фото',
    );
    if (processed == null || !mounted) return;

    ref
        .read(editOfficialEventProvider(widget.eventId).notifier)
        .setBackgroundFile(processed);
  }

  /// Открыть экран выбора места на карте
  Future<void> _pickLocation() async {
    final state = ref.read(editOfficialEventProvider(widget.eventId));
    final result = await Navigator.of(context).push<LocationResult?>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: state.selectedLocation),
      ),
    );

    if (result != null) {
      ref
          .read(editOfficialEventProvider(widget.eventId).notifier)
          .setLocation(result.coordinates);
      if (result.address != null && result.address!.isNotEmpty) {
        placeCtrl.text = result.address!;
      }
    }
  }

  Future<void> _pickDateCupertino() async {
    final state = ref.read(editOfficialEventProvider(widget.eventId));
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(state.date ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: today,
      maximumDate: today.add(const Duration(days: 365 * 2)),
      initialDateTime: temp.isBefore(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      ref.read(editOfficialEventProvider(widget.eventId).notifier).setDate(temp);
    }
  }

  Future<void> _pickTimeCupertino() async {
    final state = ref.read(editOfficialEventProvider(widget.eventId));
    DateTime temp = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      state.time?.hour ?? 12,
      state.time?.minute ?? 0,
    );

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      use24hFormat: true,
      initialDateTime: temp,
      onDateTimeChanged: (dt) => temp = dt,
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      ref.read(editOfficialEventProvider(widget.eventId).notifier).setTime(
        TimeOfDay(hour: temp.hour, minute: temp.minute),
      );
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

    final success = await ref
        .read(editOfficialEventProvider(widget.eventId).notifier)
        .deleteEvent();

    if (!mounted) return;

    if (success) {
      // Возвращаемся на предыдущий экран с результатом удаления
      Navigator.of(context).pop('deleted');
    } else {
      final state = ref.read(editOfficialEventProvider(widget.eventId));
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!isFormValid) {
      return;
    }

    final editState = ref.read(editOfficialEventProvider(widget.eventId));
    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    await formNotifier.submit(
      () async {
        final files = <String, File>{};
        final fields = <String, String>{};

        // Добавляем логотип (если выбран новый)
        if (editState.logoFile != null) {
          files['logo'] = editState.logoFile!;
        }

        // Добавляем фоновую картинку (если выбран новый)
        if (editState.backgroundFile != null) {
          files['background'] = editState.backgroundFile!;
        }

        // Добавляем поля формы
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Ошибка авторизации. Необходимо войти в систему');
        }
        fields['event_id'] = widget.eventId.toString();
        fields['user_id'] = userId.toString();
        fields['name'] = nameCtrl.text.trim();
        fields['activity'] = editState.activity!;
        fields['place'] = placeCtrl.text.trim();
        fields['latitude'] = editState.selectedLocation!.latitude.toString();
        fields['longitude'] = editState.selectedLocation!.longitude.toString();
        fields['event_date'] = _fmtDate(editState.date!);
        fields['event_time'] = _fmtTime(editState.time!);
        fields['description'] = descCtrl.text.trim();

        // Флаги для сохранения существующих изображений
        if (editState.logoUrl != null &&
            editState.logoFile == null &&
            editState.logoFilename != null) {
          fields['keep_logo'] = 'true';
        }

        if (editState.backgroundUrl != null &&
            editState.backgroundFile == null &&
            editState.backgroundFilename != null) {
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

        if (editState.saveTemplate && templateCtrl.text.trim().isNotEmpty) {
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
            'event_time': fields['event_time'],
            'description': fields['description'],
            'event_link': fields['event_link'] ?? '',
            'template_name': fields['template_name'] ?? '',
          };
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
    final editState = ref.watch(editOfficialEventProvider(widget.eventId));

    // Инициализируем контроллеры, если они еще не заполнены
    if (!_controllersInitialized && !editState.isLoadingData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeControllers();
      });
    }
    if (formState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Редактирование события'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
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
                            file: editState.logoFile,
                            url: editState.logoUrl,
                            onPick: _pickLogo,
                            onRemove: () => ref
                                .read(editOfficialEventProvider(widget.eventId)
                                    .notifier)
                                .removeLogo(),
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
                              file: editState.backgroundFile,
                              url: editState.backgroundUrl,
                              onPick: _pickBackground,
                              onRemove: () => ref
                                  .read(editOfficialEventProvider(widget.eventId)
                                      .notifier)
                                  .removeBackground(),
                              width: 207, // Ширина для соотношения 2.3:1
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
                          value: editState.activity,
                          isExpanded: true,
                          hint: const Text(
                            'Выберите вид активности',
                            style: AppTextStyles.h14w4Place,
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              ref
                                  .read(editOfficialEventProvider(widget.eventId)
                                      .notifier)
                                  .setActivity(newValue);
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
                                      editState.date != null
                                          ? _fmtDate(editState.date!)
                                          : 'Выберите дату',
                                      style: editState.date != null
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
                                      editState.time != null
                                          ? _fmtTime(editState.time!)
                                          : 'Выберите время',
                                      style: editState.time != null
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

                  const SizedBox(height: 25),
                  // ── Отображение ошибок
                  if (formState.hasErrors) ...[
                    FormErrorDisplay(formState: formState),
                    const SizedBox(height: 16),
                  ],
                  // ── Кнопки: Сохранить и Удалить событие
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: PrimaryButton(
                          text: 'Сохранить',
                          onPressed: () {
                            if (!formState.isSubmitting &&
                                !formState.isLoading) {
                              _submit();
                            }
                          },
                          expanded: true,
                          isLoading: formState.isSubmitting,
                          enabled: isFormValid && !formState.isSubmitting,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: formState.isSubmitting || formState.isLoading
                            ? null
                            : _deleteEvent,
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
