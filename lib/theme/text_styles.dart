import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle name = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle commenttext = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  static const TextStyle date = TextStyle(fontSize: 12, color: Colors.grey);

  static const TextStyle body = TextStyle(fontSize: 16, color: AppColors.text);

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
}
