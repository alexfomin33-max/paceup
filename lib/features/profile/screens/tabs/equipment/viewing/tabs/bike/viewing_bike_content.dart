import 'package:flutter/cupertino.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../../core/widgets/primary_button.dart';
import '../sneakers/viewing_sneakers_content.dart'
    show GearViewCard; // теперь публичный класс
import '../../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/utils/equipment_date_format.dart';
import '../../../adding/adding_equipment_screen.dart';

/// Модель элемента велосипеда для просмотра
class _BikeItem {
  final int id;
  final int equipUserId;
  final String brand;
  final String model;
  final int km;
  final int workouts;
  final int hours;
  final String speed;
  final String since;
  final bool isMain;
  final String? imageUrl;

  const _BikeItem({
    required this.id,
    required this.equipUserId,
    required this.brand,
    required this.model,
    required this.km,
    required this.workouts,
    required this.hours,
    required this.speed,
    required this.since,
    required this.isMain,
    this.imageUrl,
  });
}

class ViewingBikeContent extends ConsumerStatefulWidget {
  /// ID пользователя, чье снаряжение нужно отобразить
  final int userId;
  const ViewingBikeContent({super.key, required this.userId});

  @override
  ConsumerState<ViewingBikeContent> createState() =>
      _ViewingBikeContentState();
}

class _ViewingBikeContentState extends ConsumerState<ViewingBikeContent> {
  List<_BikeItem> _bikes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBikes();
  }

  /// Получение жестких данных для полей, которых нет в API
  /// На основе бренда и модели возвращает дефолтные значения
  Map<String, dynamic> _getHardcodedData(String brand, String model) {
    final brandLower = brand.toLowerCase();

    // Для Pinarello
    if (brandLower.contains('pinarello')) {
      return {
        'workouts': 57,
        'hours': 94,
        'speed': '37 км/ч',
        'since': 'В использовании с 16 августа 2022 г.',
      };
    }

    // Для SCOTT
    if (brandLower.contains('scott')) {
      return {
        'workouts': 41,
        'hours': 67,
        'speed': '32 км/ч',
        'since': 'В использовании с 25 июня 2020 г.',
      };
    }

    // Дефолтные значения для других брендов
    return {
      'workouts': 0,
      'hours': 0,
      'speed': '0 км/ч',
      'since': 'Дата не указана',
    };
  }

  /// Загрузка велосипедов из API
  Future<void> _loadBikes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.userId.toString()},
      );

      if (data['success'] == true) {
        final bikesList = data['bikes'] as List<dynamic>? ?? [];

        setState(() {
          _bikes = bikesList.map((item) {
            final brand = item['brand'] as String;
            final model = item['name'] as String;

            // Получаем жесткие данные для полей, которых нет в API
            final hardcoded = _getHardcodedData(brand, model);

            // Используем данные из API, если есть, иначе - жесткие данные
            final speedStr =
                item['speed'] as String? ?? hardcoded['speed'] as String;
            final workouts =
                item['workouts'] as int? ?? hardcoded['workouts'] as int;
            final hours = item['hours'] as int? ?? hardcoded['hours'] as int;
            // Получаем дату из базы данных
            final inUseSinceStr = item['in_use_since'] as String?;
            final sinceText = inUseSinceStr != null && inUseSinceStr.isNotEmpty
                ? formatEquipmentDateWithPrefix(inUseSinceStr)
                : hardcoded['since'] as String;

            return _BikeItem(
              id: item['id'] as int,
              equipUserId: item['equip_user_id'] as int,
              brand: brand,
              model: model,
              km: item['dist'] as int,
              workouts: workouts,
              hours: hours,
              speed: speedStr,
              since: sinceText,
              isMain: (item['main'] as int) == 1,
              imageUrl: item['image'] as String?,
            );
          }).toList();
          // Сортируем: основные элементы первыми
          _bikes.sort((a, b) {
            if (a.isMain && !b.isMain) return -1;
            if (!a.isMain && b.isMain) return 1;
            return 0;
          });

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Ошибка при загрузке велосипедов';
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

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: _loadBikes,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_bikes.isEmpty) {
      return Consumer(
        builder: (context, ref, child) {
          final currentUserIdAsync = ref.watch(currentUserIdProvider);
          return currentUserIdAsync.when(
            data: (currentUserId) {
              final isOwnProfile = currentUserId != null && currentUserId == widget.userId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Нет велосипедов',
                        style: TextStyle(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                      if (isOwnProfile) ...[
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: 'Добавить велосипед',
                          leading: const Icon(CupertinoIcons.plus_circle, size: 18),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const AddingEquipmentScreen(
                                  initialSegment: 1,
                                ),
                              ),
                            );
                            // Обновляем список после возврата
                            if (mounted) {
                              _loadBikes();
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator(radius: 16)),
            error: (_, __) => const SizedBox.shrink(),
          );
        },
      );
    }

    return Column(
      children: [
        ...List.generate(_bikes.length, (index) {
          final bike = _bikes[index];
          return Column(
            children: [
              if (index > 0) const SizedBox(height: 12),
              GearViewCard.bike(
                equipUserId: bike.equipUserId,
                brand: bike.brand,
                model: bike.model,
                imageUrl: bike.imageUrl,
                km: bike.km,
                workouts: bike.workouts,
                hours: bike.hours,
                speed: bike.speed,
                since: bike.since,
                mainBadgeText: bike.isMain ? 'Основной' : null,
                onUpdate: _loadBikes, // Callback для обновления списка после действий
                userId: widget.userId, // ID пользователя, чье снаряжение отображается
              ),
            ],
          );
        }),
        // ── Кнопка "Добавить велосипед" (только для собственного профиля)
        Consumer(
          builder: (context, ref, child) {
            final currentUserIdAsync = ref.watch(currentUserIdProvider);
            return currentUserIdAsync.when(
              data: (currentUserId) {
                final isOwnProfile = currentUserId != null && currentUserId == widget.userId;
                if (!isOwnProfile) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    const SizedBox(height: 25),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: PrimaryButton(
                          text: 'Добавить велосипед',
                          leading: const Icon(CupertinoIcons.plus_circle, size: 18),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (_) => const AddingEquipmentScreen(
                                  initialSegment: 1,
                                ),
                              ),
                            );
                            // Обновляем список после возврата
                            if (mounted) {
                              _loadBikes();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}
