import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    fontFamily: 'Inter',
  );

  static const TextStyle name = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
    fontFamily: 'Inter',
  );

  static const TextStyle date = TextStyle(
    fontSize: 12,
    color: Colors.grey,
    fontFamily: 'Inter',
  );

  static const TextStyle body = TextStyle(fontSize: 16, color: AppColors.text);

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
}
