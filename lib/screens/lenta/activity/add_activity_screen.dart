// lib/screens/lenta/activity/add_activity_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/interactive_back_swipe.dart';
import '../../../widgets/primary_button.dart';
import '../../../models/activity_lenta.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import '../../../providers/lenta/lenta_provider.dart';

import '../widgets/activity/equipment/equipment_chip.dart';

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

  // Тип тренировки: "Бег", "Велосипед", "Плавание"
  String? _selectedActivityType;
  static const List<String> _activityTypes = ['Бег', 'Велосипед', 'Плавание'];
  static const Map<String, String> _activityTypeMap = {
    'Бег': 'run',
    'Велосипед': 'bike',
    'Плавание': 'swim',
  };

  // Дата и время тренировки
  DateTime? _activityDate;
  TimeOfDay? _startTime;
  Duration? _duration; // По умолчанию не выбрана

  // Состояние видимости: 0 = Все пользователи, 1 = Только подписчики, 2 = Только Вы
  int _selectedVisibility = 0;

  // Экипировка
  bool _showEquipment = false;
  List<Equipment> _availableEquipment = [];
  Equipment? _selectedEquipment;
  bool _isLoadingEquipment = false;

  bool _isLoading = false;

  // Список фотографий (для отображения в карусели)
  // Может содержать как локальные файлы (File), так и URL (String)
  final List<dynamic> _images = [];

  // Индекс перетаскиваемой фотографии
  int? _draggedIndex;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
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
                  // 🏃 2. ТИП ТРЕНИРОВКИ (выпадающий список)
                  // ────────────────────────────────────────────────────────────────
                  const Text(
                    'Тип тренировки',
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

                  const Text(
                    'Длительность',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildDurationField(),

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
                              checkColor: AppColors.surface, // Цвет галочки
                              side: const BorderSide(
                                color: AppColors
                                    .iconSecondary, // Более светлый цвет границы
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
        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
          color: AppColors.background,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(
            CupertinoIcons.photo,
            size: 28,
            color: AppColors.iconTertiary,
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
        onWillAccept: (data) => data != image,
        onAccept: (data) {
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
                  color: AppColors.background,
                  border: Border.all(
                    color: isDragging
                        ? AppColors.brandPrimary
                        : AppColors.border,
                    width: isDragging ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: image is File
                    ? Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.iconSecondary,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: image as String,
                        fit: BoxFit.cover,
                        memCacheWidth: w,
                        maxWidthDiskCache: w,
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                          child: const Center(
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.background,
                          child: const Icon(
                            CupertinoIcons.photo,
                            size: 24,
                            color: AppColors.iconSecondary,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
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

  /// Выпадающий список для выбора типа тренировки
  Widget _buildActivityTypeSelector() {
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedActivityType,
          isExpanded: true,
          hint: const Text(
            'Выберите тип тренировки',
            style: AppTextStyles.h14w4Place,
          ),
          onChanged: (String? newValue) {
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
          },
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.iconSecondary,
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
    );
  }

  /// Поле выбора даты тренировки
  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                CupertinoIcons.calendar,
                size: 18,
                color: AppColors.iconPrimary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 18 + 14,
              minHeight: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
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
    );
  }

  /// Поле выбора времени начала
  Widget _buildTimeField() {
    return GestureDetector(
      onTap: _pickTime,
      child: AbsorbPointer(
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                CupertinoIcons.time,
                size: 18,
                color: AppColors.iconPrimary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 18 + 14,
              minHeight: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
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
    );
  }

  /// Поле выбора длительности тренировки
  Widget _buildDurationField() {
    return GestureDetector(
      onTap: _pickDuration,
      child: AbsorbPointer(
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                CupertinoIcons.timer,
                size: 18,
                color: AppColors.iconPrimary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 18 + 14,
              minHeight: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Text(
            _formatDuration(_duration).isEmpty
                ? 'Выберите длительность'
                : _formatDuration(_duration),
            style: _duration != null
                ? AppTextStyles.h14w4
                : AppTextStyles.h14w4Place,
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
      decoration: InputDecoration(
        hintText: 'Введите описание тренировки',
        hintStyle: AppTextStyles.h14w4Place,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
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
          style: AppTextStyles.h14w4.copyWith(color: AppColors.textSecondary),
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
        onEquipmentChanged: () {
          // После изменения экипировки обновляем список
          _loadEquipment();
        },
      );
    }

    // Если экипировка не выбрана, показываем выпадающий список для выбора
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Equipment>(
          value: _selectedEquipment,
          isExpanded: true,
          hint: const Text('Выберите экипировку', style: AppTextStyles.h14w4),
          onChanged: (Equipment? newValue) {
            setState(() {
              _selectedEquipment = newValue;
            });
          },
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.iconSecondary,
          ),
          items: _availableEquipment.map((equipment) {
            final displayName = equipment.brand.isNotEmpty
                ? '${equipment.brand} ${equipment.name}'
                : equipment.name;
            return DropdownMenuItem<Equipment>(
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
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
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
          dropdownColor: AppColors.surface,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(AppRadius.md),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: AppColors.iconSecondary,
          ),
          style: AppTextStyles.h14w4,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option, style: AppTextStyles.h14w4),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Кнопка сохранения
  Widget _buildSaveButton() {
    return PrimaryButton(
      text: 'Сохранить',
      onPressed: !_isLoading ? _saveActivity : () {},
      width: 190,
      isLoading: _isLoading,
      enabled: true,
    );
  }

  /// Загружает список экипировки для выбранного типа тренировки
  Future<void> _loadEquipment() async {
    if (_selectedActivityType == null) return;

    setState(() {
      _isLoadingEquipment = true;
    });

    try {
      final api = ApiService();
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
        final List<Equipment> allEquipment = equipmentList
            .map(
              (item) => Equipment.fromJson({
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
    if (minutes > 0) parts.add('$minutes мин');
    if (seconds > 0 || parts.isEmpty) parts.add('$seconds сек');

    return parts.join(' ');
  }

  /// Показывает пикер для выбора даты
  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    DateTime temp = DateUtils.dateOnly(_activityDate ?? today);

    final picker = CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      minimumDate: today,
      maximumDate: today.add(const Duration(days: 365 * 2)),
      initialDateTime: temp.isBefore(today) ? today : temp,
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
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 0),
                // ПАНЕЛЬ С КНОПКАМИ
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
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
    if (_isLoading) return;

    // Валидация
    if (_selectedActivityType == null) {
      _showError('Выберите тип тренировки');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = AuthService();
      final userId = await auth.getUserId();
      if (userId == null) {
        if (mounted) {
          _showError('Не удалось определить пользователя');
        }
        return;
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

      // Используем выбранные дату и время, или текущее время по умолчанию
      DateTime dateStart;
      DateTime dateEnd;

      // Если длительность не выбрана, используем 1 час по умолчанию
      final duration = _duration ?? const Duration(hours: 1);

      if (_activityDate != null && _startTime != null) {
        dateStart = DateTime(
          _activityDate!.year,
          _activityDate!.month,
          _activityDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        dateEnd = dateStart.add(duration);
      } else {
        // Если дата/время не выбраны, используем текущее время
        final now = DateTime.now();
        dateStart = now;
        dateEnd = now.add(duration);
      }

      final dateStartStr = formatDateTime(dateStart);
      final dateEndStr = formatDateTime(dateEnd);

      // Формируем params (минимальные stats)
      final params = jsonEncode([
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

      // Формируем points (пустой массив)
      final points = jsonEncode([]);

      // Получаем equip_id из выбранной экипировки
      int equipId = 0;
      if (_showEquipment && _selectedEquipment != null) {
        equipId = _selectedEquipment!.equipUserId ?? 0;
      }

      // Сначала создаем активность
      final api = ApiService();
      final response = await api.post(
        '/create_activity.php',
        body: {
          'user_id': userId.toString(),
          'type': _activityTypeMap[_selectedActivityType] ?? 'run',
          'date_start': dateStartStr,
          'date_end': dateEndStr,
          'params': params,
          'points': points,
          'privacy': _selectedVisibility.toString(),
          'equip_id': equipId.toString(),
          'content': _descriptionController.text.trim(),
          'media': '',
        },
      );

      if (response['success'] == true) {
        final activityId = response['activity_id'] as int?;
        if (activityId != null && _images.isNotEmpty) {
          // Загружаем фотографии, если они есть
          await _uploadPhotos(activityId, userId);
        }

        // Обновляем ленту
        await ref
            .read(lentaProvider(widget.currentUserId).notifier)
            .forceRefresh();

        if (mounted) {
          Navigator.of(context).pop(true); // Возвращаемся с флагом успеха
        }
      } else {
        final message =
            response['message']?.toString() ?? 'Не удалось создать тренировку';
        if (mounted) {
          _showError(message);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка при создании тренировки: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

      final api = ApiService();
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
        debugPrint('✅ Photos uploaded successfully');
      } else {
        debugPrint('⚠️ Failed to upload photos: ${response['message']}');
      }
    } catch (e) {
      // Ошибка загрузки фотографий не критична
      debugPrint('⚠️ Failed to upload activity photos: $e');
    }
  }

  /// Показывает ошибку
  void _showError(String message) {
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
    final picker = ImagePicker();

    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;

      // Сохраняем выбранные файлы локально
      final files = pickedFiles.map((file) => File(file.path)).toList();
      setState(() {
        _images.addAll(files);
      });
    } on PlatformException catch (e) {
      if (mounted) {
        _showError(
          'Нет доступа к галерее: ${e.message ?? 'неизвестная ошибка'}.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Не удалось загрузить фотографии. Попробуйте ещё раз.');
      }
    }
  }

  /// Обработчик удаления фотографии
  void _handleDeletePhoto(Object image) {
    setState(() {
      _images.remove(image);
    });
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
                (i) => Center(child: Text('$i', style: AppTextStyles.h17w6)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('ч', style: AppTextStyles.h14w4),
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
                    style: AppTextStyles.h18w6,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('мин', style: AppTextStyles.h14w4),
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
                    style: AppTextStyles.h17w6,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('сек', style: AppTextStyles.h14w4),
          ),
        ],
      ),
    );
  }
}
