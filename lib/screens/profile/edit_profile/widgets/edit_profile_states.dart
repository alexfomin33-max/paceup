// ────────────────────────────────────────────────────────────────────────────
//  EDIT PROFILE STATES
//
//  Виджеты состояний для экрана редактирования профиля
//  (загрузка, ошибка)
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// ───────────────────────────── Панель загрузки ─────────────────────────────

/// Виджет состояния загрузки
class EditProfileLoadingPane extends StatelessWidget {
  const EditProfileLoadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: CupertinoActivityIndicator(),
      ),
    );
  }
}

/// ───────────────────────────── Панель ошибки ─────────────────────────────

/// Виджет состояния ошибки с возможностью повтора
class EditProfileErrorPane extends StatelessWidget {
  const EditProfileErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 28,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              'Ошибка загрузки:\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

