import 'package:flutter/material.dart';
import 'radius.dart';
import 'colors.dart';

class AppInputDecorations {
  static InputDecoration base({required Widget label}) {
    return InputDecoration(
      label: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    );
  }
}
