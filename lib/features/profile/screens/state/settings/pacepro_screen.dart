// lib/features/profile/screens/state/settings/pacepro_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//                          PACEPRO: ЭКРАН ПОДПИСКИ / PAYWALL
//
// Задачи экрана:
// - Показать ценность подписки (что открывается в PacePro).
// - Дать пользователю понятный CTA «Оформить/Управлять».
// - Подготовить место под будущую интеграцию In‑App Purchases.
//
// ВАЖНО: используем только токены AppTheme (цвета/радиусы/текст).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/app_bar.dart';
import '../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../providers/pacepro_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//                                  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PaceProScreen extends ConsumerWidget {
  const PaceProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(paceProStatusProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.twinBg,
        appBar: const PaceAppBar(
          title: 'PacePro',
          backgroundColor: AppColors.twinBg,
          showBack: true,
          showBottomDivider: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: SafeArea(
          bottom: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            physics: const BouncingScrollPhysics(),
            children: [
              // ─────────── Hero: лого + статус ───────────
              _HeroCard(
                isActive: isActive,
                onToggleDebug: kDebugMode
                    ? () async {
                        await ref
                            .read(paceProStatusProvider.notifier)
                            .setActive(!isActive);
                      }
                    : null,
              ),

              const SizedBox(height: 12),

              // ─────────── Что входит в подписку ───────────
              const _SectionTitle('Что открывается в PacePro'),
              const SizedBox(height: 8),
              const _FeaturesCard(
                items: [
                  _FeatureItem(
                    icon: CupertinoIcons.bell,
                    title: 'Оповещения о слотах',
                    subtitle:
                        'Создавайте оповещения и получайте уведомления о новых '
                        'слотах под ваши критерии.',
                    isKeyFeature: true,
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.play_circle,
                    title: 'Истории (Stories)',
                    subtitle:
                        'Короткие видео‑истории как в Instagram/VK: делитесь '
                        'моментами тренировок и соревнований.',
                    isKeyFeature: true,
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.chart_bar,
                    title: 'Расширенная аналитика',
                    subtitle:
                        'Глубокая статистика по неделям/месяцам: темп, набор '
                        'высоты, зоны ЧСС, сравнение прогресса.',
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.map,
                    title: 'Маршруты и экспорт',
                    subtitle:
                        'Экспорт/импорт маршрутов и тренировок (GPX) и удобное '
                        'планирование маршрутов.',
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.sparkles,
                    title: 'Премиальные челленджи',
                    subtitle:
                        'Доступ к закрытым соревнованиям/лигам и наградам в '
                        'приложении.',
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.chat_bubble_2,
                    title: 'Приоритетная поддержка',
                    subtitle:
                        'Быстрее ответы по проблемам, данным и синхронизации.',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─────────── Скоро в PacePro ───────────
              const _SectionTitle('Скоро'),
              const SizedBox(height: 8),
              const _FeaturesCard(
                items: [
                  _FeatureItem(
                    icon: CupertinoIcons.bolt,
                    title: 'Умные планы тренировок',
                    subtitle:
                        'Готовые планы под цель (5/10/21/42 км, триатлон) с '
                        'адаптацией под ваш прогресс.',
                    isUpcoming: true,
                  ),
                  _FeatureItem(
                    icon: CupertinoIcons.square_stack_3d_up,
                    title: 'Больше инструментов для контента',
                    subtitle:
                        'Шаблоны для сторис, обложки, автосбор хайлайтов по '
                        'тренировкам.',
                    isUpcoming: true,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ─────────── Управление / CTA ───────────
              _ManageCard(
                isActive: isActive,
                onSubscribePressed: () async {
                  // ─────────── Пока заглушка: реальный биллинг подключим позже ───────────
                  await _showNotReadyDialog(context);
                },
                onRestorePressed: () async {
                  // ─────────── Заглушка: восстановление покупок ───────────
                  await _showNotReadyDialog(context);
                },
              ),

              // ─────────── Debug-only: быстрый тест флоу без биллинга ───────────
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                _DebugCard(
                  isActive: isActive,
                  onSetActive: (value) async {
                    await ref
                        .read(paceProStatusProvider.notifier)
                        .setActive(value);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                              LOCAL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final bool isActive;

  /// Debug-удобство: длинное нажатие по лого может переключать статус.
  /// В релизе callback не передаём, поэтому ничего не меняется визуально.
  final VoidCallback? onToggleDebug;

  const _HeroCard({
    required this.isActive,
    required this.onToggleDebug,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isActive ? 'Активна' : 'Не активна';
    final statusColor = isActive ? AppColors.success : AppColors.textTertiary;
    final statusBg = isActive ? AppColors.greenBg : AppColors.badgeBg;

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          // ─────────── Лого PacePro ───────────
          GestureDetector(
            onLongPress: onToggleDebug,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.asset(
                'assets/pacepro.png',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PacePro — больше возможностей',
                  style: AppTextStyles.h15w6.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Оповещения, истории и расширенная аналитика.',
                  style: AppTextStyles.h13w4Sec.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.xl),
              ),
              border: Border.all(
                color: AppColors.twinchip,
                width: 1,
              ),
            ),
            child: Text(
              statusText,
              style: AppTextStyles.h12w5.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageCard extends StatelessWidget {
  final bool isActive;
  final VoidCallback onSubscribePressed;
  final VoidCallback onRestorePressed;

  const _ManageCard({
    required this.isActive,
    required this.onSubscribePressed,
    required this.onRestorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─────────── Заголовок блока ───────────
          Text(
            isActive ? 'Управление подпиской' : 'Оформить подписку',
            style: AppTextStyles.h14w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Подписка включает платные функции и поддерживает развитие PaceUp.',
            style: AppTextStyles.h13w4Sec.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 12),

          // ─────────── CTA ───────────
          PrimaryButton(
            text: isActive ? 'Управлять подпиской' : 'Оформить PacePro',
            expanded: true,
            onPressed: onSubscribePressed,
          ),
          const SizedBox(height: 10),

          // ─────────── Восстановление покупок ───────────
          PrimaryButton(
            text: 'Восстановить покупку',
            expanded: true,
            onPressed: onRestorePressed,
            // Немного “вторичности” через отключение?
            // Пока оставляем как primary, чтобы не вводить новый дизайн.
          ),
        ],
      ),
    );
  }
}

class _DebugCard extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onSetActive;

  const _DebugCard({
    required this.isActive,
    required this.onSetActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Debug',
            style: AppTextStyles.h14w6.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Переключатель нужен, чтобы тестировать ограничения платных функций '
            'до подключения биллинга.',
            style: AppTextStyles.h13w4Sec.copyWith(
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: isActive,
            children: const {
              false: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('Free'),
              ),
              true: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text('PacePro'),
              ),
            },
            onValueChanged: (value) {
              if (value == null) return;
              onSetActive(value);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.h14w6.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  final List<_FeatureItem> items;
  const _FeaturesCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _FeatureRow(item: items[i]),
            if (i != items.length - 1) const _Divider(),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isKeyFeature;
  final bool isUpcoming;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isKeyFeature = false,
    this.isUpcoming = false,
  });
}

class _FeatureRow extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final iconColor = item.isUpcoming ? AppColors.textTertiary : AppColors.brandPrimary;
    final badgeText = item.isUpcoming ? 'Скоро' : (item.isKeyFeature ? 'Pro' : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            alignment: Alignment.centerLeft,
            child: Icon(item.icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTextStyles.h14w5.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      _Badge(text: badgeText),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: AppTextStyles.h13w4Sec.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.badgeBg,
        borderRadius: const BorderRadius.all(
          Radius.circular(AppRadius.xl),
        ),
        border: Border.all(
          color: AppColors.twinchip,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTextStyles.h11w5Sec.copyWith(
          color: AppColors.badgeText,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final hairline = 0.7 / MediaQuery.of(context).devicePixelRatio;
    return Container(
      margin: const EdgeInsets.only(left: 48, right: 12),
      height: hairline,
      color: AppColors.getDividerColor(context),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//                                 HELPERS
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: AppColors.getSurfaceColor(context),
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
      border: const Border.fromBorderSide(
        BorderSide(color: AppColors.twinchip, width: 0.7),
      ),
    );

Future<void> _showNotReadyDialog(BuildContext context) async {
  // ─────────── Диалог-объяснение (пока без биллинга) ───────────
  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Скоро'),
      content: const Text(
        'Оплата подписки будет добавлена позже. Сейчас экран нужен для '
        'проектирования и ограничения платных функций.',
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}

