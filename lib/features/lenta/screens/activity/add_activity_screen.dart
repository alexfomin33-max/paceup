// lib/screens/lenta/activity/add_activity_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_image_compressor.dart'
    show compressLocalImage, ImageCompressionPreset;
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_picker_helper.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../domain/models/activity_lenta.dart' as al;
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../features/lenta/providers/lenta_provider.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/providers/form_state_provider.dart';

import '../widgets/activity/equipment/equipment_chip.dart';
import 'description_screen.dart';

/// ────────────────────────────────────────────────────────────────
/// 🔹 ЭКРАН ДОБАВЛЕНИЯ АКТИВНОСТИ
/// ────────────────────────────────────────────────────────────────
/// Позволяет создать новую тренировку с:
/// 1. Фотографиями тренировки (горизонтальная карусель)
/// 2. Типом тренировки (выпадающий список: "Бег", "Велосипед", "Плавание")
/// 3. Описанием тренировки (текстовое поле)
/// 4. Экипировкой (чекбокс, при включении показывается EquipmentChip)
/// 5. Видимостью тренировки (выпадающий список)
/// ────────────────────────────────────────────────────────────────
class AddActivityScreen extends ConsumerStatefulWidget {
  final int currentUserId;

  const AddActivityScreen({super.key, required this.currentUserId});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  // ────────────────────────────────────────────────────────────────
  // 📝 КОНТРОЛЛЕРЫ И СОСТОЯНИЕ
  // ────────────────────────────────────────────────────────────────
  late final TextEditingController _descriptionController;
  late final FocusNode _descriptionFocusNode;

  // Вид тренировки: "Бег", "Велосипед", "Плавание", "Лыжи"
  String? _selectedActivityType;
  static const List<String> _activityTypes = [
    'Бег',
    'Велосипед',
    'Плавание',
    'Лыжи',
  ];
  static const Map<String, String> _activityTypeMap = {
    'Бег': 'run',
    'Велосипед': 'bike',
    'Плавание': 'swim',
    'Лыжи': 'ski',
  };

  // Дата и время тренировки
  DateTime? _activityDate;
  TimeOfDay? _startTime;
  Duration? _duration; // По умолчанию не выбрана
  // ── отдельный фокус для пикеров, чтобы не поднимать клавиатуру после закрытия
  final _pickerFocusNode = FocusNode(debugLabel: 'addActivityPickerFocus');

  // Дистанция тренировки (в километрах)
  final TextEditingController _distanceController = TextEditingController();

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  int _selectedVisibility = 0;

  // Экипировка
  bool _showEquipment = false;
  List<al.Equipment> _availableEquipment = [];
  al.Equipment? _selectedEquipment;
  bool _isLoadingEquipment = false;

  // Список фотографий (для отображения в карусели)
  // Может содержать как локальные файлы (File), так и URL (String)
  final List<dynamic> _images = [];

  // Индекс перетаскиваемой фотографии
  int? _draggedIndex;

  // GPX файл тренировки
  File? _gpxFile;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _descriptionFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _distanceController.dispose();
    _pickerFocusNode.dispose();
    super.dispose();
  }

  // ── снимаем фокус перед показом пикеров, чтобы клавиатура не возвращалась
  void _unfocusKeyboard() {
    FocusScope.of(context).requestFocus(_pickerFocusNode);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Добавить тренировку'),
        body: GestureDetector(
          // Скрываем клавиатуру при нажатии на пустую область
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ────────────────────────────────────────────────────────────────
                  // 📸 1. ФОТОГРАФИИ ТРЕНИРОВКИ (горизонтальная карусель)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Фото тренировки',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildPhotoCarousel(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📁 ФАЙЛ GPX ТРЕНИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Файл тренировки (GPX)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildGpxFileSelector(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 🏃 2. ВИД ТРЕНИРОВКИ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Вид тренировки',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildActivityTypeSelector(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📅 3. ДАТА И ВРЕМЯ ТРЕНИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Дата тренировки',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDateField(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Время начала',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTimeField(),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📏 ДИСТАНЦИЯ И ДЛИТЕЛЬНОСТЬ ТРЕНИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Дистанция (км)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDistanceField(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Длительность',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDurationField(),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 📝 4. ОПИСАНИЕ ТРЕНИРОВКИ
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Описание тренировки',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildDescriptionInput(),

                  const SizedBox(height: 24),

                  // ────────────────────────────────────────────────────────────────
                  // 👟 5. ДОБАВИТЬ ЭКИПИРОВКУ (чекбокс + EquipmentChip)
                  // ────────────────────────────────────────────────────────────────
                  // Показываем только для "Бег" и "Велосипед"
                  if (_shouldShowEquipment()) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Transform.scale(
                            scale: 0.85, // Уменьшаем размер на 15%
                            alignment: Alignment.centerLeft,
                            child: Checkbox(
                              value: _showEquipment,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              activeColor:
                                  AppColors.brandPrimary, // Цвет при выборе
                              checkColor: AppColors.getSurfaceColor(
                                context,
                              ), // Цвет галочки
                              side: BorderSide(
                                color: AppColors.getIconSecondaryColor(
                                  context,
                                ), // Более светлый цвет границы
                                width: 1.5,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _showEquipment = value ?? false;
                                  if (_showEquipment &&
                                      _availableEquipment.isEmpty) {
                                    _loadEquipment();
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Добавить экипировку',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_showEquipment) ...[
                      const SizedBox(height: 8),
                      _buildEquipmentSection(),
                    ],
                  ],

                  SizedBox(height: _shouldShowEquipment() ? 24 : 0),

                  // ────────────────────────────────────────────────────────────────
                  // 👁️ 6. КТО ВИДИТ ТРЕНИРОВКУ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Кто видит тренировку',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildVisibilitySelector(),

                  const SizedBox(height: 32),

                  // ────────────────────────────────────────────────────────────────
                  // 💾 КНОПКА СОХРАНЕНИЯ
                  // ────────────────────────────────────────────────────────────────
                  Center(child: _buildSaveButton()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Горизонтальная карусель фотографий
  Widget _buildPhotoCarousel() {
    // Общее количество элементов: кнопка добавления + фотографии
    final totalItems = 1 + _images.length;

    return SizedBox(
      height: 96, // 90 + 6 (padding сверху для кнопок удаления)
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 6),
        itemCount: totalItems,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Первый элемент — кнопка добавления фото
          if (index == 0) {
            return _buildAddPhotoButton();
          }
          // Остальные элементы — фотографии
          final photoIndex = index - 1;
          final image = _images[photoIndex];
          return _buildDraggablePhotoItem(image, photoIndex);
        },
      ),
    );
  }

  /// Кнопка добавления фотографии
  Widget _buildAddPhotoButton() {
    return GestureDetector(
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
    );
  }

  /// Перетаскиваемый элемент фотографии
  Widget _buildDraggablePhotoItem(Object image, int photoIndex) {
    final isDragging = _draggedIndex == photoIndex;

    return LongPressDraggable<Object>(
      data: image,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: _buildPhotoItemContent(image, isDragging: true),
        ),
      ),
      onDragStarted: () {
        setState(() {
          _draggedIndex = photoIndex;
        });
      },
      onDragEnd: (details) {
        setState(() {
          _draggedIndex = null;
        });
      },
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (data) => data != image,
        onAcceptWithDetails: (data) {
          final oldIndex = _images.indexOf(data);
          final newIndex = photoIndex;

          if (oldIndex != -1 && oldIndex != newIndex) {
            setState(() {
              _images.removeAt(oldIndex);
              _images.insert(newIndex, data);
            });
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isTargeted = candidateData.isNotEmpty;
          return Opacity(
            opacity: isDragging ? 0.5 : (isTargeted ? 0.7 : 1.0),
            child: _buildPhotoItemContent(image, isDragging: isDragging),
          );
        },
      ),
    );
  }

  /// Содержимое элемента фотографии (без обертки drag and drop)
  Widget _buildPhotoItemContent(Object image, {bool isDragging = false}) {
    return Builder(
      builder: (context) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final w = (90 * dpr).round();

        return SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  color: AppColors.getBackgroundColor(context),
                  border: isDragging
                      ? Border.all(color: AppColors.brandPrimary, width: 2)
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: image is File
                    ? Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.getBackgroundColor(context),
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: image as String,
                        fit: BoxFit.cover,
                        memCacheWidth: w,
                        maxWidthDiskCache: w,
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
                      ),
              ),
              // Кнопка удаления в правом верхнем углу
              Positioned(
                right: -6,
                top: -6,
                child: GestureDetector(
                  onTap: () => _handleDeletePhoto(image),
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
        );
      },
    );
  }

  /// Виджет для выбора GPX файла
  Widget _buildGpxFileSelector() {
    if (_gpxFile != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.doc,
              size: 20,
              color: AppColors.getIconPrimaryColor(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _gpxFile?.path.split('/').last ?? '',
                style: AppTextStyles.h14w4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _gpxFile = null;
                });
              },
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
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _handlePickGpxFile,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.add_circled,
              size: 20,
              color: AppColors.getIconSecondaryColor(context),
            ),
            const SizedBox(width: 8),
            const Text('Прикрепить файл GPX', style: AppTextStyles.h14w4Place),
          ],
        ),
      ),
    );
  }

  /// Выпадающий список для выбора типа тренировки
  Widget _buildActivityTypeSelector() {
    final isEnabled = _gpxFile == null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InputDecorator(
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
            value: _selectedActivityType,
            isExpanded: true,
            hint: const Text(
              'Выберите вид тренировки',
              style: AppTextStyles.h14w4Place,
            ),
            onChanged: isEnabled
                ? (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedActivityType = newValue;
                        // При смене типа тренировки сбрасываем выбранную экипировку
                        _selectedEquipment = null;
                        // Если выбран "Плавание" — скрываем экипировку
                        if (!_shouldShowEquipment()) {
                          _showEquipment = false;
                        } else if (_showEquipment) {
                          _loadEquipment();
                        }
                      });
                    }
                  }
                : null,
            dropdownColor: AppColors.getSurfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(AppRadius.md),
            icon: Icon(
              Icons.arrow_drop_down,
              color: AppColors.getIconSecondaryColor(context),
            ),
            style: AppTextStyles.h14w4,
            items: _activityTypes.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: AppTextStyles.h14w4),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Поле выбора даты тренировки
  Widget _buildDateField() {
    final isEnabled = _gpxFile == null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _pickDate : null,
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
                padding: const EdgeInsets.only(left: 12, right: 6),
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
            child: Text(
              _activityDate != null
                  ? _formatDate(_activityDate!)
                  : 'Выберите дату',
              style: _activityDate != null
                  ? AppTextStyles.h14w4
                  : AppTextStyles.h14w4Place,
            ),
          ),
        ),
      ),
    );
  }

  /// Поле выбора времени начала
  Widget _buildTimeField() {
    final isEnabled = _gpxFile == null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _pickTime : null,
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
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(
                  CupertinoIcons.time,
                  size: 18,
                  color: AppColors.getIconPrimaryColor(context),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 18 + 14,
                minHeight: 18,
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
            child: Text(
              _startTime != null ? _formatTime(_startTime!) : 'Выберите время',
              style: _startTime != null
                  ? AppTextStyles.h14w4
                  : AppTextStyles.h14w4Place,
            ),
          ),
        ),
      ),
    );
  }

  /// Поле ввода дистанции
  Widget _buildDistanceField() {
    final isEnabled = _gpxFile == null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: TextField(
        controller: _distanceController,
        enabled: isEnabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        style: AppTextStyles.h14w4,
        decoration: InputDecoration(
          hintText: '0.0',
          hintStyle: AppTextStyles.h14w4Place,
          filled: true,
          fillColor: AppColors.getSurfaceColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 17,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 6),
            child: Icon(
              CupertinoIcons.location,
              size: 18,
              color: AppColors.getIconPrimaryColor(context),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 18 + 14,
            minHeight: 18,
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
  }

  /// Поле выбора длительности тренировки
  Widget _buildDurationField() {
    final isEnabled = _gpxFile == null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: isEnabled ? _pickDuration : null,
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
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(
                  CupertinoIcons.timer,
                  size: 18,
                  color: AppColors.getIconPrimaryColor(context),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 18 + 14,
                minHeight: 18,
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
            child: Text(
              _duration != null ? _formatDuration(_duration) : '00:00:00',
              style: _duration != null
                  ? AppTextStyles.h14w4
                  : AppTextStyles.h14w4Place,
            ),
          ),
        ),
      ),
    );
  }

  /// Поле ввода описания
  Widget _buildDescriptionInput() {
    return TextField(
      controller: _descriptionController,
      focusNode: _descriptionFocusNode,
      maxLines: 12,
      minLines: 7,
      textAlignVertical: TextAlignVertical.top,
      style: AppTextStyles.h14w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: 'Введите описание тренировки',
        hintStyle: AppTextStyles.h14w4Place.copyWith(
          color: AppColors.getTextPlaceholderColor(context),
        ),
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
    );
  }

  /// Секция с экипировкой
  Widget _buildEquipmentSection() {
    if (_isLoadingEquipment) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    if (_availableEquipment.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Нет доступной экипировки для выбранного типа тренировки',
          style: AppTextStyles.h14w4.copyWith(
            color: AppColors.getTextSecondaryColor(context),
          ),
        ),
      );
    }

    // Если экипировка выбрана, показываем EquipmentChip
    if (_selectedEquipment != null) {
      return EquipmentChip(
        items: [_selectedEquipment!],
        userId: widget.currentUserId,
        activityType: _activityTypeMap[_selectedActivityType] ?? 'run',
        activityId: 0, // Временный ID, будет заменен после создания активности
        activityDistance: 0.0,
        showMenuButton: true,
        // ────────────────────────────────────────────────────────────────
        // 🔹 ФОН ПЛАШКИ: в светлой теме используем surface вместо background
        // ────────────────────────────────────────────────────────────────
        // Только для светлой темы на этой странице
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getSurfaceColor(context)
            : null, // В темной теме используем дефолтное поведение
        // ────────────────────────────────────────────────────────────────
        // 🔹 ФОН КНОПКИ МЕНЮ: в светлой теме используем background вместо surface
        // ────────────────────────────────────────────────────────────────
        // Только для светлой темы на этой странице
        menuButtonColor: Theme.of(context).brightness == Brightness.light
            ? AppColors.getBackgroundColor(context)
            : null, // В темной теме используем дефолтное поведение
        onEquipmentChanged: () {
          // После изменения экипировки обновляем список (параметр не используем)
          _loadEquipment();
        },
        onEquipmentSelected: (al.Equipment newEquipment) {
          // ────────────────────────────────────────────────────────────────
          // 🔹 ОБНОВЛЕНИЕ ВЫБРАННОЙ ЭКИПИРОВКИ
          // ────────────────────────────────────────────────────────────────
          // При выборе новой экипировки во всплывающем окне обновляем состояние
          setState(() {
            _selectedEquipment = newEquipment;
          });
        },
      );
    }

    // Если экипировка не выбрана, показываем выпадающий список для выбора
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
        child: DropdownButton<al.Equipment>(
          value: _selectedEquipment,
          isExpanded: true,
          hint: const Text('Выберите экипировку', style: AppTextStyles.h14w4),
          onChanged: (al.Equipment? newValue) {
            setState(() {
              _selectedEquipment = newValue;
            });
          },
          dropdownColor: AppColors.getSurfaceColor(context),
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.getIconSecondaryColor(context),
          ),
          items: _availableEquipment.map((equipment) {
            final displayName = equipment.brand.isNotEmpty
                ? '${equipment.brand} ${equipment.name}'
                : equipment.name;
            return DropdownMenuItem<al.Equipment>(
              value: equipment,
              child: Text(displayName, style: AppTextStyles.h14w4),
            );
          }).toList(),
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

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          value: options[_selectedVisibility],
          isExpanded: true,
          onChanged: (String? newValue) {
            if (newValue != null) {
              final index = options.indexOf(newValue);
              if (index != -1) {
                setState(() {
                  _selectedVisibility = index;
                });
              }
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
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    final formState = ref.watch(formStateProvider);
    return PrimaryButton(
      text: 'Сохранить',
      onPressed: !formState.isSubmitting ? _saveActivity : () {},
      width: 190,
      isLoading: formState.isSubmitting,
      enabled: !formState.isSubmitting,
    );
  }

  /// Загружает список экипировки для выбранного типа тренировки
  Future<void> _loadEquipment() async {
    if (_selectedActivityType == null) return;

    setState(() {
      _isLoadingEquipment = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.currentUserId.toString()},
      );

      if (data['success'] == true) {
        // Преобразуем тип активности в тип эквипа
        final String equipmentType = _activityTypeToEquipmentType(
          _activityTypeMap[_selectedActivityType] ?? 'run',
        );

        if (equipmentType.isEmpty) {
          setState(() {
            _availableEquipment = [];
            _isLoadingEquipment = false;
          });
          return;
        }

        // Получаем эквип нужного типа (boots или bikes)
        final List<dynamic> equipmentList = equipmentType == 'boots'
            ? data['boots'] ?? []
            : data['bikes'] ?? [];

        // Преобразуем в модель Equipment
        final List<al.Equipment> allEquipment = equipmentList
            .map(
              (item) => al.Equipment.fromJson({
                'name': item['name'] ?? '',
                'brand': item['brand'] ?? '',
                'mileage': item['dist'] ?? 0,
                'img': item['image'] ?? '',
                'main': item['main'] ?? false,
                'myraiting': 0.0,
                'type': equipmentType,
                'equip_user_id': item['equip_user_id'],
              }),
            )
            .toList();

        setState(() {
          _availableEquipment = allEquipment;
          _isLoadingEquipment = false;
        });
      } else {
        setState(() {
          _availableEquipment = [];
          _isLoadingEquipment = false;
        });
      }
    } catch (e) {
      setState(() {
        _availableEquipment = [];
        _isLoadingEquipment = false;
      });
    }
  }

  /// Проверяет, нужно ли показывать чекбокс экипировки
  /// Показываем только для "Бег" и "Велосипед"
  bool _shouldShowEquipment() {
    return _selectedActivityType == 'Бег' ||
        _selectedActivityType == 'Велосипед';
  }

  /// Форматирует дату в формат dd.MM.yyyy
  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = date.year.toString();
    return '$dd.$mm.$yy';
  }

  /// Форматирует время в формат HH:mm
  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Форматирует длительность в формат "X ч Y мин Z сек"
  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];
    if (hours > 0) parts.add('$hours ч');
    if (minutes > 0) parts.add('$minutes м');
    if (seconds > 0 || parts.isEmpty) parts.add('$seconds с');

    return parts.join(' ');
  }

  /// Показывает пикер для выбора даты
  Future<void> _pickDate() async {
    _unfocusKeyboard();
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(_activityDate ?? today);
    // Если выбранная дата в будущем, устанавливаем сегодняшнюю дату
    if (temp.isAfter(today)) {
      temp = today;
    }

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: today.subtract(const Duration(days: 365)),
      maximumDate: today, // Запрещаем выбор даты из будущего
      initialDateTime: temp,
      onDateTimeChanged: (dt) => temp = DateUtils.dateOnly(dt),
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        _activityDate = temp;
      });
    }
  }

  /// Показывает пикер для выбора времени начала
  Future<void> _pickTime() async {
    _unfocusKeyboard();
    DateTime temp = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      _startTime?.hour ?? 12,
      _startTime?.minute ?? 0,
    );

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      use24hFormat: true,
      initialDateTime: temp,
      onDateTimeChanged: (dt) => temp = dt,
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        _startTime = TimeOfDay(hour: temp.hour, minute: temp.minute);
      });
    }
  }

  /// Показывает пикер для выбора длительности (часы, минуты, секунды)
  Future<void> _pickDuration() async {
    _unfocusKeyboard();
    int tempHours = _duration?.inHours.clamp(0, 23) ?? 0;
    int tempMinutes = _duration?.inMinutes.remainder(60) ?? 0;
    int tempSeconds = _duration?.inSeconds.remainder(60) ?? 0;

    final picker = _DurationPicker(
      initialHours: tempHours,
      initialMinutes: tempMinutes,
      initialSeconds: tempSeconds,
      onChanged: (hours, minutes, seconds) {
        tempHours = hours;
        tempMinutes = minutes;
        tempSeconds = seconds;
      },
    );

    final ok = await _showCupertinoSheet<bool>(child: picker) ?? false;
    if (ok) {
      setState(() {
        _duration = Duration(
          hours: tempHours,
          minutes: tempMinutes,
          seconds: tempSeconds,
        );
      });
    }
  }

  /// Показывает Cupertino bottom sheet с пикером
  Future<T?> _showCupertinoSheet<T>({required Widget child}) {
    return showCupertinoModalPopup<T>(
      context: context,
      useRootNavigator: true,
      builder: (sheetCtx) => SafeArea(
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
                // ПАНЕЛЬ С КНОПКАМИ
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
                        child: const Text('Отмена'),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => Navigator.of(sheetCtx).pop(true),
                        child: const Text('Готово'),
                      ),
                    ],
                  ),
                ),
                // Пикер с фиксированной высотой (предотвращает зависание)
                SizedBox(height: 260, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Преобразует тип активности в тип эквипа
  String _activityTypeToEquipmentType(String activityType) {
    final String type = activityType.toLowerCase();
    if (type == 'run' || type == 'running') {
      return 'boots';
    } else if (type == 'bike' || type == 'cycling' || type == 'bicycle') {
      return 'bike';
    }
    return '';
  }

  /// Сохраняет активность на сервер
  Future<void> _saveActivity() async {
    final formState = ref.read(formStateProvider);
    if (formState.isSubmitting) return;

    // Валидация
    // Если GPX файл не загружен, требуется выбор вида тренировки
    if (_gpxFile == null && _selectedActivityType == null) {
      ref
          .read(formStateProvider.notifier)
          .setError('Выберите вид тренировки или загрузите GPX файл');
      return;
    }

    final formNotifier = ref.read(formStateProvider.notifier);

    await formNotifier.submit(
      () async {
        final auth = ref.read(authServiceProvider);
        final userId = await auth.getUserId();
        if (userId == null) {
          throw Exception('Не удалось определить пользователя');
        }

        // Форматируем даты в формат MySQL (используем текущее время)
        String formatDateTime(DateTime dt) {
          return '${dt.year}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}:'
              '${dt.second.toString().padLeft(2, '0')}';
        }

        // Если загружен GPX файл, используем временные значения (будут обновлены после парсинга)
        // Иначе используем выбранные значения или значения по умолчанию
        DateTime dateStart;
        DateTime dateEnd;
        String params;
        String points;
        double distanceKm;

        if (_gpxFile != null) {
          // При загрузке GPX файла используем временные значения
          // Они будут обновлены после парсинга GPX файла
          final now = DateTime.now();
          dateStart = now;
          dateEnd = now.add(const Duration(hours: 1));

          // Временные параметры (будут заменены после парсинга GPX)
          params = jsonEncode([
            {
              'stats': {
                'distance': 0.0,
                'realDistance': 0.0,
                'avgSpeed': 0.0,
                'avgPace': 0.0,
                'duration': 0,
              },
            },
          ]);
          points = jsonEncode([]);
          distanceKm = 0.0;
        } else {
          // Используем выбранные дату и время, или текущее время по умолчанию
          // Если длительность не выбрана, используем 1 час по умолчанию
          final duration = _duration ?? const Duration(hours: 1);

          final activityDate = _activityDate;
          final startTime = _startTime;
          if (activityDate != null && startTime != null) {
            dateStart = DateTime(
              activityDate.year,
              activityDate.month,
              activityDate.day,
              startTime.hour,
              startTime.minute,
            );
            dateEnd = dateStart.add(duration);
          } else {
            // Если дата/время не выбраны, используем текущее время
            final now = DateTime.now();
            dateStart = now;
            dateEnd = now.add(duration);
          }

          // Получаем дистанцию из поля ввода (в километрах)
          distanceKm =
              double.tryParse(
                _distanceController.text.trim().replaceAll(',', '.'),
              ) ??
              0.0;
          final distanceMeters = (distanceKm * 1000).round();

          // Рассчитываем темп (минуты на километр)
          double avgPace = 0.0;
          if (distanceKm > 0 && duration.inSeconds > 0) {
            // Темп = (время в секундах / дистанция в км) / 60 (чтобы получить минуты)
            avgPace = (duration.inSeconds / distanceKm) / 60.0;
          }

          // Рассчитываем среднюю скорость (км/ч)
          double avgSpeed = 0.0;
          if (distanceKm > 0 && duration.inSeconds > 0) {
            avgSpeed = (distanceKm / duration.inSeconds) * 3600.0;
          }

          // Формируем params с рассчитанными значениями
          params = jsonEncode([
            {
              'stats': {
                'distance': distanceMeters.toDouble(),
                'realDistance': distanceMeters.toDouble(),
                'avgSpeed': avgSpeed,
                'avgPace': avgPace,
                'duration': duration.inSeconds,
              },
            },
          ]);

          // Формируем points (пустой массив)
          points = jsonEncode([]);
        }

        final dateStartStr = formatDateTime(dateStart);
        final dateEndStr = formatDateTime(dateEnd);

        // Получаем equip_user_id из выбранной экипировки
        int equipUserId = 0;
        if (_showEquipment && _selectedEquipment != null) {
          equipUserId = _selectedEquipment!.equipUserId ?? 0;
        }

        // Определяем тип активности
        // Если GPX файл загружен, используем 'run' по умолчанию (будет определен из файла)
        // Иначе используем выбранный тип
        final activityType = _gpxFile != null
            ? 'run' // По умолчанию для GPX, может быть определен из файла
            : (_activityTypeMap[_selectedActivityType] ?? 'run');

        // Создаем активность через новый API endpoint
        final api = ref.read(apiServiceProvider);
        final response = await api.post(
          '/create_activity_from_form.php',
          body: {
            'user_id': userId.toString(),
            'type': activityType,
            'date_start': dateStartStr,
            'date_end': dateEndStr,
            'params': params,
            'points': points,
            'privacy': _selectedVisibility.toString(),
            'equip_user_id': equipUserId.toString(),
            'distance_km': distanceKm.toString(),
            'content': _descriptionController.text.trim(),
          },
        );

        if (response['success'] != true) {
          final message =
              response['message']?.toString() ??
              'Не удалось создать тренировку';
          throw Exception(message);
        }

        final activityId = response['activity_id'] as int?;
        final lentaId = response['lenta_id'] as int?;

        if (activityId == null) {
          throw Exception('Не удалось получить ID созданной тренировки');
        }

        // Загружаем GPX файл, если он есть
        if (_gpxFile != null) {
          await _uploadGpxFile(activityId, userId);
        }

        // Загружаем фотографии, если они есть
        if (_images.isNotEmpty) {
          await _uploadPhotos(activityId, userId);
        }

        // Обновляем ленту
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .forceRefresh();

        // Небольшая задержка для гарантии обновления данных на сервере
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Получаем созданную активность из обновленного провайдера
        final lentaState = ref.read(lentaProvider(widget.currentUserId));
        al.Activity? createdActivity;

        try {
          createdActivity = lentaState.items.firstWhere(
            (a) => a.id == activityId || a.lentaId == (lentaId ?? 0),
          );
        } catch (e) {
          // Если активность не найдена, пробуем еще раз после небольшой задержки
          await Future.delayed(const Duration(milliseconds: 300));
          final updatedState = ref.read(lentaProvider(widget.currentUserId));
          try {
            createdActivity = updatedState.items.firstWhere(
              (a) => a.id == activityId || a.lentaId == (lentaId ?? 0),
            );
          } catch (e2) {
            // Если все еще не найдена, просто закрываем экран
            if (!mounted) return;
            Navigator.of(context).pop(true);
            return;
          }
        }

        // После всех проверок createdActivity гарантированно не null
        // (если не найдена, происходит return выше)
        if (!mounted) return;
        // Закрываем экран добавления
        Navigator.of(context).pop();

        // Открываем экран описания тренировки
        Navigator.of(context, rootNavigator: true).push(
          TransparentPageRoute(
            builder: (_) => ActivityDescriptionPage(
              activity: createdActivity!,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;
        final formState = ref.read(formStateProvider);
        _showError(formState.error ?? 'Ошибка при создании тренировки');
      },
    );
  }

  /// Загружает GPX файл для активности
  Future<void> _uploadGpxFile(int activityId, int userId) async {
    final gpxFile = _gpxFile;
    if (gpxFile == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/upload_activity_gpx.php',
        files: {'file': gpxFile},
        fields: {
          'user_id': userId.toString(),
          'activity_id': activityId.toString(),
        },
        timeout: const Duration(minutes: 2),
      );

      if (response['success'] != true) {
        // Не бросаем исключение, так как это не критично для создания активности
      }
    } catch (e) {
      // Ошибка загрузки GPX файла не критична
    }
  }

  /// Загружает фотографии для активности
  Future<void> _uploadPhotos(int activityId, int userId) async {
    // Фильтруем только локальные файлы (File)
    final filesToUpload = <File>[];
    for (final image in _images) {
      if (image is File) {
        filesToUpload.add(image);
      }
    }

    if (filesToUpload.isEmpty) return;

    try {
      final filesForUpload = <String, File>{};
      for (var i = 0; i < filesToUpload.length; i++) {
        filesForUpload['file$i'] = filesToUpload[i];
      }

      final api = ref.read(apiServiceProvider);
      final response = await api.postMultipart(
        '/upload_activity_photos.php',
        files: filesForUpload,
        fields: {
          'user_id': userId.toString(),
          'activity_id': activityId.toString(),
        },
        timeout: const Duration(minutes: 2),
      );

      if (response['success'] == true) {
        // Фотографии успешно загружены
      }
    } catch (e) {
      // Ошибка загрузки фотографий не критична
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

  /// Обработчик добавления фотографий к тренировке
  Future<void> _handleAddPhotos() async {
    try {
      // ── выбираем и обрезаем изображения для высоты 350px (динамическое соотношение)
      // Используем стандартный pickMultiImage, затем обрезаем каждое
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: ImagePickerHelper.maxPickerDimension,
        maxHeight: ImagePickerHelper.maxPickerDimension,
        imageQuality: ImagePickerHelper.pickerImageQuality,
      );
      if (pickedFiles.isEmpty || !mounted) return;

      // Рассчитываем соотношение сторон на основе ширины экрана
      final screenWidth = MediaQuery.of(context).size.width;
      final aspectRatio = screenWidth / 350.0;

      // ── обрезаем и сжимаем все выбранные изображения
      final compressedFiles = <File>[];
      for (int i = 0; i < pickedFiles.length; i++) {
        if (!mounted) return;

        final picked = pickedFiles[i];
        // Обрезаем изображение для высоты 350px (динамическое соотношение)
        final cropped = await ImagePickerHelper.cropPickedImage(
          context: context,
          source: picked,
          aspectRatio: aspectRatio,
          title: 'Обрезка фотографии ${i + 1}',
        );

        if (cropped == null) {
          continue; // Пропускаем, если пользователь отменил обрезку
        }

        // Сжимаем обрезанное изображение
        final compressed = await compressLocalImage(
          sourceFile: cropped,
          maxSide: ImageCompressionPreset.activity.maxSide,
          jpegQuality: ImageCompressionPreset.activity.quality,
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
        _images.addAll(compressedFiles);
      });
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    }
  }

  /// Обработчик удаления фотографии
  void _handleDeletePhoto(Object image) {
    setState(() {
      _images.remove(image);
    });
  }

  /// Обработчик выбора GPX файла
  Future<void> _handlePickGpxFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name.toLowerCase();

        // Проверяем, что выбранный файл имеет расширение .gpx
        if (!fileName.endsWith('.gpx')) {
          if (mounted) {
            _showError('Пожалуйста, выберите файл с расширением .gpx');
          }
          return;
        }

        final file = File(filePath);
        setState(() {
          _gpxFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError(e);
      }
    }
  }
}

/// ────────────────────────────────────────────────────────────────
/// 🔹 КАСТОМНЫЙ ПИКЕР ДЛИТЕЛЬНОСТИ (часы, минуты, секунды)
/// ────────────────────────────────────────────────────────────────
/// Использует три CupertinoPicker для выбора часов, минут и секунд
/// ────────────────────────────────────────────────────────────────
class _DurationPicker extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final int initialSeconds;
  final Function(int hours, int minutes, int seconds) onChanged;

  const _DurationPicker({
    required this.initialHours,
    required this.initialMinutes,
    required this.initialSeconds,
    required this.onChanged,
  });

  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;

  int _currentHours = 0;
  int _currentMinutes = 0;
  int _currentSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentHours = widget.initialHours;
    _currentMinutes = widget.initialMinutes;
    _currentSeconds = widget.initialSeconds;
    _hoursController = FixedExtentScrollController(
      initialItem: widget.initialHours,
    );
    _minutesController = FixedExtentScrollController(
      initialItem: widget.initialMinutes,
    );
    _secondsController = FixedExtentScrollController(
      initialItem: widget.initialSeconds,
    );
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _updateDuration(int hours, int minutes, int seconds) {
    setState(() {
      _currentHours = hours;
      _currentMinutes = minutes;
      _currentSeconds = seconds;
    });
    widget.onChanged(hours, minutes, seconds);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Часы (0-23)
          SizedBox(
            width: 60,
            child: CupertinoPicker(
              scrollController: _hoursController,
              itemExtent: 32,
              onSelectedItemChanged: (index) {
                _updateDuration(index, _currentMinutes, _currentSeconds);
              },
              children: List.generate(
                24,
                (i) => Center(
                  child: Text(
                    '$i',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'ч',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Минуты (0-59)
          SizedBox(
            width: 60,
            child: CupertinoPicker(
              scrollController: _minutesController,
              itemExtent: 32,
              onSelectedItemChanged: (index) {
                _updateDuration(_currentHours, index, _currentSeconds);
              },
              children: List.generate(
                60,
                (i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'мин',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Секунды (0-59)
          SizedBox(
            width: 60,
            child: CupertinoPicker(
              scrollController: _secondsController,
              itemExtent: 32,
              onSelectedItemChanged: (index) {
                _updateDuration(_currentHours, _currentMinutes, index);
              },
              children: List.generate(
                60,
                (i) => Center(
                  child: Text(
                    i.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'сек',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w400,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
