import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle normaltext = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle softtext = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  static const TextStyle name = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle date = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle numberstat = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle smallsofttext = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  static const TextStyle commenttext = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  // static const TextStyle body = TextStyle(fontSize: 16);

  // static const TextStyle button = TextStyle(
  //   fontSize: 14,
  //   fontWeight: FontWeight.w500,
  // );
}
