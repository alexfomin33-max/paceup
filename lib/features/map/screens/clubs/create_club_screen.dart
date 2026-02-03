import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show ImageCompressionPreset;
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../core/providers/form_state_provider.dart';
import '../../../../core/providers/form_state.dart';
import '../../../../core/widgets/form_error_display.dart';

class CreateClubScreen extends ConsumerStatefulWidget {
  const CreateClubScreen({super.key});

  @override
  ConsumerState<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends ConsumerState<CreateClubScreen> {
  // ── контроллеры
  final nameCtrl = TextEditingController();
  // ── контроллеры для полей ввода страниц клуба (link + дополнительные через «добавить ещё»)
  final List<TextEditingController> _linkControllers = [];
  final cityCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  // ── выборы
  String? activity;
  DateTime? foundationDate;
  bool isOpenCommunity =
      true; // true = открытое сообщество (по умолчанию выбрано)

  // ── список городов для автокомплита (загружается из БД)
  List<String> _cities = [];
  
  // ── Выбранный город из списка (для валидации)
  String? _selectedCity;

  // ── медиа
  File? logoFile;
  File? backgroundFile;
  // ── отдельный фокус для пикеров, чтобы не поднимать клавиатуру после закрытия
  final _pickerFocusNode = FocusNode(debugLabel: 'createClubPickerFocus');

  // ──────────── фиксированные пропорции для обрезки медиа ────────────
  static const double _logoAspectRatio = 1;
  static const double _backgroundAspectRatio = 2.1;


  bool get isFormValid =>
      nameCtrl.text.trim().isNotEmpty &&
      _selectedCity != null && _selectedCity!.isNotEmpty &&
      activity != null &&
      foundationDate != null;

  @override
  void initState() {
    super.initState();
    // ── создаём первое поле для ввода страницы клуба
    _linkControllers.add(TextEditingController());
    _linkControllers.last.addListener(() {
      _refresh();
    });
    nameCtrl.addListener(() {
      _refresh();
      _clearFieldError('name');
    });
    cityCtrl.addListener(() {
      _refresh();
      _clearFieldError('city');
      // Если текст изменился не через выбор из списка, сбрасываем выбранный город
      if (cityCtrl.text.trim() != _selectedCity) {
        _selectedCity = null;
      }
    });
    // Загружаем список городов из БД
    _loadCities();
  }

  /// Загрузка списка городов из БД через API
  Future<void> _loadCities() async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api
          .get('/get_cities.php')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'Превышено время ожидания загрузки городов',
              );
            },
          );

      if (data['success'] == true && data['cities'] != null) {
        final cities = data['cities'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _cities = cities.map((city) => city.toString()).toList();
          });
        }
      }
    } catch (e) {
      // В случае ошибки оставляем пустой список
      // Пользователь все равно сможет ввести город вручную
      // Ошибка не критична, так как автокомплит работает и без списка
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    // ── освобождаем все контроллеры страниц клуба
    for (final controller in _linkControllers) {
      controller.dispose();
    }
    cityCtrl.dispose();
    descCtrl.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _refresh() => setState(() {});

  // ── очистка ошибки для конкретного поля при взаимодействии
  void _clearFieldError(String fieldName) {
    ref.read(formStateProvider.notifier).clearFieldError(fieldName);
  }

  // ── добавление нового поля для ввода страницы клуба (максимум 3 поля)
  void _addLinkField() {
    // ── ограничиваем количество полей до 3
    if (_linkControllers.length >= 3) return;
    
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() {
        _refresh();
      });
      _linkControllers.add(newController);
    });
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

    if (mounted) {
      setState(() => logoFile = processed);
    }
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

    if (mounted) {
      setState(() => backgroundFile = processed);
    }
  }

  Future<void> _pickDateCupertino() async {
    _unfocusKeyboard();
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(foundationDate ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      maximumDate: today, // дата основания не может быть в будущем
      initialDateTime: temp.isAfter(today) ? today : temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok && mounted) {
      setState(() {
        foundationDate = temp;
        _clearFieldError('foundationDate');
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

                  // ── панель с кнопками
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

                  // ── сам пикер
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

  /// Кнопка сохранения
  /// При загрузке: только индикатор (без текста), тёмный фон, блокировка нажатий.
  Widget _buildSaveButton(AppFormState formState) {
    final textColor = AppColors.getSurfaceColor(context);
    final isLoading = formState.isSubmitting;
    final isEnabled = isFormValid && !isLoading;

    // ────────────────────────────────────────────────────────────────
    // 💾 КНОПКА СОХРАНЕНИЯ (единый стиль с экраном добавления активности)
    // ────────────────────────────────────────────────────────────────
    final button = ElevatedButton(
      onPressed: isEnabled ? _submit : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: textColor,
        disabledBackgroundColor: AppColors.button,
        disabledForegroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        shape: const StadiumBorder(),
        minimumSize: const Size(double.infinity, 50),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.center,
      ),
      child: isLoading
          ? CupertinoActivityIndicator(radius: 9, color: textColor)
          : Text(
              'Создать сообщество',
              style: AppTextStyles.h15w5.copyWith(
                color: textColor,
                height: 1.0,
              ),
            ),
    );

    // Блокировка нажатий во время загрузки
    if (isLoading) {
      return IgnorePointer(child: button);
    }

    return button;
  }

  Future<void> _submit() async {
    final formNotifier = ref.read(formStateProvider.notifier);
    
    // ── проверяем все обязательные поля и подсвечиваем незаполненные
    final Map<String, String> newErrors = {};

    if (nameCtrl.text.trim().isEmpty) {
      newErrors['name'] = 'Введите название клуба';
    }
    if (_selectedCity == null || _selectedCity!.isEmpty) {
      newErrors['city'] = 'Выберите город из списка';
      // Очищаем поле, если город не выбран из списка
      cityCtrl.clear();
    } else if (!_cities.contains(_selectedCity)) {
      newErrors['city'] = 'Выберите город из списка';
      cityCtrl.clear();
      _selectedCity = null;
    }
    if (activity == null) {
      newErrors['activity'] = 'Выберите вид активности';
    }
    if (foundationDate == null) {
      newErrors['foundationDate'] = 'Выберите дату основания';
    }

    // ── если есть ошибки — не отправляем форму
    if (newErrors.isNotEmpty) {
      formNotifier.setFieldErrors(newErrors);
      return;
    }

    // ── форма валидна — отправляем на сервер
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

      // Добавляем фоновую картинку
      if (backgroundFile != null) {
        files['background'] = backgroundFile!;
      }

        // Добавляем поля формы
        final userId = await authService.getUserId();
        if (userId == null) {
          throw Exception('Ошибка авторизации. Необходимо войти в систему');
        }
      fields['user_id'] = userId.toString();
      fields['name'] = nameCtrl.text.trim();
      // ── собираем ссылки: первая — link, остальные — extra_links (JSON)
      final links = _linkControllers
          .map((ctrl) => ctrl.text.trim())
          .where((link) => link.isNotEmpty)
          .toList();
      if (links.isNotEmpty) {
        fields['link'] = links.first;
        if (links.length > 1) {
          fields['extra_links'] = jsonEncode(links.sublist(1));
        }
      }
      fields['city'] = cityCtrl.text.trim();
      fields['description'] = descCtrl.text.trim();
      fields['activity'] = activity!;
      fields['is_open'] = isOpenCommunity ? '1' : '0';
      fields['foundation_date'] = _fmtDate(foundationDate!);
      // Координаты не обязательны - будут получены по городу на сервере

        // Отправляем запрос
        Map<String, dynamic> data;
        if (files.isEmpty) {
          // JSON запрос без файлов
          data = await api.post('/create_club.php', body: fields);
        } else {
          // Multipart запрос с файлами
          data = await api.postMultipart(
            '/create_club.php',
            files: files,
            fields: fields,
            timeout: const Duration(seconds: 60),
          );
        }

        // Проверяем ответ
        if (data['success'] != true) {
          final errorMessage = data['message'] ?? 'Ошибка при создании клуба';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () {
        if (!mounted) return;
        // Закрываем экран создания клуба и возвращаемся на карту с результатом
        Navigator.of(context).pop('created');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(formStateProvider);

    return InteractiveBackSwipe(
      enabled: false,
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'Создание клуба',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: GestureDetector(
          // ── скрываем клавиатуру при нажатии на пустую область экрана
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                          const Text(
                            'Логотип клуба',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MediaTile(
                            file: logoFile,
                            onPick: _pickLogo,
                            onRemove: () => setState(() => logoFile = null),
                            width: 90,
                            height: 90,
                            isCircular: true,
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Фоновая картинка',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _MediaTile(
                              file: backgroundFile,
                              onPick: _pickBackground,
                              onRemove: () =>
                                  setState(() => backgroundFile = null),
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

                  // ---------- Название клуба ----------
                  const Text(
                    'Название клуба',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: TextField(
                      controller: nameCtrl,
                      style: AppTextStyles.h14w4,
                      decoration: InputDecoration(
                        hintText: 'Введите название клуба',
                        hintStyle: AppTextStyles.h14w4Place,
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 22,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        errorText: formState.fieldErrors.containsKey('name')
                            ? formState.fieldErrors['name']
                            : null,
                        errorMaxLines: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Страница клуба ----------
                  const Text(
                    'Страница клуба',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── динамические поля для ввода страниц клуба
                  Column(
                    children: List.generate(
                      _linkControllers.length.clamp(0, 3),
                      (index) {
                        return Column(
                          children: [
                            if (index > 0) const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                  color: AppColors.twinchip,
                                  width: 0.7,
                                ),
                              ),
                              child: TextField(
                                controller: _linkControllers[index],
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                style: AppTextStyles.h14w4,
                                decoration: InputDecoration(
                                  hintText: 'https://example.com/club',
                                  hintStyle: AppTextStyles.h14w4Place,
                                  filled: true,
                                  fillColor: AppColors.getSurfaceColor(context),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 22,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ).expand((widget) => [widget]).toList(),
                  ),
                  // ── кнопка "добавить ещё" (показываем только если меньше 3 полей)
                  if (_linkControllers.length < 3) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _addLinkField,
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
                  ],
                  const SizedBox(height: 24),

                  // ---------- Вид активности ----------
                  const Text(
                    'Вид активности',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        errorText: formState.fieldErrors.containsKey('activity')
                            ? formState.fieldErrors['activity']
                            : null,
                        errorMaxLines: 2,
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
                              setState(() {
                                activity = newValue;
                                _clearFieldError('activity');
                              });
                            }
                          },
                          dropdownColor: AppColors.getSurfaceColor(context),
                          menuMaxHeight: 300,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                          style: AppTextStyles.h14w4,
                          items: const ['Бег', 'Велосипед', 'Плавание', 'Лыжи'].map((
                            option,
                          ) {
                            return DropdownMenuItem<String>(
                              value: option,
                              child: Text(
                                option,
                                style: AppTextStyles.h14w4,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Радиокнопки: Открытое/Закрытое сообщество ----------
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: true,
                          // ignore: deprecated_member_use
                          groupValue: isOpenCommunity,
                          // ignore: deprecated_member_use
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Открытое сообщество',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Radio<bool>(
                          value: false,
                          // ignore: deprecated_member_use
                          groupValue: isOpenCommunity,
                          // ignore: deprecated_member_use
                          onChanged: (v) =>
                              setState(() => isOpenCommunity = v ?? false),
                          activeColor: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Закрытое сообщество',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ---------- Город ----------
                  const Text(
                    'Город',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CityAutocompleteField(
                    controller: cityCtrl,
                    suggestions: _cities,
                    hasError: formState.fieldErrors.containsKey('city'),
                    errorText: formState.fieldErrors['city'],
                    onSelected: (city) {
                      setState(() {
                        _selectedCity = city;
                        cityCtrl.text = city;
                      });
                      _clearFieldError('city');
                    },
                  ),
                  const SizedBox(height: 24),

                  // ---------- Дата основания клуба ----------
                  const Text(
                    'Дата основания клуба',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: _pickDateCupertino,
                      child: AbsorbPointer(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.getSurfaceColor(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 22,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 6,
                              ),
                              child: Icon(
                                CupertinoIcons.calendar,
                                size: 18,
                                color: AppColors.getIconPrimaryColor(context),
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 18 + 14,
                              minHeight: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            errorText: formState.fieldErrors.containsKey('foundationDate')
                                ? formState.fieldErrors['foundationDate']
                                : null,
                            errorMaxLines: 2,
                          ),
                          child: Text(
                            foundationDate != null
                                ? _fmtDate(foundationDate!)
                                : 'Выберите дату',
                            style: foundationDate != null
                                ? AppTextStyles.h14w4
                                : AppTextStyles.h14w4Place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Описание ----------
                  const Text(
                    'Описание',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.twinchip,
                        width: 0.7,
                      ),
                    ),
                    child: TextField(
                      controller: descCtrl,
                      maxLines: 12,
                      minLines: 8,
                      textAlignVertical: TextAlignVertical.top,
                      style: AppTextStyles.h14w4.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Введите описание клуба',
                        hintStyle: AppTextStyles.h14w4Place.copyWith(
                          color: AppColors.getTextPlaceholderColor(context),
                        ),
                        filled: true,
                        fillColor: AppColors.getSurfaceColor(context),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Показываем ошибки, если есть
                  if (formState.hasErrors) ...[
                    FormErrorDisplay(formState: formState),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 8),

                  // ────────────────────────────────────────────────────────────────
                  // 💾 КНОПКА СОХРАНЕНИЯ
                  // ────────────────────────────────────────────────────────────────
                  Center(
                    child: _buildSaveButton(formState),
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
// --------------------------- ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ ---------------------------
//

// ── автокомплит для города
class _CityAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSelected;
  final bool hasError;
  final String? errorText;

  const _CityAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSelected,
    this.hasError = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<String>.empty();
          }
          final query = textEditingValue.text.toLowerCase();
          return suggestions.where((city) {
            return city.toLowerCase().startsWith(query);
          });
        },
        onSelected: onSelected,
        fieldViewBuilder:
            (
              BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted,
            ) {
              // Инициализируем текст из внешнего контроллера
              if (textEditingController.text.isEmpty &&
                  controller.text.isNotEmpty) {
                textEditingController.text = controller.text;
              }

              // Синхронизируем изменения в Autocomplete контроллере с внешним
              textEditingController.addListener(() {
                if (textEditingController.text != controller.text) {
                  controller.text = textEditingController.text;
                }
              });

              return TextField(
                controller: textEditingController,
                focusNode: focusNode,
                onSubmitted: (String value) {
                  onFieldSubmitted();
                },
                style: AppTextStyles.h14w4,
                decoration: InputDecoration(
                  hintText: 'Введите город',
                  hintStyle: AppTextStyles.h14w4Place,
                  filled: true,
                  fillColor: AppColors.getSurfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 22,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  errorText: hasError
                      ? (errorText ?? 'Выберите город из списка')
                      : null,
                  errorMaxLines: 2,
                ),
              );
            },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                color: AppColors.getSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          onSelected(option);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.h14w4.copyWith(
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
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
  final bool isCircular;

  const _MediaTile({
    required this.file,
    required this.onPick,
    required this.onRemove,
    required this.width,
    required this.height,
    this.isCircular = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── если фото ещё нет — плитка с иконкой и рамкой
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircular
                ? null
                : BorderRadius.circular(AppRadius.lg),
            color: AppColors.twinphoto,
            border: Border.all(
              color: AppColors.twinchip,
              width: 0.7,
            ),
          ),
          child: const Center(
            child: Icon(
              CupertinoIcons.camera_fill,
              size: 24,
              color: AppColors.scrim20,
            ),
          ),
        ),
      );
    }

    // ── если фото выбрано — превью без рамки
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircular
                  ? null
                  : BorderRadius.circular(AppRadius.lg),
              color: AppColors.getBackgroundColor(context),
            ),
            clipBehavior: Clip.antiAlias,
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
          child: GestureDetector(
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
      ],
    );
  }
}
