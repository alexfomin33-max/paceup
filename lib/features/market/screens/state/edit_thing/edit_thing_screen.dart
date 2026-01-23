import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../core/utils/image_picker_helper.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';
import '../../../../leaderboard/widgets/city_autocomplete_field.dart';
import '../../../models/market_models.dart' show Gender;

/// Экран редактирования объявления о продаже вещи
class EditThingScreen extends ConsumerStatefulWidget {
  final int thingId;

  const EditThingScreen({super.key, required this.thingId});

  @override
  ConsumerState<EditThingScreen> createState() => _EditThingScreenState();
}

class _EditThingScreenState extends ConsumerState<EditThingScreen> {
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  // ── контроллеры для полей ввода городов передачи
  final List<TextEditingController> _cityControllers = [];
  // ── список выбранных городов из списка (для валидации)
  final List<String?> _selectedCities = [];
  final descCtrl = TextEditingController();
  
  // ── Список городов для автокомплита (загружается из БД)
  List<String> _cities = [];

  final List<String> _categories = const [
    'Кроссовки',
    'Часы',
    'Одежда',
    'Аксессуары',
  ];
  String _category = 'Кроссовки';

  /// null = Любой
  Gender? _gender;

  // ── список существующих изображений (URL)
  final List<String> _existingImages = [];
  // ── список новых изображений (File)
  final List<File> _newImages = [];

  bool _isLoading = true;
  String? _error;

  bool get _isValid =>
      titleCtrl.text.trim().isNotEmpty && priceCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // ── создаём первое поле для ввода города передачи
    _cityControllers.add(TextEditingController());
    _selectedCities.add(null);
    _cityControllers.last.addListener(() {
      setState(() {});
      // Если текст изменился не через выбор из списка, сбрасываем выбранный город
      final index = _cityControllers.length - 1;
      if (_cityControllers[index].text.trim() != _selectedCities[index]) {
        _selectedCities[index] = null;
      }
    });
    // Загружаем список городов из БД
    _loadCities();
    _loadThingData();
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
    }
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

  /// Загружает данные объявления из API
  Future<void> _loadThingData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        throw Exception('Не удалось получить ID пользователя');
      }

      final api = ref.read(apiServiceProvider);
      final response = await api.get(
        '/get_thing.php',
        queryParams: {
          'thing_id': widget.thingId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Ошибка загрузки данных');
      }

      final thing = response['thing'] as Map<String, dynamic>;

      // ── заполняем форму данными
      titleCtrl.text = thing['title'] ?? '';
      // ── форматируем цену с пробелами
      final price = (thing['price'] ?? 0) as int;
      priceCtrl.text = _formatPrice(price);
      _category = thing['category'] ?? 'Кроссовки';

      final genderStr = thing['gender'];
      if (genderStr == 'male') {
        _gender = Gender.male;
      } else if (genderStr == 'female') {
        _gender = Gender.female;
      } else {
        _gender = null;
      }

      descCtrl.text = thing['description'] ?? '';

      // ── заполняем города
      final cities = (thing['cities'] as List<dynamic>?) ?? [];
      _cityControllers.clear();
      _selectedCities.clear();
      if (cities.isEmpty) {
        _cityControllers.add(TextEditingController());
        _selectedCities.add(null);
        _cityControllers.last.addListener(() {
          setState(() {});
          final index = _cityControllers.length - 1;
          if (_cityControllers[index].text.trim() != _selectedCities[index]) {
            _selectedCities[index] = null;
          }
        });
      } else {
        for (final city in cities) {
          final cityName = city.toString();
          final controller = TextEditingController(text: cityName);
          // Проверяем, есть ли город в списке
          final selectedCity = _cities.contains(cityName) ? cityName : null;
          _selectedCities.add(selectedCity);
          controller.addListener(() {
            setState(() {});
            final index = _cityControllers.length - 1;
            if (controller.text.trim() != _selectedCities[index]) {
              _selectedCities[index] = null;
            }
          });
          _cityControllers.add(controller);
        }
      }

      // ── заполняем существующие изображения
      final images = (thing['images'] as List<dynamic>?) ?? [];
      _existingImages.clear();
      _existingImages.addAll(images.map((img) => img.toString()));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── добавление нового поля для ввода города передачи
  void _addCityField() {
    setState(() {
      final newController = TextEditingController();
      _selectedCities.add(null);
      newController.addListener(() {
        setState(() {});
        final index = _cityControllers.length;
        if (newController.text.trim() != _selectedCities[index]) {
          _selectedCities[index] = null;
        }
      });
      _cityControllers.add(newController);
    });
  }

  /// Удаляет объявление
  Future<void> _handleDelete() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // ── показываем диалог подтверждения
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Удаление объявления'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Вы уверены, что хотите удалить это объявление? Это действие нельзя отменить.',
            style: TextStyle(fontSize: 15),
          ),
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

    if (confirmed != true) return;

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
        final data = await api.post(
          '/delete_thing.php',
          body: {'thing_id': widget.thingId, 'user_id': userId},
        );

        if (data['success'] != true) {
          final errorMessage = data['message']?.toString() ?? 'Ошибка сервера';
          throw Exception(errorMessage);
        }
      },
      onSuccess: () async {
        if (!mounted) return;
        Navigator.pop(context, true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при удалении объявления');
      },
    );
  }

  /// Сохраняет изменения объявления на сервер
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
        // ── проверяем, что все города выбраны из списка
        for (int i = 0; i < _cityControllers.length; i++) {
          final cityText = _cityControllers[i].text.trim();
          if (cityText.isNotEmpty && !_cities.contains(cityText)) {
            // Город не найден в списке - очищаем поле
            _cityControllers[i].clear();
            _selectedCities[i] = null;
            throw Exception('Выберите все города из списка');
          }
        }
        
        // ── собираем города передачи из контроллеров (только выбранные из списка)
        final cities = _cityControllers
            .asMap()
            .entries
            .where((entry) {
              final index = entry.key;
              final cityText = entry.value.text.trim();
              return cityText.isNotEmpty && _selectedCities[index] != null;
            })
            .map((entry) => entry.value.text.trim())
            .toList();

        // ── формируем данные для отправки
        final fields = <String, String>{
          'thing_id': widget.thingId.toString(),
          'user_id': userId.toString(),
          'title': titleCtrl.text.trim(),
          'category': _category,
          'price': priceCtrl.text.replaceAll(' ', ''),
          'description': descCtrl.text.trim(),
        };

        // ── добавляем пол (если указан)
        if (_gender != null) {
          fields['gender'] = _gender == Gender.male ? 'male' : 'female';
        }

        // ── добавляем существующие изображения (JSON массив URL)
        if (_existingImages.isNotEmpty) {
          fields['existing_images'] = jsonEncode(_existingImages);
        }

        // ── добавляем города передачи (JSON массив)
        if (cities.isNotEmpty) {
          fields['cities'] = jsonEncode(cities);
        }

        Map<String, dynamic> data;

        if (_newImages.isEmpty) {
          // ── JSON-запрос (без новых файлов)
          final jsonBody = <String, dynamic>{
            'thing_id': widget.thingId,
            'user_id': userId,
            'title': titleCtrl.text.trim(),
            'category': _category,
            'price': int.tryParse(priceCtrl.text.replaceAll(' ', '')) ?? 0,
            'description': descCtrl.text.trim(),
          };
          if (_gender != null) {
            jsonBody['gender'] = _gender == Gender.male ? 'male' : 'female';
          }
          if (_existingImages.isNotEmpty) {
            jsonBody['existing_images'] = _existingImages;
          }
          if (cities.isNotEmpty) {
            jsonBody['cities'] = cities;
          }

          data = await api.post('/update_thing.php', body: jsonBody);
        } else {
          // ── Multipart-запрос (с новыми файлами)
          final files = <String, File>{};
          for (int i = 0; i < _newImages.length; i++) {
            files['images[$i]'] = _newImages[i];
          }

          data = await api.postMultipart(
            '/update_thing.php',
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
        if (!mounted) return;
        Navigator.pop(context, true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при обновлении объявления');
      },
    );
  }

  /// Обработчик добавления фотографий
  Future<void> _handleAddPhotos() async {
    final picker = ImagePicker();

    try {
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: ImagePickerHelper.maxPickerDimension,
        maxHeight: ImagePickerHelper.maxPickerDimension,
        imageQuality: ImagePickerHelper.pickerImageQuality,
      );
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
        _newImages.addAll(compressedFiles);
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  /// Обработчик удаления существующего изображения
  void _handleDeleteExistingImage(String url) {
    setState(() {
      _existingImages.remove(url);
    });
  }

  /// Обработчик удаления нового изображения
  void _handleDeleteNewImage(File file) {
    setState(() {
      _newImages.remove(file);
    });
  }

  /// Обработчик замены существующего изображения
  Future<void> _handleReplaceExistingImage(String url, int index) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // ── сжимаем выбранное фото
      final compressed = await compressLocalImage(
        sourceFile: File(pickedFile.path),
        maxSide: ImageCompressionPreset.post.maxSide,
        jpegQuality: ImageCompressionPreset.post.quality,
      );
      if (!mounted) return;

      setState(() {
        // ── удаляем старое изображение и добавляем новое
        _existingImages.removeAt(index);
        _newImages.add(compressed);
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  /// Обработчик замены нового изображения
  Future<void> _handleReplaceNewImage(File file, int index) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      // ── сжимаем выбранное фото
      final compressed = await compressLocalImage(
        sourceFile: File(pickedFile.path),
        maxSide: ImageCompressionPreset.post.maxSide,
        jpegQuality: ImageCompressionPreset.post.quality,
      );
      if (!mounted) return;

      setState(() {
        _newImages[index] = compressed;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
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
    if (_isLoading) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: PaceAppBar(
            title: 'Редактирование объявления',
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
                onPressed: _handleDelete,
              ),
            ],
          ),
          body: const Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    if (_error != null) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          appBar: PaceAppBar(
            title: 'Редактирование объявления',
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
                onPressed: _handleDelete,
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText.rich(
                TextSpan(
                  text: 'Ошибка загрузки:\n',
                  style: TextStyle(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  children: [
                    TextSpan(
                      text: _error ?? 'Неизвестная ошибка',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    // 🔻 умный нижний паддинг: клавиатура (viewInsets) > 0 ? берём её : берём safe-area
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom; // клавиатура
    final safeBottom = media.viewPadding.bottom; // «борода»/ноутч
    final bottomPad = (bottomInset > 0 ? bottomInset : safeBottom) + 20;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: PaceAppBar(
          backgroundColor: AppColors.twinBg,
          title: 'Редактирование объявления',
          showBack: true,
          showBottomDivider: false,
          elevation: 0,
        scrolledUnderElevation: 0,
          actions: [
            IconButton(
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.delete,
                size: 20,
                color: AppColors.error,
              ),
              onPressed: _handleDelete,
            ),
          ],
        ),
        body: GestureDetector(
          // ── снимаем фокус с текстовых полей при клике вне их
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(12, 20, 12, bottomPad),
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
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 20),

                const _SmallLabel('Пол'),
                const SizedBox(height: 8),
                _GenderAnyRow(
                  value: _gender,
                  onChanged: (g) => setState(
                    () => _gender = g,
                  ), // g может быть null (= Любой)
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
                      child: CityAutocompleteField(
                        controller: _cityControllers[index],
                        suggestions: _cities,
                        hintText: 'Населенный пункт',
                        onSelected: (city) {
                          setState(() {
                            _selectedCities[index] = city;
                            _cityControllers[index].text = city;
                          });
                        },
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
                  hint:
                      'Размер, отправка, передача и другая полезная информация',
                  controller: descCtrl,
                  minLines: 7, // ── минимальная высота поля 7 строк
                  maxLines: 20, // ── максимальная высота поля 20 строк
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
                        enabled: _isValid && !formState.isSubmitting,
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

  /// Горизонтальная карусель фотографий
  Widget _buildPhotoCarousel() {
    // ── общее количество элементов: кнопка добавления + существующие изображения + новые изображения
    final totalItems = 1 + _existingImages.length + _newImages.length;

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

          // ── существующие изображения
          if (index <= _existingImages.length) {
            final imageIndex = index - 1;
            final url = _existingImages[imageIndex];
            return _buildExistingPhotoItem(url, imageIndex);
          }

          // ── новые изображения
          final newImageIndex = index - 1 - _existingImages.length;
          final file = _newImages[newImageIndex];
          return _buildNewPhotoItem(file, newImageIndex);
        },
      ),
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
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
    );
  }

  /// Элемент существующего изображения с кнопкой удаления
  Widget _buildExistingPhotoItem(String url, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _handleReplaceExistingImage(url, index),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                color: AppColors.getBackgroundColor(context),
              ),
              clipBehavior: Clip.hardEdge,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
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
              onTap: () => _handleDeleteExistingImage(url),
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
      ),
    );
  }

  /// Элемент нового изображения с кнопкой удаления
  Widget _buildNewPhotoItem(File file, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _handleReplaceNewImage(file, index),
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
              onTap: () => _handleDeleteNewImage(file),
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
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
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
                  child: Text(
                    o,
                    style: AppTextStyles.h14w4.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Форматирует цену с пробелами каждые 3 цифры
String _formatPrice(int price) {
  final s = price.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final pos = s.length - i;
    buffer.write(s[i]);
    if (pos > 1 && pos % 3 == 1) {
      buffer.write(' ');
    }
  }
  return buffer.toString();
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
