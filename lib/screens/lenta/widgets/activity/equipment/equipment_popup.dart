// lib/screens/lenta/widgets/activity/equipment/equipment_popup.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/activity_lenta.dart' as al;
import '../../../../../providers/services/api_provider.dart';
import '../../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Попап экипировки, якорящийся к кнопке справа от чипа.
/// Поведение и размеры совпадают с исходным вариантом:
/// - 288×112, 2 строки по 56, тонкий разделитель 1px (#ECECEC)
/// - Появление с анимацией Fade + Scale(0.8→1.0, easeOutBack ~250мс)
/// - Позиция: стараемся показать НАД кнопкой; если не влезает — ПОД кнопкой.
/// - Горизонталь: прижимаем правым краем к кнопке; не выходим за границы экрана.
class EquipmentPopup {
  /// Показать попап, привязанный к виджету с [anchorKey].
  /// Использует реальные данные из [items] вместо жестко вбитых значений.
  /// Загружает весь эквип пользователя того же типа и показывает его (кроме уже отображаемого).
  static void showAnchored(
    BuildContext context, {
    required GlobalKey anchorKey,
    required List<al.Equipment> items,
    required int userId,
    required String activityType,
    required int activityId,
    required double activityDistance,
    VoidCallback? onEquipmentChanged,
    Function(al.Equipment)?
    onEquipmentSelected, // callback для выбора экипировки (для экрана добавления)
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final anchorContext = anchorKey.currentContext;
    if (anchorContext == null) return;

    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null) return;

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    const double popupW = 260;
    // ────────────────────────────────────────────────────────────────
    // 📏 ДИНАМИЧЕСКАЯ ВЫСОТА: будет вычисляться на основе содержимого
    // ────────────────────────────────────────────────────────────────
    // Минимальная высота для индикатора загрузки (56px)
    const double minHeight = 56.0;

    // Горизонталь: выравниваем правым краем по кнопке, но в пределах экрана.
    double left = offset.dx + size.width - popupW;
    left = left.clamp(8.0, screenSize.width - popupW - 8.0);

    // Вертикаль: начальная позиция (будет пересчитана после загрузки)
    // Используем минимальную высоту для начальной позиции
    final topWouldBe = offset.dy - minHeight;
    final double initialTop = (topWouldBe < 20)
        ? (offset.dy + size.height)
        : topWouldBe;

    late OverlayEntry entry;

    void close() {
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _AnimatedPopup(
        left: left,
        initialTop: initialTop,
        anchorOffset: offset.dy,
        anchorHeight: size.height,
        width: popupW,
        onDismiss: close,
        items: items,
        userId: userId,
        activityType: activityType,
        activityId: activityId,
        activityDistance: activityDistance,
        onEquipmentChanged: onEquipmentChanged,
        onEquipmentSelected: onEquipmentSelected,
      ),
    );

    overlay.insert(entry);
  }
}

class _AnimatedPopup extends StatefulWidget {
  final double left;
  final double initialTop;
  final double anchorOffset;
  final double anchorHeight;
  final double width;
  final VoidCallback onDismiss;
  final List<al.Equipment> items;
  final int userId;
  final String activityType;
  final int activityId;
  final double activityDistance;
  final VoidCallback? onEquipmentChanged;
  final Function(al.Equipment)? onEquipmentSelected;

  const _AnimatedPopup({
    required this.left,
    required this.initialTop,
    required this.anchorOffset,
    required this.anchorHeight,
    required this.width,
    required this.onDismiss,
    required this.items,
    required this.userId,
    required this.activityType,
    required this.activityId,
    required this.activityDistance,
    this.onEquipmentChanged,
    this.onEquipmentSelected,
  });

  @override
  State<_AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<_AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Тап по полупрозрачному фону — закрыть
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: FadeTransition(
              opacity: _fade.drive(Tween(begin: 0.0, end: 1.0)),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Попап с контентом
        // ✅ Важно: попап должен быть ПОСЛЕ фонового GestureDetector в Stack,
        // чтобы элементы внутри попапа перехватывали клики раньше
        Positioned(
          left: widget.left,
          top: widget.initialTop,
          width: widget.width,
          child: GestureDetector(
            // ✅ Пустой обработчик останавливает распространение клика на фоновый GestureDetector
            // ✅ deferToChild позволяет кликам проходить к дочерним виджетам
            onTap: () {},
            behavior: HitTestBehavior.deferToChild,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: Colors.transparent,
                  child: IntrinsicHeight(
                    child: Container(
                      width: widget.width,
                      constraints: const BoxConstraints(
                        minHeight: 56.0,
                        maxHeight: 284.0, // максимум для 5 элементов
                      ),
                      decoration: BoxDecoration(
                        // ────────────────────────────────────────────────────────────────
                        // 🌓 ТЕМНАЯ ТЕМА: фон попапа такой же, как у плашки экипировки
                        // ────────────────────────────────────────────────────────────────
                        // В темной теме используем darkSurfaceMuted (как у плашки)
                        // В светлой теме оставляем getSurfaceColor (не трогаем)
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceMuted
                            : AppColors.getSurfaceColor(context),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: [
                          BoxShadow(
                            // ────────────────────────────────────────────────────────────────
                            // 🌓 ТЕМНАЯ ТЕМА: адаптивная тень
                            // ────────────────────────────────────────────────────────────────
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkShadowSoft
                                : AppColors.textTertiary,
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _PopupContent(
                        items: widget.items,
                        userId: widget.userId,
                        activityType: widget.activityType,
                        activityId: widget.activityId,
                        activityDistance: widget.activityDistance,
                        onEquipmentChanged: () {
                          widget.onDismiss(); // закрываем попап
                          widget.onEquipmentChanged
                              ?.call(); // вызываем callback
                        },
                        onEquipmentSelected: widget.onEquipmentSelected,
                        onDismiss: widget.onDismiss,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Контент попапа: строки экипировки по 56px и разделители 1px.
/// ────────────────────────────────────────────────────────────────
/// 📦 ИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БД: загружает весь эквип пользователя того же типа
/// и показывает его (кроме уже отображаемого в блоке тренировки)
/// ────────────────────────────────────────────────────────────────
class _PopupContent extends ConsumerStatefulWidget {
  final List<al.Equipment> items; // уже показанный эквип из блока тренировки
  final int userId;
  final String activityType;
  final int activityId;
  final double activityDistance;
  final VoidCallback? onEquipmentChanged;
  final Function(al.Equipment)? onEquipmentSelected;
  final VoidCallback? onDismiss;

  const _PopupContent({
    required this.items,
    required this.userId,
    required this.activityType,
    required this.activityId,
    required this.activityDistance,
    this.onEquipmentChanged,
    this.onEquipmentSelected,
    this.onDismiss,
  });

  @override
  ConsumerState<_PopupContent> createState() => _PopupContentState();
}

class _PopupContentState extends ConsumerState<_PopupContent> {
  List<al.Equipment> _allEquipment = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllEquipment();
  }

  /// Загружает весь эквип пользователя того же типа через API
  /// и исключает уже показанный эквип из блока тренировки
  Future<void> _loadAllEquipment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Преобразуем тип активности в тип эквипа
      // run -> boots, bike -> bike
      final String equipmentType = _activityTypeToEquipmentType(
        widget.activityType,
      );

      if (equipmentType.isEmpty) {
        // Если тип активности не поддерживается — показываем только текущий эквип
        setState(() {
          _allEquipment = widget.items;
          _isLoading = false;
        });
        return;
      }

      // Загружаем весь эквип пользователя через API
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/get_equipment.php',
        body: {'user_id': widget.userId.toString()},
      );

      if (data['success'] == true) {
        // Получаем эквип нужного типа (boots или bikes)
        final List<dynamic> equipmentList = equipmentType == 'boots'
            ? data['boots'] ?? []
            : data['bikes'] ?? [];

        // Преобразуем в модель Equipment с equip_user_id
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

        // Исключаем уже показанный эквип (сравниваем по name и brand)
        // Создаем множество идентификаторов показанного эквипа
        final Set<String> shownEquipmentIds = widget.items
            .map((e) => '${e.brand}|${e.name}'.toLowerCase())
            .toSet();

        final List<al.Equipment> filteredEquipment = allEquipment
            .where(
              (e) => !shownEquipmentIds.contains(
                '${e.brand}|${e.name}'.toLowerCase(),
              ),
            )
            .toList();

        setState(() {
          _allEquipment = filteredEquipment;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Не удалось загрузить эквип';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки эквипа: $e';
        _isLoading = false;
      });
    }
  }

  /// Преобразует тип активности в тип эквипа
  /// run -> boots, bike -> bike
  String _activityTypeToEquipmentType(String activityType) {
    final String type = activityType.toLowerCase();
    if (type == 'run' || type == 'running') {
      return 'boots';
    } else if (type == 'bike' || type == 'cycling' || type == 'bicycle') {
      return 'bike';
    }
    return '';
  }

  /// Заменяет эквип в активности: обновляет activities.equip_id и пересчитывает дистанцию
  /// Если activityId == 0 (активность еще не создана), просто вызывает onEquipmentSelected
  Future<void> _replaceEquipment(al.Equipment newEquipment) async {
    // ────────────────────────────────────────────────────────────────
    // 🔹 ОСОБЫЙ СЛУЧАЙ: если активность еще не создана (activityId == 0)
    // ────────────────────────────────────────────────────────────────
    // Используем callback для выбора экипировки без вызова API
    if (widget.activityId == 0) {
      widget.onEquipmentSelected?.call(newEquipment);
      widget.onDismiss?.call(); // закрываем попап
      return;
    }

    if (newEquipment.equipUserId == null) {
      // Если нет equip_user_id — не можем заменить
      return;
    }

    // Получаем текущий эквип (который был показан в блоке)
    final currentEquipment = widget.items.isNotEmpty
        ? widget.items.first
        : null;
    if (currentEquipment == null || currentEquipment.equipUserId == null) {
      // Если нет текущего эквипа — не можем заменить
      return;
    }

    try {
      // Получаем userId из AuthService
      final auth = ref.read(authServiceProvider);
      final userId = await auth.getUserId();
      if (userId == null) return;

      // Вызываем API для замены эквипа
      final api = ref.read(apiServiceProvider);
      await api.post(
        '/replace_activity_equipment.php',
        body: {
          'user_id': userId.toString(),
          'activity_id': widget.activityId.toString(),
          'old_equip_user_id': currentEquipment.equipUserId.toString(),
          'new_equip_user_id': newEquipment.equipUserId.toString(),
          'distance_km': widget.activityDistance.toString(),
        },
      );

      // Вызываем callback для обновления UI
      widget.onEquipmentChanged?.call();
    } catch (e) {
      // Ошибка замены эквипа — можно показать сообщение
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 56,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            // ────────────────────────────────────────────────────────────────
            // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет индикатора загрузки
            // ────────────────────────────────────────────────────────────────
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextSecondary
                : AppColors.brandPrimary,
          ),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Text(
            _error!,
            style: AppTextStyles.h12w4.copyWith(
              // ────────────────────────────────────────────────────────────────
              // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет текста ошибки
              // ────────────────────────────────────────────────────────────────
              color: AppColors.getTextPrimaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Если нет эквипа — показываем сообщение
    if (_allEquipment.isEmpty) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'Нет другого эквипа',
            style: AppTextStyles.h12w4.copyWith(
              // ────────────────────────────────────────────────────────────────
              // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет текста пустого состояния
              // ────────────────────────────────────────────────────────────────
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 📏 ОГРАНИЧЕНИЕ КОЛИЧЕСТВА: показываем максимум 5 элементов
    // ────────────────────────────────────────────────────────────────
    final displayItems = _allEquipment.take(5).toList();
    final List<Widget> children = [];
    for (int i = 0; i < displayItems.length; i++) {
      if (i > 0) {
        children.add(
          Divider(
            height: 1,
            thickness: 0.5,
            // ────────────────────────────────────────────────────────────────
            // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет разделителя
            // ────────────────────────────────────────────────────────────────
            color: AppColors.getDividerColor(context),
            indent: 8,
            endIndent: 8,
          ),
        );
      }
      final item = displayItems[i];
      // Формируем полное название: бренд + название обуви
      // Если бренд есть — показываем "Бренд Название", иначе только название
      final String displayName = (item.brand.isNotEmpty && item.name.isNotEmpty)
          ? '${item.brand} ${item.name}'
          : item.name;
      children.add(
        _ShoeRow(
          imageUrl: item.img,
          name: displayName,
          mileageKm: item.mileage,
          onTap: () => _replaceEquipment(item),
        ),
      );
    }

    return Column(children: children);
  }
}

/// Одна строка 56px: слева 80px под картинку, справа — текстовый блок.
/// ────────────────────────────────────────────────────────────────
/// 📦 ИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БД: используем imageUrl из API
/// ────────────────────────────────────────────────────────────────
class _ShoeRow extends StatelessWidget {
  final String imageUrl;
  final String name;
  final int mileageKm;
  final VoidCallback? onTap;

  const _ShoeRow({
    required this.imageUrl,
    required this.name,
    required this.mileageKm,
    this.onTap,
  });

  /// Создает виджет строки эквипа (используется и в if, и в else)
  Widget _buildRowContent(BuildContext context) {
    return Row(
      children: [
        // Слева 80×56 - изображение из БД или заглушка
        Container(
          width: 80,
          height: 56,
          // ────────────────────────────────────────────────────────────────
          // 🌓 ТЕМНАЯ ТЕМА: фон контейнера такой же, как у попапа (darkSurfaceMuted)
          // ────────────────────────────────────────────────────────────────
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.getSurfaceColor(context),
          padding: const EdgeInsets.all(8),
          child: imageUrl.isNotEmpty
              ? Builder(
                  builder: (context) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final w = (64 * dpr).round();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: w,
                        maxWidthDiskCache: w,
                        placeholder: (context, url) => Container(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон placeholder
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getBackgroundColor(context),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              // ────────────────────────────────────────────────────────────────
                              // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет индикатора загрузки
                              // ────────────────────────────────────────────────────────────────
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          // ────────────────────────────────────────────────────────────────
                          // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон и цвет иконки ошибки
                          // ────────────────────────────────────────────────────────────────
                          color: AppColors.getBackgroundColor(context),
                          child: Icon(
                            Icons.sports_soccer,
                            size: 32,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    // ────────────────────────────────────────────────────────────────
                    // 🌓 ТЕМНАЯ ТЕМА: адаптивный фон и цвет иконки заглушки
                    // ────────────────────────────────────────────────────────────────
                    color: AppColors.getBackgroundColor(context),
                    child: Icon(
                      Icons.sports_soccer,
                      size: 32,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
        ),
        // Справа 208×56
        Expanded(
          child: Container(
            height: 56,
            // ────────────────────────────────────────────────────────────────
            // 🌓 ТЕМНАЯ ТЕМА: фон текстового блока такой же, как у попапа (darkSurfaceMuted)
            // ────────────────────────────────────────────────────────────────
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkSurfaceMuted
                : AppColors.getSurfaceColor(context),
            padding: const EdgeInsets.only(left: 5, top: 8, right: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "$name\n",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.7,
                      // ────────────────────────────────────────────────────────────────
                      // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет основного текста
                      // ────────────────────────────────────────────────────────────────
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  TextSpan(
                    text: "Пробег: ",
                    style: AppTextStyles.h11w4Sec.copyWith(
                      // ────────────────────────────────────────────────────────────────
                      // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет вторичного текста
                      // ────────────────────────────────────────────────────────────────
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                  TextSpan(
                    text: "$mileageKm",
                    style: AppTextStyles.h12w5.copyWith(
                      // ────────────────────────────────────────────────────────────────
                      // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет основного текста
                      // ────────────────────────────────────────────────────────────────
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  TextSpan(
                    text: " км",
                    style: AppTextStyles.h11w4Sec.copyWith(
                      // ────────────────────────────────────────────────────────────────
                      // 🌓 ТЕМНАЯ ТЕМА: адаптивный цвет вторичного текста
                      // ────────────────────────────────────────────────────────────────
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowContent = SizedBox(
      height: 56,
      width: double.infinity,
      child: _buildRowContent(context),
    );

    if (onTap == null) {
      // Если нет обработчика клика — возвращаем обычный виджет
      return rowContent;
    }

    // Если есть обработчик клика — оборачиваем в GestureDetector
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: rowContent,
    );
  }
}
