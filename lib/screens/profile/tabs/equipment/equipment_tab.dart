// lib/screens/profile/tabs/equipment/equipment_tab.dart
// ─────────────────────────────────────────────────────────────────────────────
//                                Вкладка «Снаряжение»
//  Загружает снаряжение пользователя из API и отображает его
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../theme/app_theme.dart';
import '../../../../service/api_service.dart';
import '../../../../service/auth_service.dart';
import 'adding/adding_equipment_screen.dart';
import 'viewing/viewing_equipment_screen.dart';
import '../../../../widgets/primary_button.dart';

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

class GearTab extends StatefulWidget {
  const GearTab({super.key});
  @override
  State<GearTab> createState() => _GearTabState();
}

class _GearTabState extends State<GearTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<_GearItem> _boots = [];
  List<_GearItem> _bikes = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;

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
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = userId;
      final api = ApiService();
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': userId.toString()},
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
        _error = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateShowOnMain(bool isBoots, bool value) async {
    if (_currentUserId == null) return;

    final items = isBoots ? _boots : _bikes;
    if (items.isEmpty) return;

    // Обновляем флаг для всех элементов этого типа
    try {
      final api = ApiService();
      for (final item in items) {
        await api.post(
          '/update_equipment_show_on_main.php',
          body: {
            'user_id': _currentUserId.toString(),
            'equip_user_id': item.equipUserId.toString(),
            'show_on_main': value.toString(),
          },
        );
      }

      // Очищаем кэш MainTab, чтобы данные обновились на главной странице профиля
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'main_tab_$_currentUserId';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при обновлении: $e')));
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
              style: const TextStyle(color: AppColors.textSecondary),
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
          SliverToBoxAdapter(
            child: _SectionHeaderWithToggle(
              title: 'Кроссовки',
              value: _showShoesOnMain,
              onChanged: (v) => _updateShowOnMain(true, v),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2)),
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) =>
                        const ViewingEquipmentScreen(initialSegment: 0),
                  ),
                );
              },
              child: _GearListCard(items: _boots, isBoots: true),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // ─── Велосипеды (показываем только если есть)
        if (_bikes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeaderWithToggle(
              title: 'Велосипеды',
              value: _showBikesOnMain,
              onChanged: (v) => _updateShowOnMain(false, v),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 2)),
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) =>
                        const ViewingEquipmentScreen(initialSegment: 1),
                  ),
                );
              },
              child: _GearListCard(items: _bikes, isBoots: false),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ─── Кнопка "Добавить снаряжение"
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            'На главном экране',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: [
            const BoxShadow(
              color: AppColors.shadowSoft,
              offset: Offset(0, 1),
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
                        child: it.imageUrl != null && it.imageUrl!.isNotEmpty
                            ? Image.network(
                                it.imageUrl!,
                                width: 64,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  // При ошибке загрузки показываем дефолтное изображение
                                  final image = Image.asset(
                                    isBoots
                                        ? 'assets/add_boots.png'
                                        : 'assets/add_bike.png',
                                    width: 64,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  );
                                  return isBoots
                                      ? Opacity(opacity: 0.9, child: image)
                                      : image;
                                },
                              )
                            : () {
                                final image = Image.asset(
                                  isBoots
                                      ? 'assets/add_boots.png'
                                      : 'assets/add_bike.png',
                                  width: 64,
                                  height: 40,
                                  fit: BoxFit.cover,
                                );
                                return isBoots
                                    ? Opacity(opacity: 0.9, child: image)
                                    : image;
                              }(),
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
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (it.brand.isNotEmpty)
                              Text(
                                it.brand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        it.value,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.divider,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
