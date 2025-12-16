import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';
import '../../../models/market_models.dart' show Gender;

/// Контент вкладки «Продажа вещи»
class SaleThingsContent extends ConsumerStatefulWidget {
  const SaleThingsContent({super.key});

  @override
  ConsumerState<SaleThingsContent> createState() => _SaleThingsContentState();
}

class _SaleThingsContentState extends ConsumerState<SaleThingsContent> {
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  // ── контроллеры для полей ввода городов передачи
  final List<TextEditingController> _cityControllers = [];
  final descCtrl = TextEditingController();

  final List<String> _categories = const [
    'Кроссовки',
    'Часы',
    'Одежда',
    'Аксессуары',
  ];
  String? _category;

  /// null = Любой
  Gender? _gender;

  // ── список выбранных фотографий
  final List<File> _images = [];

  bool get _isValid =>
      titleCtrl.text.trim().isNotEmpty &&
      priceCtrl.text.trim().isNotEmpty &&
      _category != null;

  @override
  void initState() {
    super.initState();
    // ── создаём первое поле для ввода города передачи
    _cityControllers.add(TextEditingController());
    _cityControllers.last.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    priceCtrl.dispose();
    // ── освобождаем все контроллеры городов
    for (final controller in _cityControllers) {
      controller.dispose();
    }
    descCtrl.dispose();
    super.dispose();
  }

  // ── добавление нового поля для ввода города передачи
  void _addCityField() {
    setState(() {
      final newController = TextEditingController();
      newController.addListener(() => setState(() {}));
      _cityControllers.add(newController);
    });
  }

  /// Сохраняет объявление о продаже вещи на сервер
  Future<void> _submit() async {
    if (!_isValid) return;

    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    final authService = AuthService();
    final userId = await authService.getUserId();
    if (userId == null) {
      _showError('Не удалось получить ID пользователя');
      return;
    }

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        // ── собираем города передачи из контроллеров
        final cities = _cityControllers
            .map((ctrl) => ctrl.text.trim())
            .where((city) => city.isNotEmpty)
            .toList();

        // ── проверяем наличие категории
        if (_category == null) {
          throw Exception('Необходимо выбрать категорию товара');
        }

        // ── формируем данные для отправки
        final fields = <String, String>{
          'user_id': userId.toString(),
          'title': titleCtrl.text.trim(),
          'category': _category!,
          'price': priceCtrl.text.replaceAll(
            ' ',
            '',
          ), // ── удаляем пробелы из цены
          'description': descCtrl.text.trim(),
        };

        // ── добавляем пол (если указан)
        if (_gender != null) {
          fields['gender'] = _gender == Gender.male ? 'male' : 'female';
        }

        // ── добавляем города передачи (JSON массив)
        if (cities.isNotEmpty) {
          fields['cities'] = cities
              .toString(); // Будет передан как массив в multipart
        }

        Map<String, dynamic> data;

        if (_images.isEmpty) {
          // ── JSON-запрос (без файлов)
          // Для JSON нужно передать cities как JSON строку
          final jsonBody = <String, dynamic>{
            'user_id': userId.toString(),
            'title': titleCtrl.text.trim(),
            'category': _category!,
            'price': int.tryParse(priceCtrl.text.replaceAll(' ', '')) ?? 0,
            'description': descCtrl.text.trim(),
          };
          if (_gender != null) {
            jsonBody['gender'] = _gender == Gender.male ? 'male' : 'female';
          }
          if (cities.isNotEmpty) {
            jsonBody['cities'] = cities;
          }

          data = await api.post('/create_thing.php', body: jsonBody);
        } else {
          // ── Multipart-запрос (с файлами)
          final files = <String, File>{};
          for (int i = 0; i < _images.length; i++) {
            files['images[$i]'] = _images[i];
          }

          // ── для multipart cities передаем как JSON строку (PHP декодирует)
          if (cities.isNotEmpty) {
            // ── передаем как JSON строку, PHP декодирует в create_thing.php
            fields['cities'] = jsonEncode(cities);
          }

          data = await api.postMultipart(
            '/create_thing.php',
            files: files,
            fields: fields,
            timeout: const Duration(seconds: 60),
          );
        }

        // ── проверяем ответ API
        if (data['success'] != true) {
          final errorMessage = data['message']?.toString() ?? 'Ошибка сервера';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () async {
        // ── очищаем форму
        titleCtrl.clear();
        priceCtrl.clear();
        descCtrl.clear();
        for (final controller in _cityControllers) {
          controller.clear();
        }
        setState(() {
          _images.clear();
          _category = null;
          _gender = null;
        });

        if (!mounted) return;
        Navigator.pop(context, true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при создании объявления');
      },
    );
  }

  /// Обработчик добавления фотографий
  Future<void> _handleAddPhotos() async {
    final picker = ImagePicker();

    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      // ── подготавливаем сжатые версии всех выбранных фотографий
      final compressedFiles = <File>[];
      for (final file in pickedFiles) {
        final compressed = await compressLocalImage(
          sourceFile: File(file.path),
          maxSide: ImageCompressionPreset.post.maxSide,
          jpegQuality: ImageCompressionPreset.post.quality,
        );
        compressedFiles.add(compressed);
      }

      if (!mounted) return;
      setState(() {
        _images.addAll(compressedFiles);
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  /// Обработчик удаления фотографии
  void _handleDeletePhoto(File file) {
    setState(() {
      _images.remove(file);
    });
  }

  /// Показывает ошибку
  void _showError(dynamic error) {
    final message = ErrorHandler.format(error);
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ошибка'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText.rich(
            TextSpan(
              text: message,
              style: const TextStyle(color: AppColors.error, fontSize: 15),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔻 умный нижний паддинг: клавиатура (viewInsets) > 0 ? берём её : берём safe-area
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom; // клавиатура
    final safeBottom = media.viewPadding.bottom; // «борода»/ноутч
    final bottomPad = (bottomInset > 0 ? bottomInset : safeBottom) + 20;

    // ── снимаем фокус с текстовых полей при клике вне их
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPad),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ────────────────────────────────────────────────────────────────
            // 📸 ФОТОГРАФИИ ВЕЩИ (горизонтальная карусель)
            // ────────────────────────────────────────────────────────────────
            Text(
              'Фотографии товара',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 2),
            _buildPhotoCarousel(),

            const SizedBox(height: 24),

            _LabeledTextField(
              label: 'Название товара',
              hint: 'Наименование продаваемого товара',
              controller: titleCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            _DropdownField(
              label: 'Категория',
              value: _category,
              items: _categories,
              hint: 'Выберите категорию товара',
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 20),

            const _SmallLabel('Пол'),
            const SizedBox(height: 8),
            _GenderAnyRow(
              value: _gender,
              onChanged: (g) =>
                  setState(() => _gender = g), // g может быть null (= Любой)
            ),
            const SizedBox(height: 20),

            _PriceField(
              controller: priceCtrl,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // ── динамические поля для ввода городов передачи (в два столбца)
            const _SmallLabel('Город передачи'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(_cityControllers.length, (index) {
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 24 - 12) / 2,
                  child: TextFormField(
                    controller: _cityControllers[index],
                    onChanged: (_) => setState(() {}),
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Населенный пункт',
                      hintStyle: AppTextStyles.h14w4Place.copyWith(
                        color: AppColors.getTextPlaceholderColor(context),
                      ),
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
                );
              }),
            ),
            const SizedBox(height: 12),
            // ── кнопка "добавить ещё"
            GestureDetector(
              onTap: _addCityField,
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
            const SizedBox(height: 20),

            _LabeledTextField(
              label: 'Описание',
              hint: 'Размер, отправка, передача и другая полезная информация',
              controller: descCtrl,
              minLines: 7, // ── минимальная высота поля 7 строк
              maxLines: 12,
            ),
            const SizedBox(height: 24),

            // ── показываем ошибки, если есть
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

            // ────────────────────────────────────────────────────────────────
            // 💾 КНОПКА РАЗМЕЩЕНИЯ
            // ────────────────────────────────────────────────────────────────
            Center(
              child: Builder(
                builder: (context) {
                  final formState = ref.watch(formStateProvider);
                  return PrimaryButton(
                    text: 'Разместить продажу',
                    onPressed: !formState.isSubmitting ? _submit : () {},
                    width: 220,
                    isLoading: formState.isSubmitting,
                    enabled: _isValid && !formState.isSubmitting,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Горизонтальная карусель фотографий
  Widget _buildPhotoCarousel() {
    // ── общее количество элементов: кнопка добавления + фотографии
    final totalItems = 1 + _images.length;

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: totalItems,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // ── первый элемент — кнопка добавления фото
          if (index == 0) {
            return _buildAddPhotoButton();
          }
          // ── остальные элементы — фотографии
          final photoIndex = index - 1;
          final file = _images[photoIndex];
          return _buildPhotoItem(file, photoIndex);
        },
      ),
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: _handleAddPhotos,
          child: Container(
            width: 90,
            height: 90,
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
      ),
    );
  }

  /// Элемент фотографии с кнопкой удаления
  Widget _buildPhotoItem(File file, int photoIndex) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                // ── по тапу можно заменить картинку
                final picker = ImagePicker();
                final XFile? pickedFile = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (pickedFile == null) return;

                // ── сжимаем выбранное фото перед заменой
                final compressed = await compressLocalImage(
                  sourceFile: File(pickedFile.path),
                  maxSide: ImageCompressionPreset.post.maxSide,
                  jpegQuality: ImageCompressionPreset.post.quality,
                );
                if (!mounted) return;

                setState(() {
                  _images[photoIndex] = compressed;
                });
              },
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: AppColors.getBackgroundColor(context),
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
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
            // ── кнопка удаления в правом верхнем углу
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () => _handleDeletePhoto(file),
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
          ],
        ),
      ),
    );
  }
}

/// ——— Локальные UI-компоненты ———

class _SmallLabel extends StatelessWidget {
  final String text;
  const _SmallLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          _SmallLabel(label),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.h14w4Place.copyWith(
              color: AppColors.getTextPlaceholderColor(context),
            ),
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
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String? hint;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label),
        const SizedBox(height: 8),
        InputDecorator(
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
              value: value,
              isExpanded: true,
              onChanged: onChanged,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: AppTextStyles.h14w4Place.copyWith(
                        color: AppColors.getTextPlaceholderColor(context),
                      ),
                    )
                  : null,
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
              items: items.map((o) {
                return DropdownMenuItem<String>(
                  value: o,
                  child: Text(o, style: AppTextStyles.h14w4),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Форматтер для форматирования цены с пробелами каждые 3 цифры
class _PriceInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // ── удаляем все нецифровые символы
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // ── форматируем число с пробелами каждые 3 цифры
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      final pos = digitsOnly.length - i;
      buffer.write(digitsOnly[i]);
      if (pos > 1 && pos % 3 == 1) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _PriceField({required this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Цена'),
        const SizedBox(height: 8),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 24 - 12) / 2,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [_PriceInputFormatter()],
            onChanged: onChanged,
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: AppTextStyles.h14w4Place.copyWith(
                color: AppColors.getTextPlaceholderColor(context),
              ),
              suffixText: '₽',
              suffixStyle: AppTextStyles.h14w4.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
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
      ],
    );
  }
}

class _GenderAnyRow extends StatelessWidget {
  final Gender? value; // null = Любой
  final ValueChanged<Gender?> onChanged;
  const _GenderAnyRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _OvalToggle(
          label: 'Любой',
          selected: value == null,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Мужской',
          selected: value == Gender.male,
          onTap: () => onChanged(Gender.male),
        ),
        const SizedBox(width: 8),
        _OvalToggle(
          label: 'Женский',
          selected: value == Gender.female,
          onTap: () => onChanged(Gender.female),
        ),
      ],
    );
  }
}

class _OvalToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _OvalToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    // Используем ту же логику, что и в alert_creation_screen.dart
    final fg = selected
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.surface
              : AppColors.getSurfaceColor(context))
        : AppColors.getTextPrimaryColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected
                ? AppColors.brandPrimary
                : AppColors.getBorderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }
}
