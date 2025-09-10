import 'package:flutter/material.dart';

/// Все отступы проекта
class AppSpacing {
  // 🔹 Фиксированные отступы (для мелких элементов)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  // 🔹 Адаптивные горизонтальные отступы
  static double horizontalSmall(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.02;

  static double horizontalMedium(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.05;

  static double horizontalLarge(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.10;

  // 🔹 Адаптивные вертикальные отступы
  static double verticalSmall(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.02;

  static double verticalMedium(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.05;

  static double verticalLarge(BuildContext context) =>
      MediaQuery.of(context).size.height * 0.10;
}
