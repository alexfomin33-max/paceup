import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../../../../theme/app_theme.dart';
import '../../../../../../../widgets/more_menu_overlay.dart';
import '../../../../../../../service/api_service.dart';
import '../../../../../../../service/auth_service.dart';

/// Модель элемента снаряжения для просмотра
class _SneakerItem {
  final int id;
  final int equipUserId;
  final String brand;
  final String model;
  final int km;
  final int workouts;
  final int hours;
  final String pace;
  final String since;
  final bool isMain;
  final String? imageUrl;

  const _SneakerItem({
    required this.id,
    required this.equipUserId,
    required this.brand,
    required this.model,
    required this.km,
    required this.workouts,
    required this.hours,
    required this.pace,
    required this.since,
    required this.isMain,
    this.imageUrl,
  });
}

class ViewingSneakersContent extends StatefulWidget {
  const ViewingSneakersContent({super.key});

  @override
  State<ViewingSneakersContent> createState() => _ViewingSneakersContentState();
}

class _ViewingSneakersContentState extends State<ViewingSneakersContent> {
  List<_SneakerItem> _sneakers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSneakers();
  }

  /// Получение жестких данных для полей, которых нет в API
  /// На основе бренда и модели возвращает дефолтные значения
  Map<String, dynamic> _getHardcodedData(String brand, String model) {
    final brandLower = brand.toLowerCase();

    // Для Asics (включая "Asics Fat Burner")
    if (brandLower.contains('asics')) {
      return {
        'workouts': 46,
        'hours': 48,
        'pace': '4:18 /км',
        'since': 'В использовании с 21 июля 2023 г.',
      };
    }

    // Для Anta
    if (brandLower.contains('anta')) {
      return {
        'workouts': 68,
        'hours': 102,
        'pace': '3:42 /км',
        'since': 'В использовании с 18 августа 2022 г.',
      };
    }

    // Дефолтные значения для других брендов
    return {
      'workouts': 0,
      'hours': 0,
      'pace': '0:00 /км',
      'since': 'Дата не указана',
    };
  }

  /// Загрузка кроссовок из API
  Future<void> _loadSneakers() async {
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
        final bootsList = data['boots'] as List<dynamic>? ?? [];

        setState(() {
          _sneakers = bootsList.map((item) {
            final brand = item['brand'] as String;
            final model = item['name'] as String;

            // Получаем жесткие данные для полей, которых нет в API
            final hardcoded = _getHardcodedData(brand, model);

            // Используем данные из API, если есть, иначе - жесткие данные
            final paceStr =
                item['pace'] as String? ?? hardcoded['pace'] as String;
            final workouts =
                item['workouts'] as int? ?? hardcoded['workouts'] as int;
            final hours = item['hours'] as int? ?? hardcoded['hours'] as int;
            final sinceDate = item['since'] as String?;
            final sinceText = sinceDate != null && sinceDate.isNotEmpty
                ? 'В использовании с $sinceDate'
                : hardcoded['since'] as String;

            return _SneakerItem(
              id: item['id'] as int,
              equipUserId: item['equip_user_id'] as int,
              brand: brand,
              model: model,
              km: item['dist'] as int,
              workouts: workouts,
              hours: hours,
              pace: paceStr,
              since: sinceText,
              isMain: (item['main'] as int) == 1,
              imageUrl: item['image'] as String?,
            );
          }).toList();

          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'Ошибка при загрузке кроссовок';
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
              onPressed: _loadSneakers,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_sneakers.isEmpty) {
      return const Center(
        child: Text(
          'Нет кроссовок',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        ...List.generate(_sneakers.length, (index) {
          final sneaker = _sneakers[index];
          return Column(
            children: [
              if (index > 0) const SizedBox(height: 12),
              GearViewCard.shoes(
                brand: sneaker.brand,
                model: sneaker.model,
                imageUrl: sneaker.imageUrl,
                km: sneaker.km,
                workouts: sneaker.workouts,
                hours: sneaker.hours,
                pace: sneaker.pace,
                since: sneaker.since,
                mainBadgeText: sneaker.isMain ? 'Основные' : null,
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Публичная карточка для «Просмотра снаряжения»
class GearViewCard extends StatefulWidget {
  final String brand;
  final String model;
  final String? asset; // Локальный asset (для обратной совместимости)
  final String? imageUrl; // URL изображения из базы данных
  final int km;
  final int workouts;
  final int hours;
  final String thirdValue; // pace/speed
  final String thirdLabel;
  final String since;
  final String? mainBadgeText;

  const GearViewCard.shoes({
    super.key,
    required this.brand,
    required this.model,
    this.asset,
    this.imageUrl,
    required this.km,
    required this.workouts,
    required this.hours,
    required String pace,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = pace,
       thirdLabel = 'Средний темп';

  const GearViewCard.bike({
    super.key,
    required this.brand,
    required this.model,
    this.asset,
    this.imageUrl,
    required this.km,
    required this.workouts,
    required this.hours,
    required String speed,
    required this.since,
    this.mainBadgeText,
  }) : thirdValue = speed,
       thirdLabel = 'Скорость';

  @override
  State<GearViewCard> createState() => _GearViewCardState();
}

class _GearViewCardState extends State<GearViewCard> {
  /// Ключ для привязки всплывающего меню к кнопке "три точки"
  final GlobalKey _menuKey = GlobalKey();

  /// Показать всплывающее меню с действиями для карточки снаряжения
  void _showMenu(BuildContext context) {
    final items = <MoreMenuItem>[
      MoreMenuItem(
        text: 'Сделать основными',
        icon: CupertinoIcons.star_fill,
        onTap: () {
          // TODO: Реализовать логику установки как основных
        },
      ),
      MoreMenuItem(
        text: 'Редактировать',
        icon: CupertinoIcons.pencil,
        onTap: () {
          // TODO: Реализовать логику редактирования
        },
      ),
      MoreMenuItem(
        text: 'Удалить',
        icon: CupertinoIcons.minus_circle,
        iconColor: AppColors.error,
        textStyle: const TextStyle(color: AppColors.error),
        onTap: () {
          // TODO: Реализовать логику удаления
        },
      ),
    ];

    MoreMenuOverlay(anchorKey: _menuKey, items: items).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок (иконка в одной строке с названием)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.brand} ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: widget.model,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: _menuKey,
                  onPressed: () => _showMenu(context),
                  tooltip: 'Меню',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: const Icon(
                    CupertinoIcons.ellipsis, // горизонтальная иконка
                    size: 18,
                    color: AppColors.iconPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Чип «Основные/Основной» сразу под названием
          if (widget.mainBadgeText != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(AppRadius.xl), // пилюля
                ),
                child: Text(
                  widget.mainBadgeText!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Изображение (из базы данных или локальный asset)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AspectRatio(
              aspectRatio: 16 / 7.8,
              child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // При ошибке загрузки показываем дефолтное изображение
                        if (widget.asset != null) {
                          return Image.asset(
                            widget.asset!,
                            fit: BoxFit.contain,
                          );
                        }
                        return Container(
                          color: AppColors.border,
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    )
                  : widget.asset != null
                  ? Image.asset(widget.asset!, fit: BoxFit.contain)
                  : Container(
                      color: AppColors.border,
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Пробег
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    const TextSpan(text: 'Пробег '),
                    TextSpan(
                      text: '${widget.km}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(text: ' км'),
                  ],
                ),
              ),
            ),
          ),

          // ── Разделитель между пробегом и метриками
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.divider,
            indent: 12,
            endIndent: 12,
          ),

          // ── Метрики (левое выравнивание чисел)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                _metric('Тренировок', '${widget.workouts}'),
                _metric('Время', '${widget.hours} ч'),
                _metric(widget.thirdLabel, widget.thirdValue),
              ],
            ),
          ),

          // ── Дата
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Text(
              widget.since,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ← левое выравнивание
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.left, // ← на всякий случай
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
