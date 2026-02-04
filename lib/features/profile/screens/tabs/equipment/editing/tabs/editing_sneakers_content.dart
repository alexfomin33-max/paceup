import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../../providers/services/auth_provider.dart';
import '../../../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../../../core/widgets/form_error_display.dart';

/// Экран редактирования кроссовок
class EditingSneakersContent extends ConsumerStatefulWidget {
  final int equipUserId; // ID записи в equip_user

  const EditingSneakersContent({super.key, required this.equipUserId});

  @override
  ConsumerState<EditingSneakersContent> createState() =>
      _EditingSneakersContentState();
}

class _EditingSneakersContentState extends ConsumerState<EditingSneakersContent> {
  // ─────────────────────────────────────────────────────────────────────
  //                             КОНТРОЛЛЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  DateTime _inUseFrom = DateTime.now();
  File? _imageFile;
  String? _currentImageUrl; // URL текущего изображения из базы
  final _picker = ImagePicker();
  final _pickerFocusNode = FocusNode(debugLabel: 'sneakersEditPickerFocus');

  // ── Локальное состояние загрузки данных (отдельно от formStateProvider,
  //    чтобы избежать мерцания при переходе между экранами)
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    // ── Сбрасываем состояние формы при инициализации, чтобы избежать
    //    отображения старого состояния из предыдущего экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(formStateProvider.notifier).reset();
        _loadEquipmentData();
      }
    });
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Загрузка данных снаряжения для редактирования
  Future<void> _loadEquipmentData() async {
    if (!mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();

      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment_item.php',
        body: {
          'user_id': userId.toString(),
          'equip_user_id': widget.equipUserId.toString(),
        },
      );

      if (!mounted) return;

      if (data['success'] == true) {
        setState(() {
          _isLoadingData = false;
          _brandCtrl.text = data['brand'] ?? '';
          _modelCtrl.text = data['name'] ?? '';
          _kmCtrl.text = data['dist']?.toString() ?? '0';
          _currentImageUrl = data['image'] as String?;
          // Загружаем дату из базы
          final inUseSinceStr = data['in_use_since'] as String?;
          if (inUseSinceStr != null && inUseSinceStr.isNotEmpty) {
            try {
              _inUseFrom = DateTime.parse(inUseSinceStr);
            } catch (e) {
              // Если не удалось распарсить, оставляем текущую дату
              _inUseFrom = DateTime.now();
            }
          }
        });
      } else {
        throw Exception(data['message'] ?? 'Ошибка при загрузке данных');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.formatWithContext(error, context: 'загрузке данных'),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ИЗОБРАЖЕНИЯ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // ── уменьшаем изображение кроссовок перед сохранением
    final compressed = await compressLocalImage(
      sourceFile: File(picked.path),
      maxSide: ImageCompressionPreset.equipmentView.maxSide,
      jpegQuality: ImageCompressionPreset.equipmentView.quality,
    );
    if (!mounted) return;

    setState(() {
      _imageFile = compressed;
      // При выборе нового изображения скрываем старое
      _currentImageUrl = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ОТПРАВКА ДАННЫХ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _saveEquipment() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // Валидация
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
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
          'equip_user_id': widget.equipUserId.toString(),
          'name': model,
          'brand': brand,
          'dist': km.toString(),
          'in_use_since': _formatDateForApi(
            _inUseFrom,
          ), // Дата в формате DD.MM.YYYY
        };

        // Добавляем изображение, если выбрано новое
        if (_imageFile != null) {
          files['image'] = _imageFile!;
        }

        // Отправляем запрос
        Map<String, dynamic> data;
        if (files.isEmpty) {
          // JSON запрос без файлов
          data = await api.post('/update_equipment.php', body: fields);
        } else {
          // Multipart запрос с файлами
          data = await api.postMultipart(
            '/update_equipment.php',
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
      onSuccess: () {
        if (!mounted) return;
        // Закрываем экран после успешного сохранения
        Navigator.of(
          context,
        ).pop(true); // Возвращаем true для обновления списка
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
    DateTime selectedDate = _inUseFrom;

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
                  initialDateTime: _inUseFrom,
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
  String get _dateLabel {
    final d = _inUseFrom;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd.$mm.$yy';
  }

  /// Форматирует дату для отправки в API (DD.MM.YYYY)
  String _formatDateForApi(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  // ─────────────────────────────────────────────────────────────────────
  //                                 UI
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    final formState = ref.watch(formStateProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getSurfaceColor(context),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.getSurfaceColor(context),
          leadingWidth: 52,
          leading: IconButton(
            tooltip: 'Назад',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              CupertinoIcons.back,
              size: 22,
              color: AppColors.iconPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: _isLoadingData
              ? const Center(child: CupertinoActivityIndicator(radius: 16))
              : GestureDetector(
                  // ── снимаем фокус с текстовых полей при клике вне их
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      // ───────────────────────── Большая картинка кроссовок ─────────────────────────
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
                                              'assets/add_boots.png',
                                              width: 220,
                                              fit: BoxFit.contain,
                                            );
                                          },
                                        ),
                                      )
                                    : _currentImageUrl != null
                                        ? Builder(
                                            builder: (context) {
                                              // ────────────────────────────────────────────────────────────────
                                              // 🖼️ ОПТИМИЗАЦИЯ КАЧЕСТВА: используем CachedNetworkImage с учетом DPR
                                              // ────────────────────────────────────────────────────────────────
                                              final dpr = MediaQuery.of(
                                                context,
                                              ).devicePixelRatio;
                                              final cacheWidth = (320 * dpr).round();
                                              return ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                  maxWidth: 320,
                                                ),
                                                child: CachedNetworkImage(
                                                  imageUrl: _currentImageUrl!,
                                                  fit: BoxFit.contain,
                                                  memCacheWidth: cacheWidth,
                                                  maxWidthDiskCache: cacheWidth,
                                                  filterQuality: FilterQuality.high,
                                                  placeholder: (context, url) => Container(
                                                    color: AppColors.getBackgroundColor(context),
                                                    child: Center(
                                                      child: CupertinoActivityIndicator(
                                                        radius: 10,
                                                        color: AppColors.getIconSecondaryColor(context),
                                                      ),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) {
                                                    return Opacity(
                                                      opacity: 0.5,
                                                      child: Image.asset(
                                                        'assets/add_boots.png',
                                                        width: 220,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          )
                                        : Opacity(
                                            opacity: 0.5,
                                            child: Image.asset(
                                              'assets/add_boots.png',
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
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceColor(context),
                                 
                                ),
                                child: Column(
                                  children: [
                                    _FieldRow(
                                      title: 'Бренд',
                                      child: _RightTextField(
                                        controller: _brandCtrl,
                                        hint: 'Введите бренд',
                                        readOnly: true,
                                      ),
                                    ),
                                    _FieldRow(
                                      title: 'Модель',
                                      child: _RightTextField(
                                        controller: _modelCtrl,
                                        hint: 'Введите модель',
                                        readOnly: true,
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
                                            _dateLabel,
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

                              // ───────────────────────── Предупреждение ─────────────────────────
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.orangeBg,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: AppColors.orangeBr,
                                    width: 0.7,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.info,
                                      size: 20,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Редактировать можно только фото, дату начала использования и пробег',
                                        style: AppTextStyles.h14w4.copyWith(
                                          color: AppColors.getTextSecondaryColor(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

                      // ─────────────────── Кнопка «Сохранить» ───────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _brandCtrl,
                          builder: (context, brandValue, child) {
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _modelCtrl,
                              builder: (context, modelValue, child) {
                                final isButtonEnabled = brandValue.text.trim().isNotEmpty &&
                                    modelValue.text.trim().isNotEmpty &&
                                    !formState.isSubmitting;
                                return Opacity(
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
                                            'Сохранить',
                                            style: AppTextStyles.h15w5.copyWith(
                                              color: textColor,
                                              height: 1.0,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            );
                          },
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
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onChanged;
  const _RightTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.enabled = true,
    this.readOnly = false,
    this.onChanged,
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
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged != null ? (_) => widget.onChanged!() : null,
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
