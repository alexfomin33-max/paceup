// lib/screens/lenta/widgets/activity/equipment/equipment_chip.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/models/activity_lenta.dart' as al;
import 'equipment_popup.dart';
import '../../../../../core/theme/app_theme.dart';

/// Чип экипировки с якорным попапом (поведение как в дорефакторинговом Equipment).
/// Важные детали пиксель-паритета:
/// - Общая высота 56, фон #F3F4F6, радиус 28
/// - Внутренний горизонтальный паддинг 10 (снаружи ActivityBlock уже даёт 6)
/// - Картинка 50×50 с радиусом 25 (позиционирование left:3, top/bottom:3)
/// - Кнопка справа 28×28, белая, иконка CupertinoIcons.ellipsis size:16
class EquipmentChip extends StatefulWidget {
  final List<al.Equipment> items;
  final int userId; // ID пользователя для загрузки всего эквипа
  final String
  activityType; // тип активности (run, bike) для определения типа эквипа
  final int activityId; // ID активности для обновления эквипа
  final double activityDistance; // дистанция активности в километрах
  final VoidCallback? onEquipmentChanged; // callback после замены эквипа
  final bool showMenuButton; // показывать ли кнопку меню с тремя точками
  final Function(al.Equipment)?
  onEquipmentSelected; // callback для выбора экипировки (для экрана добавления)
  final Color?
  backgroundColor; // опциональный цвет фона плашки (для переопределения на конкретных экранах)
  final Color?
  menuButtonColor; // опциональный цвет фона кнопки меню (для переопределения на конкретных экранах)

  const EquipmentChip({
    super.key,
    required this.items,
    required this.userId,
    required this.activityType,
    required this.activityId,
    this.activityDistance = 0.0,
    this.onEquipmentChanged,
    this.showMenuButton =
        true, // по умолчанию показываем кнопку для обратной совместимости
    this.onEquipmentSelected,
    this.backgroundColor,
    this.menuButtonColor,
  });

  @override
  State<EquipmentChip> createState() => _EquipmentChipState();
}

class _EquipmentChipState extends State<EquipmentChip> {
  // ключ для вычисления позиции кнопки — сюда якорим попап
  final GlobalKey _menuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // ────────────────────────────────────────────────────────────────
    // 📦 ИСПОЛЬЗОВАНИЕ ДАННЫХ ИЗ БД: убираем жестко вбитые значения
    // ────────────────────────────────────────────────────────────────
    // Если нет данных об экипировке, не показываем чип
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final al.Equipment e = widget.items.first;
    // Используем данные из API, если они есть
    final String name = e.name.trim();
    final String brand = e.brand.trim(); // получаем бренд из модели
    final int mileage = e.mileage;
    final String img = e.img;

    // Формируем полное название: бренд + название обуви
    // Если бренд есть — показываем "Бренд Название", иначе только название
    final String displayName = brand.isNotEmpty ? '$brand $name' : name;

    // Если имя пустое, не показываем чип
    if (name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      // как было в исходном Equipment: внутренний паддинг 10
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          // ────────────────────────────────────────────────────────────────
          // 🌓 ТЕМНАЯ ТЕМА: плашка экипировки светлее карточки тренировки
          // ────────────────────────────────────────────────────────────────
          // В темной теме используем darkSurfaceMuted (светлее darkSurface карточки)
          // В светлой теме оставляем getBackgroundColor (как было)
          // Если передан backgroundColor, используем его (для переопределения на конкретных экранах)
          color:
              widget.backgroundColor ??
              (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.getBackgroundColor(context)),
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Stack(
          children: [
            // аватарка обуви
            Positioned(
              left: 3,
              top: 3,
              bottom: 3,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  // ────────────────────────────────────────────────────────────────
                  // 🌓 ТЕМНАЯ ТЕМА: светлый фон круга за картинкой
                  // ────────────────────────────────────────────────────────────────
                  // В темной теме используем белый цвет для контраста
                  // В светлой теме оставляем getSurfaceColor (как было)
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surface
                      : AppColors.getSurfaceColor(context),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: img.isNotEmpty
                      ? Builder(
                          builder: (context) {
                            final dpr = MediaQuery.of(context).devicePixelRatio;
                            final w = (50 * dpr).round();
                            return CachedNetworkImage(
                              imageUrl: img,
                              width: 50,
                              height: 50,
                              fit: BoxFit.contain,
                              memCacheWidth: w,
                              maxWidthDiskCache: w,
                              placeholder: (context, url) => Container(
                                width: 50,
                                height: 50,
                                // ────────────────────────────────────────────────────────────────
                                // 🌓 ТЕМНАЯ ТЕМА: светлый фон placeholder
                                // ────────────────────────────────────────────────────────────────
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.surface
                                    : AppColors.getSurfaceColor(context),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  // ────────────────────────────────────────────────────────────────
                                  // 🌓 ТЕМНАЯ ТЕМА: светлый фон error widget
                                  // ────────────────────────────────────────────────────────────────
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.surface
                                      : AppColors.getSurfaceColor(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.sportscourt,
                                  size: 24,
                                  color: AppColors.getIconSecondaryColor(
                                    context,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            // ────────────────────────────────────────────────────────────────
                            // 🌓 ТЕМНАЯ ТЕМА: светлый фон заглушки
                            // ────────────────────────────────────────────────────────────────
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.surface
                                : AppColors.getSurfaceColor(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.sportscourt,
                            size: 24,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                ),
              ),
            ),
            // текст
            // ────────────────────────────────────────────────────────────────
            // 📏 ПРАВАЯ ГРАНИЦА: резервируем место для кнопки только если она видима
            // ────────────────────────────────────────────────────────────────
            Positioned(
              left: 60,
              top: 7,
              right: widget.showMenuButton
                  ? 60
                  : 8, // резервируем место только если кнопка видна
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "$displayName\n",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.8,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    TextSpan(
                      text: "Пробег: ",
                      style: AppTextStyles.h11w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                    TextSpan(
                      text: "$mileage",
                      style: AppTextStyles.h12w5.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    TextSpan(
                      text: " км",
                      style: AppTextStyles.h11w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // кнопка вызова попапа (якорь)
            // ────────────────────────────────────────────────────────────────
            // 🔹 Показываем только если showMenuButton = true
            // ────────────────────────────────────────────────────────────────
            if (widget.showMenuButton)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => EquipmentPopup.showAnchored(
                      context,
                      anchorKey: _menuKey,
                      items: widget.items,
                      userId: widget.userId,
                      activityType: widget.activityType,
                      activityId: widget.activityId,
                      activityDistance: widget.activityDistance,
                      onEquipmentChanged: widget.onEquipmentChanged,
                      onEquipmentSelected: widget.onEquipmentSelected,
                    ),
                    child: Container(
                      key:
                          _menuKey, // ← важный ключ для позиционирования попапа
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        // ────────────────────────────────────────────────────────────────
                        // 🌓 ТЕМНАЯ ТЕМА: фон кружка такой же, как карточка тренировки
                        // ────────────────────────────────────────────────────────────────
                        // В темной теме используем darkSurface (как карточка тренировки)
                        // В светлой теме оставляем getSurfaceColor (как было)
                        // Если передан menuButtonColor, используем его (для переопределения на конкретных экранах)
                        color:
                            widget.menuButtonColor ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurface
                                : AppColors.getSurfaceColor(context)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.ellipsis,
                        size: 16,
                        color: AppColors.getIconPrimaryColor(context),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
