import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../core/widgets/transparent_route.dart';
import 'all_results/segment_all_results_screen.dart';
import 'my_results/segment_my_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Данные для контента нижнего листа описания участка.
// ─────────────────────────────────────────────────────────────────────────────
class SegmentDescriptionSheetData {
  const SegmentDescriptionSheetData({
    required this.title,
    required this.sportTypeText,
    required this.sportTypeIcon,
    required this.distanceText,
    required this.ascentText,
    required this.paceOrSpeedText,
    required this.heartRateText,
    required this.personalBestText,
    required this.myAttemptsCount,
    required this.hasMyResult,
    required this.segmentId,
    required this.userId,
    required this.onPersonalBestTap,
  });

  final String title;
  final String sportTypeText;
  final IconData sportTypeIcon;
  final String distanceText;
  final String ascentText;
  final String paceOrSpeedText;
  final String heartRateText;
  final String personalBestText;
  final int myAttemptsCount;
  final bool hasMyResult;
  final int segmentId;
  final int userId;
  final VoidCallback? onPersonalBestTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// Контент нижнего листа: внешний вид как у маршрутов.
// ─────────────────────────────────────────────────────────────────────────────
class SegmentDescriptionBottomSheetContent extends StatelessWidget {
  const SegmentDescriptionBottomSheetContent({
    super.key,
    required this.scrollController,
    required this.dragController,
    required this.data,
  });

  final ScrollController scrollController;
  final DraggableScrollableController dragController;
  final SegmentDescriptionSheetData data;

  @override
  Widget build(BuildContext context) {
    final myResultsText = data.hasMyResult
        ? 'Попыток: ${data.myAttemptsCount}'
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xll),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: AppSpacing.sm,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        slivers: [
          // ── Планка-хэндл
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dragController.animateTo(
                  0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Center(
                  child: Container(
                    width: AppSpacing.lg,
                    height: AppSpacing.xs,
                    decoration: BoxDecoration(
                      color: AppColors.getBorderColor(context),
                      borderRadius:
                          BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Заголовок
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                dragController.animateTo(
                  0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                color: AppColors.getSurfaceColor(context),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  data.title,
                  textAlign: TextAlign.start,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),
          ),
          // ── Метрики под названием
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _MetricChip(
                    icon: data.sportTypeIcon,
                    value: data.sportTypeText,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  _MetricChip(
                    icon: Icons.straighten,
                    value: data.distanceText,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  _MetricChip(
                    icon: CupertinoIcons.arrow_up,
                    value: data.ascentText,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  _MetricChip(
                    icon: Icons.speed,
                    value: data.paceOrSpeedText,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  _MetricChip(
                    icon: CupertinoIcons.heart,
                    value: data.heartRateText,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
          // ── Карточка действий
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Container(
                decoration: _cardDecoration(context),
                child: Column(
                  children: [
                    _ActionRow(
                      icon: CupertinoIcons.rosette,
                      title: 'Личный рекорд',
                      trailingText: data.personalBestText
                          .replaceAll(' мин', ''),
                      trailingChevron: true,
                      onTap: data.onPersonalBestTap,
                    ),
                    _ActionRow(
                      icon: CupertinoIcons.timer,
                      title: 'Мои результаты',
                      trailingText: myResultsText,
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => SegmentMyResultsScreen(
                              segmentId: data.segmentId,
                              segmentTitle: data.title,
                              userId: data.userId,
                            ),
                          ),
                        );
                      },
                    ),
                    _ActionRow(
                      icon: CupertinoIcons.chart_bar_alt_fill,
                      title: 'Общие результаты',
                      trailingChevron: true,
                      onTap: () {
                        Navigator.of(context).push(
                          TransparentPageRoute(
                            builder: (_) => SegmentAllResultsScreen(
                              segmentId: data.segmentId,
                              segmentTitle: data.title,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Компактная метрика: иконка + значение.
// ─────────────────────────────────────────────────────────────────────────────
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Строка действий (стиль settings_screen).
// ─────────────────────────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailingChevron = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final bool trailingChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final defaultTextColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              alignment: Alignment.centerLeft,
              child: Icon(icon, size: 20, color: AppColors.brandPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(color: defaultTextColor),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (trailingChevron)
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: AppColors.brandPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: AppColors.getSurfaceColor(context),
      borderRadius: const BorderRadius.all(
        Radius.circular(AppRadius.lg),
      ),
      border: const Border.fromBorderSide(
        BorderSide(color: AppColors.twinchip, width: 0.7),
      ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkShadowSoft
              : AppColors.shadowMedium,
          offset: const Offset(0, 2),
          blurRadius: AppSpacing.sm,
          spreadRadius: 0,
        ),
      ],
    );
