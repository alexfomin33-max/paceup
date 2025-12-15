// lib/screens/profile/tabs/equipment/equipment_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
//                                Вкладка «Снаряжение»
//  Загружает снаряжение пользователя из API и отображает его
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adding/adding_equipment_screen.dart';
import 'viewing/viewing_equipment_screen.dart';
import '../../../../../core/widgets/primary_button.dart';

/// Модель элемента снаряжения
class _GearItem {
  final int id;
  final int equipUserId;
  final String title;
  final String brand;
  final int dist;
  final bool isMain;
  final bool showOnMain;
  final String? imageUrl;

  const _GearItem({
    required this.id,
    required this.equipUserId,
    required this.title,
    required this.brand,
    required this.dist,
    required this.isMain,
    required this.showOnMain,
    this.imageUrl,
  });

  String get value => '$dist км';
}

class GearTab extends ConsumerStatefulWidget {
  /// ID пользователя, чье снаряжение нужно отобразить
  final int userId;
  const GearTab({super.key, required this.userId});
  @override
  ConsumerState<GearTab> createState() => _GearTabState();
}

class _GearTabState extends ConsumerState<GearTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<_GearItem> _boots = [];
  List<_GearItem> _bikes = [];
  bool _isLoading = true;
  String? _error;
  bool _isOwnProfile = false;

  // Флаги "На главном экране" для кроссовок и велосипедов
  // Используем значение из первого элемента, если есть
  bool _showShoesOnMain = false;
  bool _showBikesOnMain = false;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Проверяем, является ли просматриваемый пользователь текущим авторизованным
      final authService = ref.read(authServiceProvider);
      final currentUserId = await authService.getUserId();
      _isOwnProfile = currentUserId != null && currentUserId == widget.userId;

      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.userId.toString()},
      );

      if (data['success'] == true) {
        final bootsList = data['boots'] as List<dynamic>? ?? [];
        final bikesList = data['bikes'] as List<dynamic>? ?? [];

        setState(() {
          _boots = bootsList.map((item) {
            return _GearItem(
              id: item['id'] as int,
              equipUserId: item['equip_user_id'] as int,
              title: item['name'] as String,
              brand: item['brand'] as String,
              dist: item['dist'] as int,
              isMain: (item['main'] as int) == 1,
              showOnMain: (item['show_on_main'] as int) == 1,
              imageUrl: item['image'] as String?,
            );
          }).toList();
          // Сортируем: основные элементы первыми
          _boots.sort((a, b) {
            if (a.isMain && !b.isMain) return -1;
            if (!a.isMain && b.isMain) return 1;
            return 0;
          });

          _bikes = bikesList.map((item) {
            return _GearItem(
              id: item['id'] as int,
              equipUserId: item['equip_user_id'] as int,
              title: item['name'] as String,
              brand: item['brand'] as String,
              dist: item['dist'] as int,
              isMain: (item['main'] as int) == 1,
              showOnMain: (item['show_on_main'] as int) == 1,
              imageUrl: item['image'] as String?,
            );
          }).toList();
          // Сортируем: основные элементы первыми
          _bikes.sort((a, b) {
            if (a.isMain && !b.isMain) return -1;
            if (!a.isMain && b.isMain) return 1;
            return 0;
          });

          // Устанавливаем флаги "На главном экране" из первого элемента
          _showShoesOnMain = _boots.isNotEmpty
              ? _boots.first.showOnMain
              : false;
          _showBikesOnMain = _bikes.isNotEmpty
              ? _bikes.first.showOnMain
              : false;

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Ошибка при загрузке снаряжения';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorHandler.format(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateShowOnMain(bool isBoots, bool value) async {
    if (!_isOwnProfile) return;

    final items = isBoots ? _boots : _bikes;
    if (items.isEmpty) return;

    // Обновляем флаг для всех элементов этого типа
    try {
      final api = ref.read(apiServiceProvider);
      for (final item in items) {
        await api.post(
          '/update_equipment_show_on_main.php',
          body: {
            'user_id': widget.userId.toString(),
            'equip_user_id': item.equipUserId.toString(),
            'show_on_main': value.toString(),
          },
        );
      }

      // Очищаем кэш MainTab, чтобы данные обновились на главной странице профиля
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'main_tab_${widget.userId}';
      await prefs.remove(cacheKey);

      setState(() {
        if (isBoots) {
          _showShoesOnMain = value;
          _boots = _boots.map((item) {
            return _GearItem(
              id: item.id,
              equipUserId: item.equipUserId,
              title: item.title,
              brand: item.brand,
              dist: item.dist,
              isMain: item.isMain,
              showOnMain: value,
              imageUrl: item.imageUrl,
            );
          }).toList();
        } else {
          _showBikesOnMain = value;
          _bikes = _bikes.map((item) {
            return _GearItem(
              id: item.id,
              equipUserId: item.equipUserId,
              title: item.title,
              brand: item.brand,
              dist: item.dist,
              isMain: item.isMain,
              showOnMain: value,
              imageUrl: item.imageUrl,
            );
          }).toList();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorHandler.formatWithContext(e, context: 'обновлении снаряжения'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: _loadEquipment,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ─── Кроссовки (показываем только если есть)
        if (_boots.isNotEmpty) ...[
          if (_isOwnProfile)
            SliverToBoxAdapter(
              child: _SectionHeaderWithToggle(
                title: 'Кроссовки',
                value: _showShoesOnMain,
                onChanged: (v) => _updateShowOnMain(true, v),
              ),
            ),
          if (_isOwnProfile) const SliverToBoxAdapter(child: SizedBox(height: 2)),
          if (!_isOwnProfile)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Кроссовки',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : null,
                  ),
                ),
              ),
            ),
          if (!_isOwnProfile) const SliverToBoxAdapter(child: SizedBox(height: 2)),
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) =>
                        const ViewingEquipmentScreen(initialSegment: 0),
                  ),
                );
                // Обновляем данные после возврата
                _loadEquipment();
              },
              child: _GearListCard(items: _boots, isBoots: true),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // ─── Велосипеды (показываем только если есть)
        if (_bikes.isNotEmpty) ...[
          if (_isOwnProfile)
            SliverToBoxAdapter(
              child: _SectionHeaderWithToggle(
                title: 'Велосипеды',
                value: _showBikesOnMain,
                onChanged: (v) => _updateShowOnMain(false, v),
              ),
            ),
          if (_isOwnProfile) const SliverToBoxAdapter(child: SizedBox(height: 2)),
          if (!_isOwnProfile)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Велосипеды',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : null,
                  ),
                ),
              ),
            ),
          if (!_isOwnProfile) const SliverToBoxAdapter(child: SizedBox(height: 2)),
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) =>
                        const ViewingEquipmentScreen(initialSegment: 1),
                  ),
                );
                // Обновляем данные после возврата
                _loadEquipment();
              },
              child: _GearListCard(items: _bikes, isBoots: false),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 25)),

        // ─── Кнопка "Добавить снаряжение" (только для своего профиля)
        if (_isOwnProfile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: PrimaryButton(
                  text: 'Добавить снаряжение',
                  leading: const Icon(CupertinoIcons.plus_circle, size: 18),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const AddingEquipmentScreen(),
                      ),
                    );
                    // Обновляем данные после возврата
                    _loadEquipment();
                  },
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

// ───────────────────── Заголовок секции со свитчем
class _SectionHeaderWithToggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SectionHeaderWithToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkTextSecondary
                    : null,
              ),
            ),
          ),
          Text(
            'На главном экране',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkTextSecondary
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.brandPrimary,
          ),
        ],
      ),
    );
  }
}

// ───────────────────── Адаптивное изображение снаряжения
// Определяет пропорции изображения и выбирает подходящий BoxFit
class _AdaptiveGearImage extends StatefulWidget {
  final String? imageUrl;
  final bool isBoots;
  const _AdaptiveGearImage({required this.imageUrl, required this.isBoots});

  @override
  State<_AdaptiveGearImage> createState() => _AdaptiveGearImageState();
}

class _AdaptiveGearImageState extends State<_AdaptiveGearImage> {
  BoxFit _fit = BoxFit.contain;
  ImageStreamListener? _listener;
  ImageStream? _imageStream;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _determineFit();
    }
  }

  @override
  void didUpdateWidget(_AdaptiveGearImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _cleanupListener();
      if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        _determineFit();
      }
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _cleanupListener() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
      _listener = null;
      _imageStream = null;
    }
  }

  void _determineFit() {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return;

    final imageProvider = NetworkImage(widget.imageUrl!);
    _imageStream = imageProvider.resolve(const ImageConfiguration());

    _listener = ImageStreamListener(
      (ImageInfo imageInfo, bool _) {
        final image = imageInfo.image;
        final width = image.width.toDouble();
        final height = image.height.toDouble();
        final imageAspectRatio = width / height;
        // Контейнер имеет размер 63x42, его соотношение сторон ≈ 1.5
        final containerAspectRatio = 63.0 / 42.0;

        // Если изображение шире контейнера (по соотношению сторон),
        // используем fitWidth (помещается по ширине)
        // Иначе используем fitHeight (помещается по высоте)
        // Это обеспечивает, что изображение помещается по длинной стороне
        if (mounted) {
          setState(() {
            _fit = imageAspectRatio > containerAspectRatio
                ? BoxFit.fitWidth
                : BoxFit.fitHeight;
          });
        }
        _cleanupListener();
      },
      onError: (exception, stackTrace) {
        // При ошибке используем contain по умолчанию
        if (mounted) {
          setState(() {
            _fit = BoxFit.contain;
          });
        }
        _cleanupListener();
      },
    );

    _imageStream!.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      // Изображение помещается по длинной стороне (fitWidth или fitHeight)
      return SizedBox(
        width: 63,
        height: 42,
        child: Image.network(
          widget.imageUrl!,
          fit: _fit,
          errorBuilder: (context, error, stackTrace) {
            final image = Image.asset(
              widget.isBoots ? 'assets/add_boots.png' : 'assets/add_bike.png',
              width: 63,
              height: 42,
              fit: BoxFit.contain,
            );
            return widget.isBoots ? Opacity(opacity: 0.9, child: image) : image;
          },
        ),
      );
    }

    // Дефолтное изображение
    final image = Image.asset(
      widget.isBoots ? 'assets/add_boots.png' : 'assets/add_bike.png',
      width: 63,
      height: 42,
      fit: BoxFit.contain,
    );
    return widget.isBoots ? Opacity(opacity: 0.9, child: image) : image;
  }
}

// ───────────────────── Карточка-список с элементами снаряжения
class _GearListCard extends StatelessWidget {
  final List<_GearItem> items;
  final bool isBoots;
  const _GearListCard({required this.items, required this.isBoots});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              offset: const Offset(0, 1),
              blurRadius: 1,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: List.generate(items.length, (i) {
            final it = items[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      // Изображение или дефолтная картинка
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: _AdaptiveGearImage(
                          imageUrl: it.imageUrl,
                          isBoots: isBoots,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            if (it.brand.isNotEmpty)
                              Text(
                                it.brand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        it.value,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.getDividerColor(context),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
