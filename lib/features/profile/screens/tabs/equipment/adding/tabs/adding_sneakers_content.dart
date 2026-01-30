import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../providers/services/auth_provider.dart';
import '../../../../../../../core/providers/form_state_provider.dart';
import '../../../../../../../core/widgets/form_error_display.dart';
import '../widgets/autocomplete_text_field.dart';

/// Контент для сегмента «Кроссовки»
class AddingSneakersContent extends ConsumerStatefulWidget {
  const AddingSneakersContent({super.key});

  @override
  ConsumerState<AddingSneakersContent> createState() =>
      _AddingSneakersContentState();
}

class _AddingSneakersContentState extends ConsumerState<AddingSneakersContent> {
  // ─────────────────────────────────────────────────────────────────────
  //                             КОНТРОЛЛЕРЫ
  // ─────────────────────────────────────────────────────────────────────
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  DateTime? _inUseFrom;
  File? _imageFile;
  final _picker = ImagePicker();
  final _pickerFocusNode = FocusNode(debugLabel: 'sneakersPickerFocus');

  // FocusNode для полей
  // ВАЖНО: FocusNode управляются дочерними виджетами (AutocompleteTextField и _RightTextFieldState),
  // поэтому НЕ нужно их dispose здесь, чтобы избежать ошибки "FocusNode was used after being disposed"
  FocusNode? _brandFocusNode;
  FocusNode? _modelFocusNode;
  FocusNode? _kmFocusNode;

  // Для автодополнения - используем провайдер

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _kmCtrl.dispose();
    _pickerFocusNode.dispose();
    // НЕ dispose FocusNode здесь - они управляются дочерними виджетами
    // _brandFocusNode, _modelFocusNode и _kmFocusNode будут автоматически
    // disposed когда их соответствующие виджеты будут disposed
    super.dispose();
  }

  // ── снимаем фокус перед показом пикера, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ПОИСК БРЕНДОВ
  // ─────────────────────────────────────────────────────────────────────
  Future<List<String>> _searchBrands(String query) async {
    if (query.isEmpty) {
      return [];
    }

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/search_equipment_brands.php',
        body: {'query': query, 'type': 'boots'},
      );

      if (data['success'] == true) {
        return (data['brands'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    } catch (e) {
      // Игнорируем ошибки при поиске
    }

    return [];
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ПОИСК МОДЕЛЕЙ
  // ─────────────────────────────────────────────────────────────────────
  Future<List<String>> _searchModels(String query) async {
    final brand = _brandCtrl.text.trim();
    if (brand.isEmpty || query.isEmpty) {
      return [];
    }

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/search_equipment_models.php',
        body: {'brand': brand, 'query': query, 'type': 'boots'},
      );

      if (data['success'] == true) {
        return (data['models'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    } catch (e) {
      // Игнорируем ошибки при поиске
    }

    return [];
  }

  // ─────────────────────────────────────────────────────────────────────
  //                           ВЫБОР ИЗОБРАЖЕНИЯ
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // ── сжимаем фото кроссовок перед отправкой в API
    final compressed = await compressLocalImage(
      sourceFile: File(picked.path),
      maxSide: ImageCompressionPreset.equipmentView.maxSide,
      jpegQuality: ImageCompressionPreset.equipmentView.quality,
    );
    if (!mounted) return;

    setState(() => _imageFile = compressed);
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

        // ── Проверяем наличие основного снаряжения данного типа
        // Если основного снаряжения нет, новое станет основным
        bool hasMainEquipment = false;
        try {
          final equipmentData = await api.post(
            '/get_equipment.php',
            body: {'user_id': userId.toString()},
          );
          if (equipmentData['success'] == true) {
            final bootsList = equipmentData['boots'] as List<dynamic>? ?? [];
            // Проверяем, есть ли хотя бы одно основное снаряжение (main == 1)
            hasMainEquipment = bootsList.any(
              (item) => (item['main'] as int? ?? 0) == 1,
            );
          }
        } catch (e) {
          // Если не удалось проверить, считаем что основное есть (безопасный вариант)
          hasMainEquipment = true;
        }

        // Формируем данные
        final files = <String, File>{};
        final fields = <String, String>{
          'user_id': userId.toString(),
          'type': 'boots',
          'name': model,
          'brand': brand,
          'dist': km.toString(),
          'main': hasMainEquipment
              ? '0'
              : '1', // Основное, если нет основного снаряжения
          'in_use_since': _formatDateForApi(
            _inUseFrom ?? DateTime.now(),
          ), // Дата в формате DD.MM.YYYY
        };

        // Добавляем изображение, если есть
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
      onSuccess: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снаряжение успешно добавлено')),
        );
        // Закрываем экран после успешного сохранения
        Navigator.of(context).pop();
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
    // Переменная для хранения выбранной даты, объявлена вне builder
    // чтобы сохраняться между перестроениями
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
                        // Обновляем состояние только если виджет еще смонтирован
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

              // Сам пикер
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selectedDate,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (d) {
                    // Обновляем переменную, объявленную в области видимости _pickDate
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
    if (_inUseFrom == null) {
      return 'Выберите дату';
    }
    final d = _inUseFrom!;
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
    // ── снимаем фокус с текстовых полей при клике вне их
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // ────────────────────────────────────────────────────────────────
          // 📜 ПРОКРУЧИВАЕМАЯ ОБЛАСТЬ С КОНТЕНТОМ
          // ────────────────────────────────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
            child: Column(
              children: [
                // ───────────────────────── Карточка ─────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.getBorderColor(context),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // превью
                      SizedBox(
                        height: 170,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: Opacity(
                                opacity: 0.5,
                                child: Image.asset(
                                  'assets/add_boots.png',
                                  width: 150,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Отображение выбранного изображения или заглушки
                            if (_imageFile != null)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 240,
                                      maxHeight: 140,
                                    ),
                                    child: Image.file(
                                      _imageFile!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.error_outline,
                                            color: AppColors.getTextSecondaryColor(
                                              context,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            // кнопка «добавить фото» — снизу-справа
                            Positioned(
                              right: 70,
                              bottom: 18,
                              child: Material(
                                color: AppColors.getSurfaceColor(context),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Добавить фото',
                                  onPressed: _pickImage,
                                  icon: Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 28,
                                    color: AppColors.getTextSecondaryColor(context),
                                  ),
                                ),
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

                      // строки полей
                      _FieldRow(
                        title: 'Бренд',
                        onTap: () {
                          // Безопасный вызов requestFocus - FocusNode управляется дочерним виджетом
                          try {
                            _brandFocusNode?.requestFocus();
                          } catch (e) {
                            // Игнорируем ошибки, если FocusNode уже disposed
                          }
                        },
                        child: AutocompleteTextField(
                          controller: _brandCtrl,
                          hint: 'Введите бренд',
                          onSearch: _searchBrands,
                          onChanged: () {
                            // Очищаем модель при изменении бренда
                            setState(() {
                              _modelCtrl.clear();
                            });
                          },
                          onFocusNodeCreated: (node) {
                            _brandFocusNode = node;
                          },
                        ),
                      ),
                      _FieldRow(
                        title: 'Модель',
                        onTap: () {
                          // Безопасный вызов requestFocus - FocusNode управляется дочерним виджетом
                          try {
                            _modelFocusNode?.requestFocus();
                          } catch (e) {
                            // Игнорируем ошибки, если FocusNode уже disposed
                          }
                        },
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _brandCtrl,
                          builder: (context, brandValue, child) {
                            return AutocompleteTextField(
                              controller: _modelCtrl,
                              hint: 'Введите модель',
                              onSearch: _searchModels,
                              enabled: brandValue.text.trim().isNotEmpty,
                              onFocusNodeCreated: (node) {
                                _modelFocusNode = node;
                              },
                            );
                          },
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
                                color: _inUseFrom == null
                                    ? AppColors.getTextTertiaryColor(context)
                                    : AppColors.getTextPrimaryColor(context),
                                fontWeight: _inUseFrom == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _FieldRow(
                        title: 'Добавленная дистанция, км',
                        onTap: () {
                          // Безопасный вызов requestFocus - FocusNode управляется дочерним виджетом
                          try {
                            _kmFocusNode?.requestFocus();
                          } catch (e) {
                            // Игнорируем ошибки, если FocusNode уже disposed
                          }
                        },
                        child: _RightTextField(
                          controller: _kmCtrl,
                          hint: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                          ),
                          onFocusNodeCreated: (node) {
                            _kmFocusNode = node;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

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

                // Добавляем нижний отступ для контента перед плавающей кнопкой
                const SizedBox(height: 20),
              ],
            ),
          ),
          // ───────── Плавающая кнопка добавления (стеклянный эффект)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _buildAddButton(),
            ),
          ),
        ],
      ),
    );
  }

  /// Кнопка добавления
  Widget _buildAddButton() {
    final formState = ref.watch(formStateProvider);
    final textColor = AppColors.getSurfaceColor(context);
    final isLoading = formState.isSubmitting;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _brandCtrl,
      builder: (context, brandValue, child) {
        final isEnabled =
            brandValue.text.trim().isNotEmpty && !isLoading;

        // ─────────── Содержимое кнопки без эффекта стекла
        final button = ElevatedButton(
          onPressed: (isLoading || !isEnabled) ? null : _saveEquipment,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.button.withValues(alpha: 0.7);
                }
                return AppColors.button.withValues(alpha: 0.7);
              },
            ),
            foregroundColor: WidgetStateProperty.all(textColor),
            elevation: WidgetStateProperty.all(0),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 30),
            ),
            shape: WidgetStateProperty.all(
              StadiumBorder(
                side: BorderSide(
                  color: AppColors.button.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            minimumSize: WidgetStateProperty.all(
              const Size(double.infinity, 50),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            alignment: Alignment.center,
          ),
          child: isLoading
              ? CupertinoActivityIndicator(
                  radius: 9,
                  color: textColor,
                )
              : Text(
                  'Добавить',
                  style: AppTextStyles.h15w5.copyWith(
                    color: textColor,
                    height: 1.0,
                  ),
                ),
        );

        // ─────────── Стеклянная оболочка с блюром как в iOS
        final glassButton = ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadius.xxl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 8,
              sigmaY: 8,
            ),
            child: button,
          ),
        );

        // Блокировка нажатий во время загрузки
        if (isLoading || !isEnabled) {
          return IgnorePointer(child: glassButton);
        }

        return glassButton;
      },
    );
  }
}

/// ───────────────────── Левая метка + правый виджет ─────────────────────
class _FieldRow extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  const _FieldRow({required this.title, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 180, child: child),
                ],
              ),
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: AppColors.getDividerColor(context),
          indent: 12,
          endIndent: 12,
        ),
      ],
    );
  }
}

/// ───────────────────── Правый «плоский» TextField без рамки ─────────────────────
class _RightTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final void Function(FocusNode)? onFocusNodeCreated;
  const _RightTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.onFocusNodeCreated,
  });

  @override
  State<_RightTextField> createState() => _RightTextFieldState();
}

class _RightTextFieldState extends State<_RightTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.onFocusNodeCreated?.call(_focusNode);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final isEmpty = value.text.trim().isEmpty;
        return TextField(
          controller: widget.controller,
          focusNode: _focusNode,
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
            ),
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: isEmpty
                ? AppColors.getTextPlaceholderColor(context)
                : AppColors.getTextPrimaryColor(context),
            fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
          ),
        );
      },
    );
  }
}
