import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../../../theme/app_theme.dart';
import '../../../../../../../widgets/more_menu_overlay.dart';
import '../../../../../../../widgets/transparent_route.dart';
import '../../../../../../../service/api_service.dart';
import '../../../../../../../service/auth_service.dart';
import '../../../../../../../utils/equipment_date_format.dart';
import '../../../editing/editing_equipment_screen.dart';

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
            // Получаем дату из базы данных
            final inUseSinceStr = item['in_use_since'] as String?;
            final sinceText = inUseSinceStr != null && inUseSinceStr.isNotEmpty
                ? formatEquipmentDateWithPrefix(inUseSinceStr)
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
          // Сортируем: основные элементы первыми
          _sneakers.sort((a, b) {
            if (a.isMain && !b.isMain) return -1;
            if (!a.isMain && b.isMain) return 1;
            return 0;
          });

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
              style: TextStyle(
                color: AppColors.getTextSecondaryColor(context),
              ),
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
      return Center(
        child: Text(
          'Нет кроссовок',
          style: TextStyle(
            color: AppColors.getTextSecondaryColor(context),
          ),
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
                equipUserId: sneaker.equipUserId,
                brand: sneaker.brand,
                model: sneaker.model,
                imageUrl: sneaker.imageUrl,
                km: sneaker.km,
                workouts: sneaker.workouts,
                hours: sneaker.hours,
                pace: sneaker.pace,
                since: sneaker.since,
                mainBadgeText: sneaker.isMain ? 'Основные' : null,
                onUpdate:
                    _loadSneakers, // Callback для обновления списка после действий
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
  final int? equipUserId; // ID записи в equip_user для API запросов
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
  final VoidCallback? onUpdate; // Callback для обновления списка после действий
  final String equipmentType; // Тип снаряжения: 'boots' или 'bike'

  const GearViewCard.shoes({
    super.key,
    this.equipUserId,
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
    this.onUpdate,
  }) : thirdValue = pace,
       thirdLabel = 'Средний темп',
       equipmentType = 'boots';

  const GearViewCard.bike({
    super.key,
    this.equipUserId,
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
    this.onUpdate,
  }) : thirdValue = speed,
       thirdLabel = 'Скорость',
       equipmentType = 'bike';

  @override
  State<GearViewCard> createState() => _GearViewCardState();
}

class _GearViewCardState extends State<GearViewCard> {
  /// Ключ для привязки всплывающего меню к кнопке "три точки"
  final GlobalKey _menuKey = GlobalKey();

  /// Показать всплывающее меню с действиями для карточки снаряжения
  void _showMenu(BuildContext context) async {
    // Если нет equipUserId, не показываем меню
    if (widget.equipUserId == null) {
      return;
    }

    final items = <MoreMenuItem>[
      MoreMenuItem(
        text: widget.mainBadgeText != null
            ? 'Убрать из основных'
            : 'Сделать основными',
        icon: widget.mainBadgeText != null
            ? CupertinoIcons
                  .star_fill // Залитая звезда для основных
            : CupertinoIcons.star, // Пустая звезда для неосновных
        onTap: () => _setMain(context),
      ),
      MoreMenuItem(
        text: 'Редактировать',
        icon: CupertinoIcons.pencil,
        onTap: () => _editEquipment(context),
      ),
      MoreMenuItem(
        text: 'Удалить',
        icon: CupertinoIcons.minus_circle,
        iconColor: AppColors.error,
        textStyle: const TextStyle(color: AppColors.error),
        onTap: () => _deleteEquipment(context),
      ),
    ];

    MoreMenuOverlay(anchorKey: _menuKey, items: items).show(context);
  }

  /// Установка снаряжения как основного
  Future<void> _setMain(BuildContext context) async {
    if (widget.equipUserId == null) return;

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь не авторизован')),
          );
        }
        return;
      }

      final api = ApiService();
      final isCurrentlyMain = widget.mainBadgeText != null;
      final data = await api.post(
        '/set_main_equipment.php',
        body: {
          'user_id': userId.toString(),
          'equip_user_id': widget.equipUserId.toString(),
          'main': !isCurrentlyMain, // Передаем boolean, API сам преобразует
        },
      );

      if (data['success'] == true) {
        if (mounted) {
          // Очищаем кэш MainTab, чтобы данные обновились на главной странице профиля
          final prefs = await SharedPreferences.getInstance();
          final cacheKey = 'main_tab_$userId';
          await prefs.remove(cacheKey);
          // Обновляем список
          widget.onUpdate?.call();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Ошибка при обновлении')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  /// Редактирование снаряжения
  Future<void> _editEquipment(BuildContext context) async {
    if (widget.equipUserId == null) return;

    // Открываем экран редактирования
    final result = await Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => EditingEquipmentScreen(
          equipUserId: widget.equipUserId!,
          type: widget.equipmentType, // Используем тип из конструктора
        ),
      ),
    );

    // Если редактирование прошло успешно (вернулся true), обновляем список
    if (result == true && mounted) {
      widget.onUpdate?.call();
    }
  }

  /// Удаление снаряжения
  Future<void> _deleteEquipment(BuildContext context) async {
    if (widget.equipUserId == null) return;

    // Показываем диалог подтверждения
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Удалить снаряжение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Отмена'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Удалить'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = AuthService();
      final userId = await authService.getUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь не авторизован')),
          );
        }
        return;
      }

      final api = ApiService();
      final data = await api.post(
        '/delete_equipment.php',
        body: {
          'user_id': userId.toString(),
          'equip_user_id': widget.equipUserId.toString(),
        },
      );

      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Снаряжение успешно удалено')),
          );
          // Обновляем список
          widget.onUpdate?.call();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Ошибка при удалении')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 1,
        ),
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
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                        TextSpan(
                          text: widget.model,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.getTextPrimaryColor(context),
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
                  icon: Icon(
                    CupertinoIcons.ellipsis, // горизонтальная иконка
                    size: 18,
                    color: AppColors.getIconPrimaryColor(context),
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
                  color: AppColors.getTextPrimaryColor(context),
                  borderRadius: BorderRadius.circular(AppRadius.xl), // пилюля
                ),
                child: Text(
                  widget.mainBadgeText!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.getSurfaceColor(context),
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
                          color: AppColors.getBorderColor(context),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.photo,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                        );
                      },
                    )
                  : widget.asset != null
                  ? Image.asset(widget.asset!, fit: BoxFit.contain)
                  : Container(
                      color: AppColors.getBorderColor(context),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          color: AppColors.getTextSecondaryColor(context),
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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                  children: [
                    const TextSpan(text: 'Пробег '),
                    TextSpan(
                      text: '${widget.km}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const TextSpan(text: ' км'),
                  ],
                ),
              ),
            ),
          ),

          // ── Разделитель между пробегом и метриками
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.getTextSecondaryColor(context),
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
