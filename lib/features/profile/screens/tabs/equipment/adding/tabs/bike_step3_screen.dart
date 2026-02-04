// lib/features/profile/screens/tabs/equipment/adding/tabs/bike_step3_screen.dart
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../../providers/services/auth_provider.dart';
import '../../../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../../../core/widgets/form_error_display.dart';
import '../../viewing/viewing_equipment_screen.dart';

/// Экран «Сохранить велосипед» — третий шаг добавления велосипеда
class BikeStep3Screen extends ConsumerStatefulWidget {
  /// Выбранный бренд велосипеда
  final String brand;
  /// Выбранная модель велосипеда
  final String model;

  const BikeStep3Screen({
    super.key,
    required this.brand,
    required this.model,
  });

  @override
  ConsumerState<BikeStep3Screen> createState() => _BikeStep3ScreenState();
}

class _BikeStep3ScreenState extends ConsumerState<BikeStep3Screen> {
  // ─────────────────────────────────────────────────────────────────────
  //                             КОНТРОЛЛЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  final _kmCtrl = TextEditingController();
  DateTime? _inUseFrom;
  File? _imageFile;
  final _picker = ImagePicker();
  final _pickerFocusNode = FocusNode(debugLabel: 'bikeStep3PickerFocus');

  @override
  void initState() {
    super.initState();
    // ── Инициализируем контроллер пробега значением по умолчанию
    _kmCtrl.text = '0';
    // ── Сбрасываем состояние формы при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(formStateProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ИЗОБРАЖЕНИЯ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // ── уменьшаем изображение велосипеда перед сохранением
    final compressed = await compressLocalImage(
      sourceFile: File(picked.path),
      maxSide: ImageCompressionPreset.equipmentView.maxSide,
      jpegQuality: ImageCompressionPreset.equipmentView.quality,
    );
    if (!mounted) return;

    setState(() {
      _imageFile = compressed;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ОТПРАВКА ДАННЫХ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _saveEquipment() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // Валидация
    final brand = widget.brand.trim();
    final model = widget.model.trim();
    final kmStr = _kmCtrl.text.trim();

    if (brand.isEmpty) {
      ref.read(formStateProvider.notifier).setError('Введите бренд');
      return;
    }

    if (model.isEmpty) {
      ref.read(formStateProvider.notifier).setError('Введите модель');
      return;
    }

    // Дистанция необязательна, по умолчанию 0
    int km = 0;
    if (kmStr.isNotEmpty) {
      final parsedKm = int.tryParse(kmStr);
      if (parsedKm == null || parsedKm < 0) {
        ref.read(formStateProvider.notifier).setError('Некорректная дистанция');
        return;
      }
      km = parsedKm;
    }

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);
    final authService = ref.read(authServiceProvider);

    await formNotifier.submit(
      () async {
        final userId = await authService.getUserId();

        if (userId == null) {
          throw Exception('Пользователь не авторизован');
        }

        // Формируем данные
        final files = <String, File>{};
        final fields = <String, String>{
          'user_id': userId.toString(),
          'name': model,
          'brand': brand,
          'dist': km.toString(),
          'in_use_since': _formatDateForApi(
            _inUseFrom,
          ), // Дата в формате DD.MM.YYYY
          'type': 'bikes', // Тип снаряжения: велосипед
        };

        // Добавляем изображение, если выбрано
        if (_imageFile != null) {
          files['image'] = _imageFile!;
        }

        // Отправляем запрос
        Map<String, dynamic> data;
        if (files.isEmpty) {
          // JSON запрос без файлов
          data = await api.post('/add_equipment.php', body: fields);
        } else {
          // Multipart запрос с файлами
          data = await api.postMultipart(
            '/add_equipment.php',
            files: files,
            fields: fields,
            timeout: const Duration(seconds: 60),
          );
        }

        // Проверяем ответ
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Ошибка при сохранении');
        }
      },
      onSuccess: () async {
        if (!mounted) return;
        // Получаем userId для перехода на экран просмотра
        final userId = await authService.getUserId();
        if (userId == null || !mounted) return;
        
        // Закрываем все экраны добавления
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // Переходим на экран просмотра велосипедов
        if (mounted) {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(
              builder: (_) => ViewingEquipmentScreen(
                initialSegment: 1, // Велосипеды
                userId: userId,
              ),
            ),
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
                    context: 'сохранении снаряжения',
                  ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ДАТЫ (iOS)
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    _unfocusKeyboard();
    DateTime selectedDate = _inUseFrom ?? DateTime.now();

    await showCupertinoModalPopup(
      context: context,
      builder: (popupContext) {
        return Container(
          height: 280,
          color: AppColors.getSurfaceColor(context),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () => Navigator.pop(popupContext),
                      child: const Text('Отменить'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      onPressed: () {
                        if (mounted) {
                          setState(() => _inUseFrom = selectedDate);
                        }
                        Navigator.pop(popupContext);
                      },
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.getDividerColor(context),
                indent: 12,
                endIndent: 12,
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedDate,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) {
                    selectedDate = d;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ФОРМАТТЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  String? get _dateLabel {
    if (_inUseFrom == null) return null;
    final d = _inUseFrom!;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  /// Форматирует дату для отправки в API (DD.MM.YYYY)
  String _formatDateForApi(DateTime? date) {
    final d = date ?? DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  // ─────────────────────────────────────────────────────────────────────
  //                                 UI
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    final formState = ref.watch(formStateProvider);
    final isButtonEnabled = _inUseFrom != null && !formState.isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceColor(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.getSurfaceColor(context),
        leadingWidth: 52,
        leading: IconButton(
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(
            CupertinoIcons.back,
            size: 22,
            color: AppColors.getIconPrimaryColor(context),
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          // ── снимаем фокус с текстовых полей при клике вне их
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              // ───────────────────────── Большая картинка велосипеда ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ── Показываем картинку по умолчанию или выбранную
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: _imageFile != null
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.asset(
                                      'assets/add_bike.png',
                                      width: 220,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                              )
                            : Opacity(
                                opacity: 0.5,
                                child: Image.asset(
                                  'assets/add_bike.png',
                                  width: 220,
                                  fit: BoxFit.contain,
                                ),
                              ),
                      ),
                    ),
                    // кнопка «добавить фото» — в центре картинки
                    Opacity(
                      opacity: 0.5,
                      child: Material(
                        color: AppColors.getTextPrimaryColor(context),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _pickImage,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 24,
                              color: AppColors.getSurfaceColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ───────────────────────── Карточка с полями ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
              
                    ),
                    child: Column(
                      children: [
                        _FieldRow(
                          title: 'Бренд',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              widget.brand,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.getTextPrimaryColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        _FieldRow(
                          title: 'Модель',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              widget.model,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: AppColors.getTextPrimaryColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        _FieldRow(
                          title: 'В использовании с',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _pickDate,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                _dateLabel ?? 'выберите дату',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: _dateLabel != null
                                      ? AppColors.getTextPrimaryColor(context)
                                      : AppColors.getTextPlaceholderColor(context),
                                  fontWeight: _dateLabel != null
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _FieldRow(
                          title: 'Пробег, км',
                          child: _RightTextField(
                            controller: _kmCtrl,
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─────────────────── Отображение ошибок ───────────────────
              Builder(
                builder: (context) {
                  final formState = ref.watch(formStateProvider);
                  if (formState.hasErrors) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FormErrorDisplay(formState: formState),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // ─────────────────── Кнопка «Сохранить велосипед» ───────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Opacity(
                  opacity: isButtonEnabled ? 1.0 : 0.4,
                  child: ElevatedButton(
                    onPressed: isButtonEnabled ? _saveEquipment : null,
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
                    child: formState.isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CupertinoActivityIndicator(
                              radius: 9,
                            ),
                          )
                        : Text(
                            'Сохранить велосипед',
                            style: AppTextStyles.h15w5.copyWith(
                              color: textColor,
                              height: 1.0,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────────────────── Левая метка + правый виджет ─────────────────────
class _FieldRow extends StatelessWidget {
  final String title;
  final Widget child;
  const _FieldRow({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextPrimaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: child),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────── Правый «плоский» TextField без рамки ─────────────────────
class _RightTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _RightTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  State<_RightTextField> createState() => _RightTextFieldState();
}

class _RightTextFieldState extends State<_RightTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      textAlign: TextAlign.right,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hint,
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.getTextPlaceholderColor(context),
          fontWeight: FontWeight.w400,
        ),
      ),
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: AppColors.getTextPrimaryColor(context),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
