import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;
import '../../../../core/utils/error_handler.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../providers/events/add_official_event_provider.dart';
import 'location_picker_screen.dart';

class AddOfficialEventScreen extends ConsumerStatefulWidget {
  const AddOfficialEventScreen({super.key});

  @override
  ConsumerState<AddOfficialEventScreen> createState() =>
      _AddOfficialEventScreenState();
}

class _AddOfficialEventScreenState
    extends ConsumerState<AddOfficialEventScreen> {
  // ── контроллеры для полей ввода (используются для синхронизации с состоянием)
  late final TextEditingController nameCtrl;
  late final TextEditingController placeCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController linkCtrl;
  late final TextEditingController templateCtrl;
  final List<TextEditingController> _distanceControllers = [];

  // ── состояние блока загрузки шаблона
  bool _showTemplateBlock = false;
  String? _selectedTemplate;

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.1;

  @override
  void initState() {
    super.initState();
    // ── инициализируем контроллеры
    nameCtrl = TextEditingController();
    placeCtrl = TextEditingController();
    descCtrl = TextEditingController();
    linkCtrl = TextEditingController();
    templateCtrl = TextEditingController(text: 'Субботний коферан');

    // ── создаём первое поле для ввода дистанции
    _distanceControllers.add(TextEditingController());

    // ── синхронизируем контроллеры с состоянием провайдера
    nameCtrl.addListener(() {
      ref.read(addOfficialEventFormProvider.notifier).updateName(nameCtrl.text);
    });
    placeCtrl.addListener(() {
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updatePlace(placeCtrl.text);
    });
    descCtrl.addListener(() {
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateDescription(descCtrl.text);
    });
    linkCtrl.addListener(() {
      ref.read(addOfficialEventFormProvider.notifier).updateLink(linkCtrl.text);
    });
    templateCtrl.addListener(() {
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateTemplateName(templateCtrl.text);
    });
    _distanceControllers.last.addListener(() {
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateDistance(0, _distanceControllers.last.text);
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

  // ── добавление нового поля для ввода дистанции
  void _addDistanceField() {
    final newController = TextEditingController();
    final index = _distanceControllers.length;
    newController.addListener(() {
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateDistance(index, newController.text);
    });
    setState(() {
      _distanceControllers.add(newController);
    });
    ref.read(addOfficialEventFormProvider.notifier).addDistanceField();
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

    ref.read(addOfficialEventFormProvider.notifier).updateLogoFile(processed);
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

    ref
        .read(addOfficialEventFormProvider.notifier)
        .updateBackgroundFile(processed);
  }

  /// Открыть экран выбора места на карте
  Future<void> _pickLocation() async {
    final formState = ref.read(addOfficialEventFormProvider);
    final result = await Navigator.of(context).push<LocationResult?>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initialPosition: formState.selectedLocation),
      ),
    );

    if (result != null) {
      // ⚡️ Автозаполнение поля "Место проведения" адресом из геокодинга
      if (result.address != null && result.address!.isNotEmpty) {
        placeCtrl.text = result.address!;
      }
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateLocation(result.coordinates, result.address);
    }
  }

  Future<void> _pickDateCupertino() async {
    final formState = ref.read(addOfficialEventFormProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(formState.date ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: today,
      maximumDate: today.add(const Duration(days: 365 * 2)),
      initialDateTime: temp.isBefore(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      ref.read(addOfficialEventFormProvider.notifier).updateDate(temp);
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


  // ── загрузка данных выбранного шаблона
  Future<void> _loadTemplateData(String templateName) async {
    try {
      final templateAsync = await ref.read(
        templateDataProvider(templateName).future,
      );

      // ── Обработка дистанций из шаблона (делаем это ПЕРВЫМ, чтобы контроллеры были готовы)
      // Очищаем существующие контроллеры
      for (final controller in _distanceControllers) {
        controller.dispose();
      }
      _distanceControllers.clear();

      // Получаем дистанции из шаблона
      final distances = templateAsync.distances.isNotEmpty
          ? List<String>.from(templateAsync.distances)
          : [''];

      // Создаём контроллеры для каждой дистанции СНАЧАЛА
      for (int i = 0; i < distances.length; i++) {
        final controller = TextEditingController(text: distances[i]);
        final index = i;
        controller.addListener(() {
          ref
              .read(addOfficialEventFormProvider.notifier)
              .updateDistance(index, controller.text);
        });
        _distanceControllers.add(controller);
      }

      // ── Заполняем форму данными из шаблона
      nameCtrl.text = templateAsync.name;
      placeCtrl.text = templateAsync.place;
      descCtrl.text = templateAsync.description;

      // ── Заполняем ссылку и обновляем провайдер
      final linkValue = (templateAsync.link?.trim() ?? '').replaceAll(' ', '');
      linkCtrl.text = linkValue;

      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateActivity(templateAsync.activity);
      ref
          .read(addOfficialEventFormProvider.notifier)
          .updateDate(templateAsync.date);

      // Координаты
      if (templateAsync.latitude != null && templateAsync.longitude != null) {
        ref
            .read(addOfficialEventFormProvider.notifier)
            .updateLocation(
              LatLng(templateAsync.latitude!, templateAsync.longitude!),
              templateAsync.place,
            );
      }

      // ── Обновляем состояние провайдера (включая ссылку и дистанции)
      // Это должно быть сделано ПЕРЕД обновлением отдельных полей
      ref
          .read(addOfficialEventFormProvider.notifier)
          .loadFromTemplate(
            name: templateAsync.name,
            place: templateAsync.place,
            description: templateAsync.description,
            link: linkValue,
            activity: templateAsync.activity,
            date: templateAsync.date,
            location:
                templateAsync.latitude != null &&
                    templateAsync.longitude != null
                ? LatLng(templateAsync.latitude!, templateAsync.longitude!)
                : null,
            distances: distances,
          );

      // ── Дополнительно обновляем ссылку (для гарантии синхронизации)
      if (linkValue.isNotEmpty) {
        ref.read(addOfficialEventFormProvider.notifier).updateLink(linkValue);
      }

      templateCtrl.text = templateName;

      // ── Принудительно обновляем виджет для отображения новых контроллеров
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Ошибка уже обработана в провайдере через AsyncValue
      if (mounted) {
        // Показываем ошибку через SelectableText.rich (будет добавлено в build)
      }
    }
  }

  Future<void> _submit() async {
    final formState = ref.read(addOfficialEventFormProvider);
    // ── проверяем валидность формы (кнопка неактивна, если форма невалидна, но на всякий случай)
    if (!formState.isValid) {
      return;
    }

    try {
      await ref.read(submitEventProvider.notifier).submit(formState);
      // ── успешная отправка — закрываем экран
      if (mounted) {
        Navigator.of(context).pop('created');
      }
    } catch (e) {
      // Ошибка обрабатывается через AsyncValue в build методе
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── получаем состояние формы из провайдера
    final formState = ref.watch(addOfficialEventFormProvider);
    // ── получаем состояние списка шаблонов
    final templatesAsync = ref.watch(templatesListProvider);
    // ── получаем состояние отправки формы
    final submitAsync = ref.watch(submitEventProvider);
    // ── получаем состояние загрузки шаблона (если выбран)
    final templateDataAsync = _selectedTemplate != null
        ? ref.watch(templateDataProvider(_selectedTemplate!))
        : null;

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
                  if (_showTemplateBlock) {
                    ref.read(templatesListProvider.notifier).reload();
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
                  // ── отображение ошибок отправки формы
                  if (submitAsync.hasError) ...[
                    SelectableText.rich(
                      TextSpan(
                        text: 'Ошибка отправки: ',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                        children: [
                          TextSpan(
                            text: ErrorHandler.format(submitAsync.error!),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── отображение ошибок загрузки шаблона
                  if (templateDataAsync?.hasError == true) ...[
                    SelectableText.rich(
                      TextSpan(
                        text: 'Ошибка загрузки шаблона: ',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                        children: [
                          TextSpan(
                            text: ErrorHandler.format(
                              templateDataAsync!.error!,
                            ),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                    templatesAsync.when(
                      data: (templates) => Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) => InputDecorator(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.getSurfaceColor(context),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
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
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedTemplate,
                                    isExpanded: true,
                                    hint: const Text(
                                      'Выберите шаблон',
                                      style: AppTextStyles.h14w4Place,
                                    ),
                                    onChanged: templates.isNotEmpty
                                        ? (String? newValue) {
                                            setState(
                                              () =>
                                                  _selectedTemplate = newValue,
                                            );
                                          }
                                        : null,
                                    dropdownColor: AppColors.getSurfaceColor(
                                      context,
                                    ),
                                    menuMaxHeight: 300,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: templates.isNotEmpty
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
                                    items: templates.map((item) {
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
                              isLoading: templateDataAsync?.isLoading ?? false,
                              enabled: _selectedTemplate != null,
                            ),
                          ),
                        ],
                      ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: CupertinoActivityIndicator(radius: 9),
                        ),
                      ),
                      error: (error, stack) => SelectableText.rich(
                        TextSpan(
                          text: 'Ошибка загрузки шаблонов: ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                          ),
                          children: [
                            TextSpan(
                              text: ErrorHandler.format(error),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

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
                            file: formState.logoFile,
                            onPick: _pickLogo,
                            onRemove: () => ref
                                .read(addOfficialEventFormProvider.notifier)
                                .updateLogoFile(null),
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
                              file: formState.backgroundFile,
                              onPick: _pickBackground,
                              onRemove: () => ref
                                  .read(addOfficialEventFormProvider.notifier)
                                  .updateBackgroundFile(null),
                              width:
                                  189, // Ширина для соотношения 2.1:1 (90 * 2.1)
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
                          value: formState.activity,
                          isExpanded: true,
                          hint: const Text(
                            'Выберите вид активности',
                            style: AppTextStyles.h14w4Place,
                          ),
                          onChanged: (String? newValue) {
                            ref
                                .read(addOfficialEventFormProvider.notifier)
                                .updateActivity(newValue);
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
                                formState.date != null
                                    ? _fmtDate(formState.date!)
                                    : 'Выберите дату',
                                style: formState.date != null
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
                              value: formState.saveTemplate,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              activeColor: AppColors.brandPrimary,
                              checkColor: AppColors.getSurfaceColor(context),
                              side: BorderSide(
                                color: AppColors.getIconSecondaryColor(context),
                                width: 1.5,
                              ),
                              onChanged: (v) => ref
                                  .read(addOfficialEventFormProvider.notifier)
                                  .updateSaveTemplate(v ?? false),
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
                  if (formState.saveTemplate) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) => TextField(
                        controller: templateCtrl,
                        enabled: formState.saveTemplate,
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
                        if (!submitAsync.isLoading) _submit();
                      },
                      expanded: false,
                      isLoading: submitAsync.isLoading,
                      enabled: formState.isValid,
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
  final double width;
  final double height;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // 📌 Если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
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
