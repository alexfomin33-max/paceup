// lib/widgets/app_bar.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Универсальная шапка проекта.
/// Использование:
///   appBar: PaceAppBar(
///     title: 'Уведомления',
///     actions: [IconButton(...)]
///   )
///
/// По умолчанию:
///  • центрированный заголовок,
///  • кнопка «назад» слева (можно отключить),
///  • разделитель снизу,
///  • без теней/тонального тинта (iOS-лайк).
class PaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title; // Текстовый заголовок
  final Widget? titleWidget; // Или свой виджет заголовка
  final bool centerTitle;

  final Widget? leading; // Кастомный leading
  final bool showBack; // Показать дефолтную «назад»
  final VoidCallback? onBack; // Свой обработчик «назад»
  final double leadingWidth;

  final List<Widget>? actions; // Правые иконки

  final bool showBottomDivider; // Разделитель снизу
  final Color? backgroundColor; // Фон шапки
  final Color surfaceTintColor; // M3-тональный тинт
  final double elevation; // Тень в статике
  final double scrolledUnderElevation; // Тень при скролле под шапкой
  final Color? shadowColor; // Цвет тени

  const PaceAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.centerTitle = true,
    this.leading,
    this.showBack = true,
    this.onBack,
    this.leadingWidth = 56,
    this.actions,
    this.showBottomDivider = true,
    this.backgroundColor,
    this.surfaceTintColor = Colors.transparent,
    this.elevation = 1,
    this.scrolledUnderElevation = 1,
    this.shadowColor,
  }) : assert(
         title != null || titleWidget != null,
         'Передайте title или titleWidget',
       );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Используем цвета из темы
    final bgColor = backgroundColor ?? AppColors.getSurfaceColor(context);
    final iconColor = AppColors.getIconPrimaryColor(context);
    final borderColor = AppColors.getBorderColor(context);
    final shadowColorValue = shadowColor ?? 
        (Theme.of(context).brightness == Brightness.dark 
            ? AppColors.darkShadowSoft 
            : AppColors.shadowSoft);
    
    return AppBar(
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColorValue,
      backgroundColor: bgColor,
      surfaceTintColor: surfaceTintColor,
      centerTitle: centerTitle,
      leadingWidth: leadingWidth,

      // Приоритет: кастомный leading → стандартная «назад» → null
      leading:
          leading ??
          (showBack
              ? IconButton(
                  splashRadius: 22,
                  icon: Icon(
                    CupertinoIcons.back,
                    size: 22,
                    color: iconColor,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                )
              : null),

      // Заголовок: свой виджет → текст
      title: titleWidget ??
          Text(
            title!,
            style: AppTextStyles.h17w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),

      actions: actions,

      // Тонкая линия снизу, если нужно
      bottom: showBottomDivider
          ? PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: borderColor,
              ),
            )
          : null,
    );
  }
}
