import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/utils/error_handler.dart';
import '../../../../../../../../core/widgets/more_menu_overlay.dart';
import '../../../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../../../core/widgets/primary_button.dart';
import '../../../../../../../../providers/services/api_provider.dart';
import '../../../../../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../core/utils/equipment_date_format.dart';
import '../../../editing/editing_equipment_screen.dart';
import '../../../adding/adding_equipment_screen.dart';

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

class ViewingSneakersContent extends ConsumerStatefulWidget {
  const ViewingSneakersContent({super.key});

  @override
  ConsumerState<ViewingSneakersContent> createState() =>
      _ViewingSneakersContentState();
}

class _ViewingSneakersContentState
    extends ConsumerState<ViewingSneakersContent> {
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
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();

      if (userId == null) {
        setState(() {
          _error = 'Пользователь не авторизован';
          _isLoading = false;
        });
        return;
      }

      final api = ref.read(apiServiceProvider);
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
              style: TextStyle(color: AppColors.getTextSecondaryColor(context)),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Нет кроссовок',
                style: TextStyle(
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Добавить кроссовки',
                leading: const Icon(CupertinoIcons.plus_circle, size: 18),
                onPressed: () async {
                  await Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          const AddingEquipmentScreen(initialSegment: 0),
                    ),
                  );
                  // Обновляем список после возврата
                  if (mounted) {
                    _loadSneakers();
                  }
                },
              ),
            ],
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
        // ── Кнопка "Добавить кроссовки"
        if (_sneakers.isNotEmpty) const SizedBox(height: 25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: PrimaryButton(
              text: 'Добавить кроссовки',
              leading: const Icon(CupertinoIcons.plus_circle, size: 18),
              onPressed: () async {
                await Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) =>
                        const AddingEquipmentScreen(initialSegment: 0),
                  ),
                );
                // Обновляем список после возврата
                if (mounted) {
                  _loadSneakers();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Публичная карточка для «Просмотра снаряжения»
class GearViewCard extends ConsumerStatefulWidget {
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
       thirdLabel = 'Темп, мин/км',
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
       thirdLabel = 'Скорость, км/ч',
       equipmentType = 'bike';

  @override
  ConsumerState<GearViewCard> createState() => _GearViewCardState();
}

class _GearViewCardState extends ConsumerState<GearViewCard> {
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
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь не авторизован')),
        );
        return;
      }

      final api = ref.read(apiServiceProvider);
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
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'main_tab_$userId';
        await prefs.remove(cacheKey);
        if (!context.mounted) return;
        // Обновляем список
        widget.onUpdate?.call();
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Ошибка при обновлении')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.format(e))));
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
    if (!mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();
      if (userId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь не авторизован')),
        );
        return;
      }

      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/delete_equipment.php',
        body: {
          'user_id': userId.toString(),
          'equip_user_id': widget.equipUserId.toString(),
        },
      );

      if (data['success'] == true) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снаряжение успешно удалено')),
        );
        // Обновляем список
        widget.onUpdate?.call();
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Ошибка при удалении')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.format(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
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
            Transform.translate(
              offset: const Offset(0, -6),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    // ────────────────────────────────────────────────────────────────
                    // 🌓 ТЕМНАЯ ТЕМА: темно-серый фон для плашки "Основные"
                    // ────────────────────────────────────────────────────────────────
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkDivider
                        : AppColors.getTextPrimaryColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.xl), // пилюля
                  ),
                  child: Text(
                    widget.mainBadgeText!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      // ────────────────────────────────────────────────────────────────
                      // 🌓 ТЕМНАЯ ТЕМА: светлый текст на сером фоне
                      // ────────────────────────────────────────────────────────────────
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.getSurfaceColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // ── Изображение (из базы данных или дефолтное)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: SizedBox(
                width: 220,
                height: 150,
                child: Builder(
                  builder: (context) {
                    // ────────────────────────────────────────────────────────────────
                    // 🖼️ ДЕФОЛТНОЕ ИЗОБРАЖЕНИЕ: определяем тип экипировки
                    // ────────────────────────────────────────────────────────────────
                    final String defaultImageAsset =
                        widget.equipmentType == 'bike'
                        ? 'assets/add_bike.png'
                        : 'assets/add_boots.png';

                    // Проверяем, является ли imageUrl валидным URL
                    final bool hasValidImageUrl =
                        widget.imageUrl != null &&
                        widget.imageUrl!.isNotEmpty &&
                        (widget.imageUrl!.startsWith('http://') ||
                            widget.imageUrl!.startsWith('https://'));

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        color: AppColors.surface,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: hasValidImageUrl
                            ? Builder(
                                builder: (context) {
                                  // ────────────────────────────────────────────────────────────────
                                  // 🖼️ ОПТИМИЗАЦИЯ КАЧЕСТВА: используем CachedNetworkImage с учетом DPR
                                  // ────────────────────────────────────────────────────────────────
                                  final dpr = MediaQuery.of(
                                    context,
                                  ).devicePixelRatio;
                                  final cacheWidth = (220 * dpr).round();
                                  return CachedNetworkImage(
                                    imageUrl: widget.imageUrl!,
                                    width: 220,
                                    height: 150,
                                    fit: BoxFit.contain,
                                    memCacheWidth: cacheWidth,
                                    maxWidthDiskCache: cacheWidth,
                                    filterQuality: FilterQuality.high,
                                    // НЕ передаем cacheManager - используется DefaultCacheManager
                                    errorWidget: (context, url, error) {
                                      // ────────────────────────────────────────────────────────────────
                                      // 🖼️ ДЕФОЛТНОЕ ИЗОБРАЖЕНИЕ: при ошибке загрузки показываем asset
                                      // ────────────────────────────────────────────────────────────────
                                      return Image.asset(
                                        defaultImageAsset,
                                        width: 220,
                                        height: 150,
                                        fit: BoxFit.contain,
                                      );
                                    },
                                  );
                                },
                              )
                            : widget.asset != null
                            ? Image.asset(
                                widget.asset!,
                                width: 220,
                                height: 150,
                                fit: BoxFit.contain,
                              )
                            : Builder(
                                builder: (context) {
                                  // ────────────────────────────────────────────────────────────────
                                  // 🖼️ ДЕФОЛТНОЕ ИЗОБРАЖЕНИЕ: если нет URL, показываем asset
                                  // ────────────────────────────────────────────────────────────────
                                  return Image.asset(
                                    defaultImageAsset,
                                    width: 220,
                                    height: 150,
                                    fit: BoxFit.contain,
                                  );
                                },
                              ),
                      ),
                    );
                  },
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
                    TextSpan(
                      text: 'Пробег ',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    TextSpan(
                      text: '${widget.km}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    TextSpan(
                      text: ' км',
                      style: TextStyle(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
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
                _metric('Время, ч', '${widget.hours}'),
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
    // Разделяем значение на числовую часть и единицы измерения
    String numberPart = value;
    String unitPart = '';

    // Проверяем наличие единиц измерения в конце строки
    if (value.endsWith(' ч')) {
      numberPart = value.substring(0, value.length - 2);
      unitPart = ' ч';
    } else if (value.endsWith(' км/ч')) {
      numberPart = value.substring(0, value.length - 5);
      // Для "Скорость, км/ч" не показываем "км/ч"
      if (label != 'Скорость, км/ч') {
        unitPart = ' км/ч';
      }
    } else if (value.endsWith(' /км')) {
      numberPart = value.substring(0, value.length - 4);
      // Для "Темп, мин/км" не показываем "/км"
      if (label != 'Темп, мин/км') {
        unitPart = ' /км';
      }
    } else if (value.endsWith(' /100м')) {
      numberPart = value.substring(0, value.length - 6);
      unitPart = ' /100м';
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // ← левое выравнивание
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 2),
          unitPart.isNotEmpty
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: numberPart,
                        style: TextStyle(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                      TextSpan(
                        text: unitPart,
                        style: TextStyle(
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                )
              : Text(
                  numberPart,
                  textAlign: TextAlign.left, // ← на всякий случай
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
        ],
      ),
    );
  }
}
