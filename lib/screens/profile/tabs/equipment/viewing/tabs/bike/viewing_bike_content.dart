import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../theme/app_theme.dart';
import '../sneakers/viewing_sneakers_content.dart'
    show GearViewCard; // теперь публичный класс
import '../../../../../../../service/api_service.dart';
import '../../../../../../../service/auth_service.dart';
import '../../../../../../../utils/equipment_date_format.dart';

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

class ViewingBikeContent extends StatefulWidget {
  const ViewingBikeContent({super.key});

  @override
  State<ViewingBikeContent> createState() => _ViewingBikeContentState();
}

class _ViewingBikeContentState extends State<ViewingBikeContent> {
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
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      final api = ApiService();
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': userId.toString()},
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
        _error = 'Ошибка: $e';
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
              style: const TextStyle(color: AppColors.textSecondary),
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
      return const Center(
        child: Text(
          'Нет велосипедов',
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
              ),
            ],
          );
        }),
      ],
    );
  }
}
