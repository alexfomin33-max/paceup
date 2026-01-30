// lib/screens/lenta/state/newpost/edit_post_screen.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../../core/utils/error_handler.dart';
import '../../../../../core/utils/image_picker_helper.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../providers/lenta_provider.dart';
import '../../../../../core/providers/form_state_provider.dart';
import '../../../../../core/widgets/form_error_display.dart';
import '../../../../../providers/services/auth_provider.dart';

/// Модель «существующего» изображения, пришедшего с бэка
class _ExistingImage {
  final String url;
  bool keep;
  _ExistingImage(this.url, {required this.keep});
}

/// Вспомогательный класс для представления элемента карусели
class _CarouselItem {
  final int? existingIndex;
  final int? newIndex;
  final bool isExisting;

  _CarouselItem.existing(this.existingIndex)
    : newIndex = null,
      isExisting = true;
  _CarouselItem.newImage(this.newIndex)
    : existingIndex = null,
      isExisting = false;
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН РЕДАКТИРОВАНИЯ ПОСТА
/// ────────────────────────────────────────────────────────────────
/// Позволяет редактировать существующий пост с:
/// 1. Фотографиями поста (горизонтальная карусель)
///    - Существующие изображения (можно удалить/вернуть)
///    - Новые изображения (можно добавить)
/// 2. Описанием поста (текстовое поле)
/// ────────────────────────────────────────────────────────────────
class EditPostScreen extends ConsumerStatefulWidget {
  final int userId;
  final int postId;

  /// Текст, заголовок и изображения поста на момент открытия экрана
  final String initialText;
  final String initialTitle;
  final List<String> initialImageUrls;
  final int initialVisibility;

  const EditPostScreen({
    super.key,
    required this.userId,
    required this.postId,
    required this.initialText,
    this.initialTitle = '',
    required this.initialImageUrls,
    this.initialVisibility = 0,
  });

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  // ────────────────────────────────────────────────────────────────
  // 📝 КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;

  // Существующие картинки (по URL) — можно помечать keep=false
  late final List<_ExistingImage> _existing = widget.initialImageUrls
      .map((u) => _ExistingImage(u, keep: true))
      .toList();

  // Новые картинки, выбранные на устройстве
  final List<File> _newImages = [];

  // Доступность кнопки сохранения
  bool _canSave = false;

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  late final int _initialVisibility;
  int _selectedVisibility = 0;

  // Создание от имени клуба
  bool _createFromClub = false;
  List<Map<String, dynamic>> _clubs = [];
  int? _selectedClubId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _titleFocusNode = FocusNode();
    _descriptionController = TextEditingController(text: widget.initialText);
    _descriptionFocusNode = FocusNode();
    _initialVisibility = widget.initialVisibility.clamp(0, 2);
    _selectedVisibility = _initialVisibility;
    _titleController.addListener(_updateSaveState);
    _titleFocusNode.addListener(_updateSaveState);
    _descriptionController.addListener(_updateSaveState);
    _descriptionFocusNode.addListener(_updateSaveState);
    _loadUserClubs(); // ── загружаем клубы пользователя при инициализации
    _updateSaveState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  /// Проверяет, есть ли какие-либо изменения относительно исходных
  bool _hasChanges() {
    final textChanged =
        _descriptionController.text.trim() != widget.initialText.trim();
    final titleChanged =
        _titleController.text.trim() != widget.initialTitle.trim();

    final existingKeptUrls = _existing
        .where((e) => e.keep)
        .map((e) => e.url)
        .toList();
    final initiallyUrls = widget.initialImageUrls;

    // Сравним множества сохранённых URL с исходными
    final sameExisting =
        existingKeptUrls.length == initiallyUrls.length &&
        existingKeptUrls.toSet().containsAll(initiallyUrls.toSet());

    final newFilesAdded = _newImages.isNotEmpty;

    // Проверяем изменение видимости поста
    final visibilityChanged = _selectedVisibility != _initialVisibility;

    return textChanged ||
        titleChanged ||
        !sameExisting ||
        newFilesAdded ||
        visibilityChanged;
  }

  /// Обновляет состояние доступности кнопки сохранения
  void _updateSaveState() {
    final formState = ref.read(formStateProvider);
    setState(() => _canSave = _hasChanges() && !formState.isSubmitting);
  }

  // ── загрузка списка клубов пользователя
  Future<void> _loadUserClubs() async {
    try {
      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          _clubs = [];
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
          _clubs = clubsList.map((c) => {
            'id': c['id'] as int,
            'name': c['name'] as String,
          }).toList();
          // Если список не пустой и selectedClubId не установлен, выбираем первый
          if (_clubs.isNotEmpty && _selectedClubId == null) {
            _selectedClubId = _clubs.first['id'] as int;
          }
        });
      } else {
        setState(() {
          _clubs = [];
        });
      }
    } catch (e) {
      setState(() {
        _clubs = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        resizeToAvoidBottomInset: false,
        appBar: const PaceAppBar(
          title: 'Редактировать пост',
          backgroundColor: AppColors.twinBg,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: GestureDetector(
          // Скрываем клавиатуру при нажатии на пустую область
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Stack(
              children: [
                // ────────────────────────────────────────────────────────────────
                // 📜 ПРОКРУЧИВАЕМАЯ ОБЛАСТЬ С КОНТЕНТОМ
                // ────────────────────────────────────────────────────────────────
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                          // ────────────────────────────────────────────────────────────────
                          // 📸 1. ФОТОГРАФИИ ПОСТА (горизонтальная карусель)
                          // ────────────────────────────────────────────────────────────────
                          Text(
                            'Фотографии поста',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _buildPhotoCarousel(),

                          const SizedBox(height: 24),

                          // ────────────────────────────────────────────────────────────────
                          // 📝 2. ЗАГОЛОВОК ПОСТА
                          // ────────────────────────────────────────────────────────────────
                          Text(
                            'Заголовок поста',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTitleInput(),

                          const SizedBox(height: 24),

                          // ────────────────────────────────────────────────────────────────
                          // 📝 3. ОПИСАНИЕ ПОСТА
                          // ────────────────────────────────────────────────────────────────
                          Text(
                            'Описание поста',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDescriptionInput(),

                          const SizedBox(height: 24),

                          // ────────────────────────────────────────────────────────────────
                          // 👁️ 3. КТО ВИДИТ ПОСТ (выпадающий список)
                          // ────────────────────────────────────────────────────────────────
                          Text(
                            'Кто видит пост',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.getTextPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildVisibilitySelector(),

                          const SizedBox(height: 24),

                          // ────────────────────────────────────────────────────────────────
                          // 🏢 4. РЕДАКТИРОВАТЬ ОТ ИМЕНИ КЛУБА
                          // ────────────────────────────────────────────────────────────────
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
                                      value: _createFromClub,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      activeColor: AppColors.brandPrimary,
                                      checkColor:
                                          AppColors.getSurfaceColor(context),
                                      side: BorderSide(
                                        color: AppColors.getIconSecondaryColor(
                                          context,
                                        ),
                                        width: 1.5,
                                      ),
                                      onChanged: (v) => setState(
                                        () => _createFromClub = v ?? false,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Редактировать от имени клуба',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_createFromClub) ...[
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) => Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: AppColors.twinchip,
                                    width: 0.7,
                                  ),
                                ),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.getSurfaceColor(
                                      context,
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedClubId,
                                      isExpanded: true,
                                      hint: const Text(
                                        'Выберите клуб',
                                        style: AppTextStyles.h14w4Place,
                                      ),
                                      onChanged: (_createFromClub &&
                                              _clubs.isNotEmpty)
                                          ? (int? newValue) {
                                              setState(() {
                                                _selectedClubId = newValue;
                                              });
                                            }
                                          : null,
                                      dropdownColor:
                                          AppColors.getSurfaceColor(context),
                                      menuMaxHeight: 300,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.lg,
                                      ),
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: (_createFromClub &&
                                                _clubs.isNotEmpty)
                                            ? AppColors.getIconSecondaryColor(
                                                context,
                                              )
                                            : AppColors.iconTertiary,
                                      ),
                                      style: AppTextStyles.h14w4.copyWith(
                                        color: (_createFromClub &&
                                                _clubs.isNotEmpty)
                                            ? AppColors.getTextPrimaryColor(
                                                context,
                                              )
                                            : AppColors.getTextPlaceholderColor(
                                                context,
                                              ),
                                      ),
                                      items: _clubs.map((item) {
                                        return DropdownMenuItem<int>(
                                          value: item['id'] as int,
                                          child: Text(
                                            item['name'] as String,
                                            style: AppTextStyles.h14w4.copyWith(
                                              color: AppColors
                                                  .getTextPrimaryColor(context),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Показываем ошибки, если есть
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
                        ],
                      ),
                    ),
                // ───────── Плавающая кнопка сохранения (стеклянный эффект)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: _buildSaveButton(),
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
    return Builder(
      builder: (context) {
        // ────────────────────────────────────────────────────────────────
        // 🔹 ВЫЧИСЛЕНИЕ ДИНАМИЧЕСКОГО РАЗМЕРА ЭЛЕМЕНТА
        // ────────────────────────────────────────────────────────────────
        // Размер вычисляется так, чтобы в одну линию на экране помещалось ровно 3 элемента
        // Учитываем: паддинг Column (16px с каждой стороны = 32px) и отступы между элементами (2 отступа по 12px = 24px)
        final screenWidth = MediaQuery.of(context).size.width;
        const horizontalPadding = 16.0 * 2; // Паддинг Column с двух сторон
        const separatorWidth = 12.0 * 2; // 2 отступа между 3 элементами
        final itemSize = (screenWidth - horizontalPadding - separatorWidth) / 3;

        // ────────────────────────────────────────────────────────────────
        // 🔹 СОЗДАНИЕ СПИСКА ЭЛЕМЕНТОВ С ОГРАНИЧЕНИЕМ В 3 ЭЛЕМЕНТА
        // ────────────────────────────────────────────────────────────────
        // Максимум 3 элемента в карусели: существующие + новые + кнопка (если есть место)
        final List<_CarouselItem> items = [];

        // Добавляем существующие изображения (только те, что keep=true)
        for (int i = 0; i < _existing.length; i++) {
          if (_existing[i].keep) {
            items.add(_CarouselItem.existing(i));
            if (items.length >= 3) break;
          }
        }

        // Добавляем новые изображения (если еще есть место)
        for (int i = 0; i < _newImages.length && items.length < 3; i++) {
          items.add(_CarouselItem.newImage(i));
        }

        // Показываем кнопку добавления только если есть место (меньше 3 элементов)
        final showAddButton = items.length < 3;
        final totalItems = items.length + (showAddButton ? 1 : 0);

        return SizedBox(
          height:
              itemSize +
              6, // Размер элемента + padding сверху для кнопок удаления
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(
              top: 6,
            ), // Добавляем padding сверху для кнопок удаления
            itemCount: totalItems,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Сначала показываем элементы медиа (существующие и новые фотографии)
              if (index < items.length) {
                final item = items[index];
                if (item.isExisting) {
                  return _buildExistingPhotoItem(
                    _existing[item.existingIndex!],
                    itemSize,
                  );
                } else {
                  return _buildNewPhotoItem(
                    _newImages[item.newIndex!],
                    item.newIndex!,
                    itemSize,
                  );
                }
              }

              // Если есть место (items.length < 3), последний элемент — кнопка добавления
              // Кнопка всегда справа от всех элементов
              return _buildAddPhotoButton(itemSize);
            },
          ),
        );
      },
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton(double size) {
    return GestureDetector(
      onTap: _handleAddPhotos,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: AppColors.twinphoto,
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

  /// Элемент существующего изображения (по URL) с возможностью удалить/вернуть
  Widget _buildExistingPhotoItem(_ExistingImage existing, double size) {
    return Builder(
      builder: (context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                // По тапу можно заменить файл (станет НОВОЙ картинкой),
                // а текущую пометим на удаление (keep=false)
                // ── выбираем и обрезаем изображение в соотношении 1:1.1 (ширина:высота)
                final aspectRatio = 1.0 / 1.1;
                final processed = await ImagePickerHelper.pickAndProcessImage(
                  context: context,
                  aspectRatio: aspectRatio,
                  maxSide: ImageCompressionPreset.post.maxSide,
                  jpegQuality: ImageCompressionPreset.post.quality,
                  cropTitle: 'Обрезать',
                );
                if (processed == null || !mounted) return;

                setState(() {
                  existing.keep = false;
                  _newImages.add(processed);
                  _updateSaveState();
                });
              },
              child: Opacity(
                opacity: existing.keep ? 1.0 : 0.35,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    color: AppColors.getBackgroundColor(context),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Builder(
                    builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final side = (size * dpr).round();
                      return CachedNetworkImage(
                        imageUrl: existing.url,
                        fit: BoxFit.cover,
                        memCacheWidth: side,
                        maxWidthDiskCache: side,
                        placeholder: (context, url) => Container(
                          color: AppColors.getBackgroundColor(context),
                          child: const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
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
            ),
            // Кнопка удалить/вернуть в правом верхнем углу
            Positioned(
              right: -6,
              top: -6,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    existing.keep = !existing.keep;
                    _updateSaveState();
                  });
                },
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
                  child: Icon(
                    existing.keep
                        ? CupertinoIcons.clear_circled_solid
                        : CupertinoIcons.arrow_uturn_left_circle_fill,
                    size: 20,
                    color: existing.keep
                        ? AppColors.error
                        : AppColors.brandPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Элемент нового фото (локальный файл) с кнопкой удаления
  Widget _buildNewPhotoItem(File file, int photoIndex, double size) {
    return Builder(
      builder: (context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () async {
                // По тапу можно заменить картинку
                // ── выбираем и обрезаем изображение в соотношении 1:1.1 (ширина:высота)
                final aspectRatio = 1.0 / 1.1;
                final processed = await ImagePickerHelper.pickAndProcessImage(
                  context: context,
                  aspectRatio: aspectRatio,
                  maxSide: ImageCompressionPreset.post.maxSide,
                  jpegQuality: ImageCompressionPreset.post.quality,
                  cropTitle: 'Обрезать',
                );
                if (processed == null || !mounted) return;

                setState(() {
                  _newImages[photoIndex] = processed;
                  _updateSaveState();
                });
              },
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: AppColors.getBackgroundColor(context),
                ),
                clipBehavior: Clip.antiAlias,
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
            // Кнопка удаления в правом верхнем углу
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

  /// Поле ввода заголовка
  Widget _buildTitleInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.7,
        ),
      ),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocusNode,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Введите заголовок поста',
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          filled: true,
          fillColor: AppColors.surface,
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
        onSubmitted: (_) {
          // Переходим к полю описания при нажатии Enter
          FocusScope.of(context).requestFocus(_descriptionFocusNode);
        },
      ),
    );
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocusNode,
        maxLines: 20,
        minLines: 10,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.h14w4.copyWith(
          color: AppColors.getTextPrimaryColor(context),
        ),
        decoration: InputDecoration(
          hintText: 'Обновите описание',
          hintStyle: AppTextStyles.h14w4Place.copyWith(
            color: AppColors.getTextPlaceholderColor(context),
          ),
          filled: true,
          fillColor: AppColors.surface,
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
    );
  }

  /// Выпадающий список для выбора видимости
  Widget _buildVisibilitySelector() {
    const List<String> options = [
      'Все пользователи',
      'Только подписчики',
      'Только Вы',
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
                          color: AppColors.twinchip,
                          width: 0.7,
                        ),
        // boxShadow: [
        //   const BoxShadow(
        //     color: AppColors.twinshadow,
        //     blurRadius: 20,
        //     offset: Offset(0, 1),
        //   ),
        // ],
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
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
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: options[_selectedVisibility],
            isExpanded: true,
            alignment: AlignmentDirectional.centerStart,
            onChanged: (String? newValue) {
              if (newValue != null) {
                final index = options.indexOf(newValue);
                if (index != -1) {
                  setState(() {
                    _selectedVisibility = index;
                    _updateSaveState();
                  });
                }
              }
            },
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: AppTextStyles.h14w4.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    final formState = ref.watch(formStateProvider);
    final textColor = AppColors.getSurfaceColor(context);
    final isLoading = formState.isSubmitting;
    final isValid = _canSave;

    // ─────────── Содержимое кнопки без эффекта стекла
    final button = ElevatedButton(
      onPressed: (isLoading || !isValid) ? null : _submitEdit,
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
              'Сохранить',
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
    if (isLoading) {
      return IgnorePointer(child: glassButton);
    }

    return glassButton;
  }

  /// Сохраняет изменения поста на сервер
  Future<void> _submitEdit() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    final text = _descriptionController.text.trim();
    final keepUrls = _existing.where((e) => e.keep).map((e) => e.url).toList();
    final hasNewFiles = _newImages.isNotEmpty;

    final formNotifier = ref.read(formStateProvider.notifier);
    final api = ref.read(apiServiceProvider);

    await formNotifier.submit(
      () async {
        Map<String, dynamic> data;

        if (!hasNewFiles) {
          // JSON-запрос: только текст/состав существующих картинок
          data = await api.post(
            '/update_post.php',
            body: {
              'post_id': widget.postId.toString(),
              'user_id': widget.userId.toString(),
              'text': text,
              'title': _titleController.text.trim(), // ── Добавляем заголовок поста
              'privacy': _selectedVisibility.toString(),
              'keep_images': keepUrls,
              if (_createFromClub && _selectedClubId != null)
                'club_id': _selectedClubId.toString(),
            },
          );
        } else {
          // Multipart-запрос: добавились новые файлы
          final files = <String, File>{};
          for (int i = 0; i < _newImages.length; i++) {
            files['images[$i]'] = _newImages[i];
          }

          data = await api.postMultipart(
            '/update_post.php',
            files: files,
            fields: {
              'post_id': widget.postId.toString(),
              'user_id': widget.userId.toString(),
              'text': text,
              'title': _titleController.text.trim(), // ── Добавляем заголовок поста
              'privacy': _selectedVisibility.toString(),
              'keep_images': keepUrls.toString(),
              if (_createFromClub && _selectedClubId != null)
                'club_id': _selectedClubId.toString(),
            },
            timeout: const Duration(seconds: 60),
          );
        }

        // Проверяем разные форматы ответа API
        bool success = false;
        String? errorMessage;

        // Сервер может возвращать массив внутри 'data'
        final actualData =
            data['data'] is List && (data['data'] as List).isNotEmpty
            ? (data['data'] as List)[0] as Map<String, dynamic>
            : data;

        // Формат 1: прямой success в корне
        if (actualData['success'] == true) {
          success = true;
        }
        // Формат 2: success в data массиве
        else if (data['data'] is List && (data['data'] as List).isNotEmpty) {
          final firstItem = (data['data'] as List)[0];
          if (firstItem is Map<String, dynamic>) {
            if (firstItem['success'] == true) {
              success = true;
            } else {
              errorMessage = firstItem['message']?.toString();
            }
          }
        }
        // Формат 3: success в data объекте
        else if (data['data'] is Map<String, dynamic>) {
          final dataObj = data['data'] as Map<String, dynamic>;
          if (dataObj['success'] == true) {
            success = true;
          } else {
            errorMessage = dataObj['message']?.toString();
          }
        }
        // Формат 4: error или message в корне
        else if (data['error'] != null || data['message'] != null) {
          errorMessage = (data['error'] ?? data['message']).toString();
        }
        // Неизвестный формат
        else {
          errorMessage = 'Неизвестный формат ответа сервера';
        }

        if (!success) {
          final msg = errorMessage ?? 'Ошибка сервера';
          throw Exception(msg);
        }

        // Обновляем ленту
        await ref.read(lentaProvider(widget.userId).notifier).forceRefresh();

        // Небольшая задержка для гарантии обновления данных на сервере
        await Future.delayed(const Duration(milliseconds: 500));
      },
      onSuccess: () {
        if (!mounted) return;
        Navigator.pop(context, true);
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при сохранении поста');
      },
    );

    // Обновляем состояние кнопки после завершения
    if (mounted) {
      _updateSaveState();
    }
  }

  /// Обработчик добавления фотографий к посту
  Future<void> _handleAddPhotos() async {
    try {
      // ── выбираем и обрезаем изображения в соотношении 1:1.1 (ширина:высота)
      // Используем стандартный pickMultiImage, затем обрезаем каждое
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: ImagePickerHelper.maxPickerDimension,
        maxHeight: ImagePickerHelper.maxPickerDimension,
        imageQuality: ImagePickerHelper.pickerImageQuality,
      );
      if (pickedFiles.isEmpty || !mounted) return;

      // Соотношение сторон 1:1.1 (ширина:высота)
      final aspectRatio = 1.0 / 1.1;

      // ── обрезаем и сжимаем все выбранные изображения
      final compressedFiles = <File>[];
      for (int i = 0; i < pickedFiles.length; i++) {
        if (!mounted) return;

        final picked = pickedFiles[i];
        // Обрезаем изображение в соотношении 1:1.1 (ширина:высота)
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезать',
        );

        if (cropped == null)
          continue; // Пропускаем, если пользователь отменил обрезку

        // Сжимаем обрезанное изображение
        final compressed = await compressLocalImage(
          sourceFile: cropped,
          maxSide: ImageCompressionPreset.post.maxSide,
          jpegQuality: ImageCompressionPreset.post.quality,
        );

        // Удаляем временный файл обрезки
        if (cropped.path != compressed.path) {
          try {
            await cropped.delete();
          } catch (_) {
            // Игнорируем ошибки удаления
          }
        }

        compressedFiles.add(compressed);
      }

      if (compressedFiles.isEmpty || !mounted) return;

      setState(() {
        _newImages.addAll(compressedFiles);
        _updateSaveState();
      });
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    }
  }

  /// Обработчик удаления фотографии
  void _handleDeletePhoto(File file) {
    setState(() {
      _newImages.remove(file);
      _updateSaveState();
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
}
