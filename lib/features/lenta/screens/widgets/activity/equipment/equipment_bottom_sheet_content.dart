// lib/features/lenta/screens/widgets/activity/equipment/
// equipment_bottom_sheet_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../domain/models/activity_lenta.dart' as al;
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../profile/screens/tabs/equipment/adding/tabs/sneakers_step1_screen.dart';
import '../../../../../profile/screens/tabs/equipment/adding/tabs/bike_step1_screen.dart';

/// Контент для bottom sheet экипировки с горизонтальной каруселью.
class EquipmentBottomSheetContent extends ConsumerStatefulWidget {
  final List<al.Equipment> currentItems;
  final int userId;
  final String activityType;
  final int activityId;
  final double activityDistance;
  final VoidCallback? onEquipmentChanged;
  final VoidCallback onDone;

  const EquipmentBottomSheetContent({
    super.key,
    required this.currentItems,
    required this.userId,
    required this.activityType,
    required this.activityId,
    required this.activityDistance,
    required this.onDone,
    this.onEquipmentChanged,
  });

  @override
  ConsumerState<EquipmentBottomSheetContent> createState() =>
      _EquipmentBottomSheetContentState();
}

class _EquipmentBottomSheetContentState
    extends ConsumerState<EquipmentBottomSheetContent> {
  // ────────────────────────────────────────────────────────────────
  // 📦 ЛОКАЛЬНОЕ СОСТОЯНИЕ: список экипировки, загрузка, ошибка
  // ────────────────────────────────────────────────────────────────
  List<al.Equipment> _allEquipment = [];
  bool _isLoading = true;
  String? _error;
  bool _didPrecache = false;
  al.Equipment? _selectedEquipment;
  // ────────────────────────────────────────────────────────────────
  // 🎯 МАРКЕРЫ: специальные значения для карточек действий
  // ────────────────────────────────────────────────────────────────
  static const int _addSneakersMarker = -999;

  // ────────────────────────────────────────────────────────────────
  // 📐 РАЗМЕРЫ КАРТОЧЕК: стабильная высота для карусели
  // ────────────────────────────────────────────────────────────────
  static const double _cardWidth = 220;
  static const double _cardHeight = 220;
  static const double _imageSize = 140;

  // ────────────────────────────────────────────────────────────────
  // 🎬 ПЛЕЙСХОЛДЕРЫ: количество карточек при загрузке
  // ────────────────────────────────────────────────────────────────
  static const int _placeholderCardCount = 4;

  @override
  void initState() {
    super.initState();
    // ────────────────────────────────────────────────────────────────
    // 🎯 ИНИЦИАЛИЗАЦИЯ: выделяем текущую экипировку по умолчанию
    // ────────────────────────────────────────────────────────────────
    if (widget.currentItems.isNotEmpty) {
      _selectedEquipment = widget.currentItems.first;
    }
    _loadAllEquipment();
  }

  /// ────────────────────────────────────────────────────────────────
  /// 📡 ЗАГРУЗКА ЭКИПИРОВКИ: получаем весь список из API по типу
  /// ────────────────────────────────────────────────────────────────
  Future<void> _loadAllEquipment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ────────────────────────────────────────────────────────────────
      // 🔁 ПРЕОБРАЗУЕМ ТИП АКТИВНОСТИ В ТИП ЭКИПИРОВКИ
      // ────────────────────────────────────────────────────────────────
      final String equipmentType = _activityTypeToEquipmentType(
        widget.activityType,
      );

      if (equipmentType.isEmpty) {
        // ────────────────────────────────────────────────────────────────
        // ⚠️ НЕПОДДЕРЖИВАЕМЫЙ ТИП: показываем только текущий эквип
        // ────────────────────────────────────────────────────────────────
        setState(() {
          _allEquipment = widget.currentItems;
          _isLoading = false;
        });
        return;
      }

      // ────────────────────────────────────────────────────────────────
      // 🌐 API: загружаем весь эквип пользователя
      // ────────────────────────────────────────────────────────────────
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.userId.toString()},
      );

      if (data['success'] == true) {
        // ────────────────────────────────────────────────────────────────
        // ✅ МАППИНГ В МОДЕЛЬ: boots или bikes
        // ────────────────────────────────────────────────────────────────
        final List<dynamic> equipmentList =
            equipmentType == 'boots' ? data['boots'] ?? [] : data['bikes'] ?? [];
        final List<al.Equipment> allEquipment =
            equipmentList.map((item) {
              return al.Equipment.fromJson({
                'name': item['name'] ?? '',
                'brand': item['brand'] ?? '',
                'mileage': item['dist'] ?? 0,
                'img': item['image'] ?? '',
                'main': item['main'] ?? false,
                'myraiting': 0.0,
                'type': equipmentType,
                'equip_user_id': item['equip_user_id'],
              });
            }).toList();

        if (mounted) {
          setState(() {
            _allEquipment = allEquipment;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Не удалось загрузить экипировку';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHandler.formatWithContext(
            e,
            context: 'загрузке экипировки',
          );
          _isLoading = false;
        });
      }
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🔁 ПРЕОБРАЗОВАНИЕ ТИПА: run -> boots, bike -> bike
  /// ────────────────────────────────────────────────────────────────
  String _activityTypeToEquipmentType(String activityType) {
    final String type = activityType.toLowerCase();
    if (type == 'run' || type == 'running') {
      return 'boots';
    } else if (type == 'bike' || type == 'cycling' || type == 'bicycle') {
      return 'bike';
    }
    return '';
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🚴 ПРОВЕРКА ТИПА: является ли активность велосипедом
  /// ────────────────────────────────────────────────────────────────
  bool get _isBike {
    final type = widget.activityType.toLowerCase();
    return type == 'bike' || type == 'cycling' || type == 'bicycle';
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🟦 ВЫБОР КАРТОЧКИ: выделяем рамкой, шит не закрываем
  /// ────────────────────────────────────────────────────────────────
  void _selectEquipment(al.Equipment newEquipment) {
    setState(() {
      _selectedEquipment = newEquipment;
    });
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🚫 ОТКРЕПЛЕНИЕ ЭКИПИРОВКИ: убираем эквип из тренировки
  /// ────────────────────────────────────────────────────────────────
  Future<void> _detachEquipment() async {
    if (widget.activityId <= 0) {
      widget.onDone();
      return;
    }

    try {
      final auth = ref.read(authServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) {
        widget.onDone();
        return;
      }

      final api = ref.read(apiServiceProvider);
      await api.post(
        '/detach_activity_equipment.php',
        body: {
          'user_id': userId.toString(),
          'activity_id': widget.activityId.toString(),
        },
      );

      widget.onEquipmentChanged?.call();
      widget.onDone();
    } catch (_) {
      widget.onEquipmentChanged?.call();
      widget.onDone();
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// ✅ ПРИМЕНЕНИЕ ВЫБОРА: меняем эквип при нажатии «Готово»
  /// ────────────────────────────────────────────────────────────────
  Future<void> _applySelectedEquipment() async {
    final selected = _selectedEquipment;
    
    // ────────────────────────────────────────────────────────────────
    // ➕ ВЫБРАНО «ДОБАВИТЬ ЭКИПИРОВКУ»: открываем экран добавления
    // ────────────────────────────────────────────────────────────────
    if (selected?.equipUserId == _addSneakersMarker) {
      widget.onDone();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        TransparentPageRoute(
          builder: (_) => _isBike
              ? const BikeStep1Screen()
              : const SneakersStep1Screen(),
        ),
      );
      return;
    }
    
    // ────────────────────────────────────────────────────────────────
    // 🚫 ВЫБРАНО «НЕ ОТОБРАЖАТЬ»: открепляем эквип
    // ────────────────────────────────────────────────────────────────
    if (selected == null) {
      await _detachEquipment();
      return;
    }

    // ────────────────────────────────────────────────────────────────
    // ✅ ПРОВЕРКА: если выбран текущий эквип — просто закрываем
    // ────────────────────────────────────────────────────────────────
    final currentEquipment = widget.currentItems.isNotEmpty
        ? widget.currentItems.first
        : null;
    if (currentEquipment != null &&
        selected.equipUserId != null &&
        selected.equipUserId == currentEquipment.equipUserId) {
      widget.onDone();
      return;
    }

    // ────────────────────────────────────────────────────────────────
    // 🔹 ЕСЛИ АКТИВНОСТЬ НЕ СОХРАНЕНА: ничего не меняем
    // ────────────────────────────────────────────────────────────────
    if (widget.activityId == 0) {
      widget.onDone();
      return;
    }

    if (selected.equipUserId == null ||
        currentEquipment?.equipUserId == null) {
      widget.onDone();
      return;
    }

    try {
      // ────────────────────────────────────────────────────────────────
      // 🔐 USER ID: нужен для API замены эквипа
      // ────────────────────────────────────────────────────────────────
      final auth = ref.read(authServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) {
        widget.onDone();
        return;
      }

      final api = ref.read(apiServiceProvider);
      await api.post(
        '/replace_activity_equipment.php',
        body: {
          'user_id': userId.toString(),
          'activity_id': widget.activityId.toString(),
          'old_equip_user_id': currentEquipment!.equipUserId.toString(),
          'new_equip_user_id': selected.equipUserId.toString(),
          'distance_km': widget.activityDistance.toString(),
        },
      );

      widget.onEquipmentChanged?.call();
      widget.onDone();
    } catch (_) {
      // ────────────────────────────────────────────────────────────────
      // ⚠️ ОШИБКА: закрываем шит и обновляем UI для синхронизации
      // ────────────────────────────────────────────────────────────────
      widget.onEquipmentChanged?.call();
      widget.onDone();
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🖼️ ПРЕФЕТЧ КАРТИНОК: подогреваем кэш для первых карточек
  /// ────────────────────────────────────────────────────────────────
  void _precacheEquipmentImages(BuildContext context) {
    if (_didPrecache || _allEquipment.isEmpty) return;
    _didPrecache = true;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (_imageSize * dpr).round();
    final int limit = _allEquipment.length < 8 ? _allEquipment.length : 8;
    for (var i = 0; i < limit; i++) {
      final img = _allEquipment[i].img;
      if (img.isNotEmpty &&
          (img.startsWith('http://') || img.startsWith('https://'))) {
        precacheImage(
          CachedNetworkImageProvider(
            img,
            maxWidth: targetW,
            maxHeight: targetW,
          ),
          context,
        );
      }
    }
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🏜️ ПЛЕЙСХОЛДЕР КАРТОЧКИ: скелетон при загрузке
  /// ────────────────────────────────────────────────────────────────
  Widget _placeholderCard(BuildContext context) {
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.twinchip,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _imageSize,
            height: _imageSize,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: _cardWidth - AppSpacing.md * 2,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.skeletonGlow,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        ],
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🎠 КАРУСЕЛЬ: единый список для плейсхолдеров и контента
  /// ────────────────────────────────────────────────────────────────
  Widget _buildCarousel(
    BuildContext context, {
    required bool isLoading,
    required String defaultImageAsset,
  }) {
    // ────────────────────────────────────────────────────────────────
    // 📊 КОЛИЧЕСТВО ЭЛЕМЕНТОВ: экипировка + «Не отображать» + «Добавить»
    // ────────────────────────────────────────────────────────────────
    final itemCount = isLoading
        ? _placeholderCardCount
        : _allEquipment.length +
            2; // +1 для «Не отображать», +1 для «Добавить кроссовки»
    final scrollPhysics = isLoading
        ? const NeverScrollableScrollPhysics()
        : const BouncingScrollPhysics();

    return SizedBox(
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: scrollPhysics,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (isLoading) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox(
                key: ValueKey('placeholder_$index'),
                child: _placeholderCard(context),
              ),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // 🚫 ПРЕДПОСЛЕДНИЙ ЭЛЕМЕНТ: карточка «Не отображать»
          // ────────────────────────────────────────────────────────────────
          if (index == _allEquipment.length) {
            final isSelected = _selectedEquipment == null;
            final card = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedEquipment = null;
                });
              },
              child: _hideEquipmentCard(
                context,
                isSelected: isSelected,
              ),
            );

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox(
                key: const ValueKey('hide_equipment'),
                child: card,
              ),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // ➕ ПОСЛЕДНИЙ ЭЛЕМЕНТ: карточка «Добавить экипировку»
          // ────────────────────────────────────────────────────────────────
          if (index == _allEquipment.length + 1) {
            final isSelected = _selectedEquipment?.equipUserId == _addSneakersMarker;
            final card = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _selectedEquipment = al.Equipment.fromJson({
                    'name': '',
                    'brand': '',
                    'mileage': 0,
                    'img': '',
                    'main': false,
                    'myraiting': 0.0,
                    'type': _isBike ? 'bike' : 'boots',
                    'equip_user_id': _addSneakersMarker,
                  });
                });
              },
              child: _addEquipmentCard(
                context,
                isSelected: isSelected,
              ),
            );

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: SizedBox(
                key: const ValueKey('add_sneakers'),
                child: card,
              ),
            );
          }

          // ────────────────────────────────────────────────────────────────
          // 📦 ОБЫЧНАЯ КАРТОЧКА ЭКИПИРОВКИ
          // ────────────────────────────────────────────────────────────────
          final item = _allEquipment[index];
          final isSelected = _selectedEquipment?.equipUserId != null &&
              _selectedEquipment?.equipUserId == item.equipUserId;
          final card = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectEquipment(item),
            child: _equipmentCard(
              context,
              item: item,
              defaultImageAsset: defaultImageAsset,
              isSelected: isSelected,
            ),
          );

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: SizedBox(
              key: ValueKey('item_${item.equipUserId ?? index}'),
              child: card,
            ),
          );
        },
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// ➕ КАРТОЧКА «ДОБАВИТЬ ЭКИПИРОВКУ»: переход на экран добавления
  /// ────────────────────────────────────────────────────────────────
  Widget _addEquipmentCard(BuildContext context, {required bool isSelected}) {
    final imageAsset = _isBike ? 'assets/adding-bike.jpg' : 'assets/adding-sneakers.jpg';
    final title = _isBike ? 'Добавить велосипед' : 'Добавить кроссовки';
    
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isSelected ? AppColors.button : AppColors.twinchip,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                width: _imageSize - 20,
                height: _imageSize - 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h13w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🚫 КАРТОЧКА «НЕ ОТОБРАЖАТЬ»: скрытие экипировки
  /// ────────────────────────────────────────────────────────────────
  Widget _hideEquipmentCard(BuildContext context, {required bool isSelected}) {
    final imageAsset = _isBike ? 'assets/without_bike.png' : 'assets/without_sneakers.png';
    
    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isSelected ? AppColors.button : AppColors.twinchip,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ────────────────────────────────────────────────────────────────
          // 🖼️ ИЗОБРАЖЕНИЕ: без экипировки
          // ────────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.contain,
                width: _imageSize - 20,
                height: _imageSize - 20,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // ────────────────────────────────────────────────────────────────
          // 🧾 ТЕКСТ: название
          // ────────────────────────────────────────────────────────────────
          Text(
            'Не отображать',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h13w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Экипировка будет удалена',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h12w4Sec.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// 🧩 КАРТОЧКА ЭКИПИРОВКИ: картинка + название + пробег
  /// ────────────────────────────────────────────────────────────────
  Widget _equipmentCard(
    BuildContext context, {
    required al.Equipment item,
    required String defaultImageAsset,
    required bool isSelected,
  }) {
    final displayName = (item.brand.isNotEmpty && item.name.isNotEmpty)
        ? '${item.brand} ${item.name}'
        : item.name;
    final hasValidImageUrl =
        item.img.isNotEmpty &&
        (item.img.startsWith('http://') || item.img.startsWith('https://'));

    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isSelected ? AppColors.button : AppColors.twinchip,
          width: isSelected ? 1.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ────────────────────────────────────────────────────────────────
          // 🖼️ ИЗОБРАЖЕНИЕ: сетевое или дефолтное
          // ────────────────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: hasValidImageUrl
                ? CachedNetworkImage(
                    imageUrl: item.img,
                    fit: BoxFit.contain,
                    width: _imageSize,
                    height: _imageSize,
                    fadeInDuration: const Duration(milliseconds: 600),
                    fadeInCurve: Curves.easeInOut,
                    placeholder: (context, url) => Container(
                      width: _imageSize,
                      height: _imageSize,
                      color: AppColors.getBackgroundColor(context),
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      defaultImageAsset,
                      fit: BoxFit.contain,
                      width: _imageSize,
                      height: _imageSize,
                    ),
                  )
                : Image.asset(
                    defaultImageAsset,
                    fit: BoxFit.contain,
                    width: _imageSize,
                    height: _imageSize,
                  ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // ────────────────────────────────────────────────────────────────
          // 🧾 ТЕКСТ: название и пробег
          // ────────────────────────────────────────────────────────────────
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h13w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Пробег: ${item.mileage} км',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h12w4Sec.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  /// ────────────────────────────────────────────────────────────────
  /// ✅ КНОПКА «ГОТОВО»: закрываем bottom sheet
  /// ────────────────────────────────────────────────────────────────
  Widget _doneButton(BuildContext context) {
    final textColor = AppColors.getSurfaceColor(context);
    return ElevatedButton(
      onPressed: _applySelectedEquipment,
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
      child: Text(
        'Готово',
        style: AppTextStyles.h15w5.copyWith(
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 📦 ПРЕФЕТЧ: запускаем один раз после загрузки списка
    // ────────────────────────────────────────────────────────────────
    if (!_isLoading && _error == null) {
      _precacheEquipmentImages(context);
    }

    // ────────────────────────────────────────────────────────────────
    // 🖼️ ДЕФОЛТНОЕ ИЗОБРАЖЕНИЕ ПО ТИПУ
    // ────────────────────────────────────────────────────────────────
    final isBike =
        widget.activityType.toLowerCase() == 'bike' ||
        widget.activityType.toLowerCase() == 'cycling' ||
        widget.activityType.toLowerCase() == 'bicycle';
    final String defaultImageAsset = isBike
        ? 'assets/add_bike.png'
        : 'assets/add_boots.png';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        4,
        0,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ────────────────────────────────────────────────────────────────
          // 📝 ПОДЗАГОЛОВОК: описание под заголовком
          // ────────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(
              bottom: 20,
              left: AppSpacing.md,
              right: AppSpacing.md,
            ),
            child: Text(
              isBike
                  ? 'Укажите, на каком велосипеде прошла тренировка'
                  : 'Укажите, в каких кроссовках прошла тренировка',
              textAlign: TextAlign.center,
              style: AppTextStyles.h13w4.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          ),
          // ────────────────────────────────────────────────────────────────
          // ⏳ ЗАГРУЗКА: плейсхолдеры карточек
          // ────────────────────────────────────────────────────────────────
          if (_error != null)
            // ────────────────────────────────────────────────────────────────
            // ❌ ОШИБКА: показываем SelectableText.rich
            // ────────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.md,
              ),
              child: SelectableText.rich(
                TextSpan(
                  text: _error!,
                  style: AppTextStyles.h12w4.copyWith(
                    color: AppColors.error,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else if (!_isLoading && _allEquipment.isEmpty)
            // ────────────────────────────────────────────────────────────────
            // 📭 ПУСТОЕ СОСТОЯНИЕ
            // ────────────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.md,
              ),
              child: Text(
                'Экипировка не найдена',
                textAlign: TextAlign.center,
                style: AppTextStyles.h12w4Sec.copyWith(
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            )
          else
            // ────────────────────────────────────────────────────────────────
            // 🎠 КАРУСЕЛЬ: одна и та же лента для loading/контента
            // ────────────────────────────────────────────────────────────────
            _buildCarousel(
              context,
              isLoading: _isLoading,
              defaultImageAsset: defaultImageAsset,
            ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: _doneButton(context),
          ),
        ],
      ),
    );
  }
}
