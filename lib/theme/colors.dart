import 'package:flutter/material.dart';

abstract class AppColors {
  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ БРЕНД / АКЦЕНТ                                                        │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color brandPrimary = Color(0xFF379AE6);
  static const Color brandSecondary = Color(0xFF5856D6); // iOS Indigo
  // iOS Green (как доп. акцент)
  static const Color brandTertiary = Color(0xFF34C759);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ТЕКСТ                                                                 │
  // └───────────────────────────────────────────────────────────────────────┘
  // Базовый «почти чёрный» (iOS label)
  static const Color textPrimary = Color(0xFF1C1C1E);
  // Вторичный (подписи, метаданные)
  static const Color textSecondary = Color(0xFF6C6C70);
  // Третичный (менее значимый, еле заметный)
  static const Color textTertiary = Color(0xFF8E8E93);
  // Плейсхолдеры/disabled
  static const Color textPlaceholder = Color(0xFFA3A3A8);
  // Интерактивные ссылки
  static const Color link = brandPrimary;

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ФОНЫ / ПОВЕРХНОСТИ                                                    │
  // └───────────────────────────────────────────────────────────────────────┘
  // Системные iOS-лайк фоны
  static const Color background = Color(0xFFF2F2F7); // systemGroupedBackground
  static const Color softBg = Color(0xFFF5F5F5);
  // основная поверхность (карточки)
  static const Color surface = Color(0xFFFFFFFF);
  // слегка приглушённая поверхность
  static const Color surfaceMuted = Color(0xFFFAFAFC);
  static const Color disabled = Color(0xFFF7F7FA);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ РАЗДЕЛИТЕЛИ / БОРДЕРЫ / СТРОКИ                                       │
  // └───────────────────────────────────────────────────────────────────────┘
  // iOS separator: обычно это полупрозрачный тёмный на белом.
  // Мы даём уже просчитанные светлые значения, чтобы не возиться с альфой.
  static const Color divider = Color(0xFFE5E5EA); // тонкая линия-разделитель
  static const Color border = Color(0xFFEAEAEA); // очень лёгкая рамка
  // более заметный бордер (для инпутов)
  static const Color outline = Color(0xFFDADDE2);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ СОСТОЯНИЯ / СИГНАЛЫ                                                   │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color success = Color(0xFF34C759); // iOS Green
  static const Color warning = Color(0xFFFF9500); // iOS Orange
  static const Color error = Color(0xFFFF3B30); // iOS Red
  // iOS Light Blue (инфо/подсказки)
  static const Color info = Color(0xFF5AC8F5);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ИКОНКИ                                                                │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color iconPrimary = textPrimary; // основные иконки
  static const Color iconSecondary = textSecondary; // вторичные/неактивные
  static const Color iconTertiary = textTertiary; // ещё слабее

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ЧИПЫ / ПИЛЮЛИ / ПЛАШКИ                                                │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color chipBg = Color(0xFFF3F5F7);
  static const Color chipBorder = Color(0xFFE3E6EA);
  static const Color chipText = textSecondary;
  // для «новое»/badge (синеватый)
  static const Color badgeBg = Color(0xFFEFF4FF);
  static const Color badgeText = Color(0xFF2B59C3);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ОВЕРЛЕИ / СКРИМ / СТЁКЛО / ТЕНИ                                       │
  // └───────────────────────────────────────────────────────────────────────┘
  // Прозрачные чёрные слои (альфа зашита в HEX):
  static const Color scrim10 = Color(0x19000000); // 10% — очень лёгкий
  static const Color scrim20 = Color(0x33000000); // 20% — стандартный скрим
  static const Color scrim40 = Color(0x66000000); // 40% — для модалок
  static const Color scrim90 = Color(0xE6000000); // ≈90% — почти чёрный экран

  // Тени (мягкие iOS-лайк)
  static const Color shadowSoft = Color(0x14000000); // ~8%   (карточки)
  static const Color shadowMedium = Color(0x26000000); // ~15%  (всплывающие)
  static const Color shadowStrong = Color(0x40000000); // ~25%  (флоат-элементы)

  // «Стекло» для блюра (фон и бордеры поверх blur)
  static const Color glassTint = Color(0x99FFFFFF); // 60% белый
  static const Color glassStroke = Color(0x66FFFFFF); // 40% белый контур

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ДИЗАБЛЕД / СКЕЛЕТОН                                                   │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color disabledBg = Color(0xFFF2F2F2);
  static const Color disabledText = Color(0xFFB9BBC1);
  static const Color skeletonBase = Color(0xFFE9EBF0);
  static const Color skeletonGlow = Color(0xFFF6F7FB);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ДОП. АКЦЕНТЫ (iOS-палитра)                                            │
  // └───────────────────────────────────────────────────────────────────────┘
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentIndigo = Color(0xFF5856D6);
  static const Color accentPurple = Color(0xFFAF52DE);
  static const Color accentPink = Color(0xFFFF2D55);
  static const Color accentTeal = Color(0xFF30B0C7);
  static const Color accentMint = Color(0xFF00C7BE);
  static const Color accentYellow = Color(0xFFFFCC00);

  static const Color gray = Color(0xFF8E8E93);
  static const Color indigo = Color(0xFF5856D6);
  static const Color purple = Color(0xFFAF52DE);
  static const Color blue = Color(0xFF007AFF);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color mint = Color(0xFF00C7BE);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color yellow = Color(0xFFFFCC00);
  static const Color red = Color(0xFFFF3B30);
  static const Color pink = Color(0xFFFF2D55);

  static Color indigoBg = indigo.withValues(alpha: 0.06);
  static Color purpleBg = purple.withValues(alpha: 0.06);
  static Color blueBg = blue.withValues(alpha: 0.06);
  static Color orangeBg = orange.withValues(alpha: 0.06);
  static Color greenBg = green.withValues(alpha: 0.06);
  static Color redBg = red.withValues(alpha: 0.06);

  static Color indigoBr = indigo.withValues(alpha: 0.22);
  static Color purpleBr = purple.withValues(alpha: 0.22);
  static Color blueBr = blue.withValues(alpha: 0.22);
  static Color orangeBr = orange.withValues(alpha: 0.22);
  static Color greenBr = green.withValues(alpha: 0.10);
  static Color redBr = red.withValues(alpha: 0.22);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ СПЕЦИАЛЬНЫЕ (под ваш проект)                                          │
  // └───────────────────────────────────────────────────────────────────────┘
  // Чат-пузырь (как у тебя было)
  static const Color chatBubble = Color(0xFFDBFFDC);
  // Имена в чате
  static const Color nameMale = Color(0xFF197DCA);
  static const Color nameFemale = Color(0xFFE02862);
  // Премиальные/«золото»
  static const Color gold = Color(0xFFECA517);
  // Цвет букв "UP" в логотипе (яркий салатовый/лайм-зеленый)
  static const Color greenUP = Color(0xFF9bec28);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ АЛИАСЫ ДЛЯ СОВМЕСТИМОСТИ (СТАРЫЕ ИМЕНА → НОВЫЕ ТОКЕНЫ)                │
  // └───────────────────────────────────────────────────────────────────────┘

  // Фоны
  static const Color backgroundRed = Color(0xFFFDF2F2);
  static const Color backgroundYellow = Color(0xFFFFF6E2);
  static const Color backgroundGreen = Color(0xFFEEFDF3);
  static const Color backgroundBlue = Color(0xFFE8F5FF);
  static const Color backgroundPurple = Color(0xFFF7F0FF);
  static const Color backgroundMint = Color(0xFFE8F7F1);

  static const Color female = Color(0xFFE8618C);
  static const Color bgfemale = Color(0xFFFDF1F5);
  static const Color male = Color(0xFF379AE6);
  static const Color bgmale = Color(0xFFF1F8FD);
  static const Color price = Color(0xFF98690C);
  static const Color cancel = Color(0xFFD32F2F);
  static const Color accept = Color(0xFF2E7D32);
  static const Color bordercancel = Color(0xFFF6CACA);
  static const Color borderaccept = Color(0xFFD7EDCF);

  // ┌───────────────────────────────────────────────────────────────────────┐
  // │ ТЕМНАЯ ТЕМА                                                           │
  // └───────────────────────────────────────────────────────────────────────┘

  /// Получить цвет фона в зависимости от темы
  static Color getBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkBackground : background;
  }

  /// Получить цвет поверхности в зависимости от темы
  static Color getSurfaceColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkSurface : surface;
  }

  /// Получить основной цвет текста в зависимости от темы
  static Color getTextPrimaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextPrimary : textPrimary;
  }

  /// Получить вторичный цвет текста в зависимости от темы
  static Color getTextSecondaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextSecondary : textSecondary;
  }

  /// Получить третичный цвет текста в зависимости от темы
  static Color getTextTertiaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkTextTertiary : textTertiary;
  }

  /// Получить цвет разделителя в зависимости от темы
  static Color getDividerColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkDivider : divider;
  }

  /// Получить цвет бордера в зависимости от темы
  static Color getBorderColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkBorder : border;
  }

  /// Получить приглушенный цвет поверхности в зависимости от темы
  static Color getSurfaceMutedColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkSurfaceMuted : surfaceMuted;
  }

  /// Получить цвет иконки в зависимости от темы
  static Color getIconPrimaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkIconPrimary : iconPrimary;
  }

  /// Получить вторичный цвет иконки в зависимости от темы
  static Color getIconSecondaryColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? darkIconSecondary : iconSecondary;
  }

  /// Получить цвет плейсхолдера в зависимости от темы
  static Color getTextPlaceholderColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? darkTextPlaceholder
        : textPlaceholder;
  }

  // Темные цвета (iOS Dark Mode)
  static const Color darkBackground = Color(0xFF121212); // темно-серый фон
  static const Color darkSurface = Color(0xFF1C1C1E); // iOS dark surface
  static const Color darkSurfaceMuted = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFE9E9E9);
  static const Color darkTextSecondary = Color(0xFF98989D);
  static const Color darkTextTertiary = Color(0xFF6C6C70);
  static const Color darkTextPlaceholder = Color(
    0xFF6C6C70,
  ); // плейсхолдер в темной теме
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkBorder = Color(0xFF48484A);
  static const Color darkIconPrimary = Color(0xFFE9E9E9);
  static const Color darkIconSecondary = Color(0xFF98989D);
  static const Color darkShadowSoft = Color(
    0x40000000,
  ); // более заметная тень в темной теме
}
