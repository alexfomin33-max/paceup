import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/segments_service.dart';
import '../../../../../../core/utils/activity_format.dart';
import '../../../../../../providers/services/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Формат дистанции: до 2 знаков после запятой (как в маршрутах).
// ─────────────────────────────────────────────────────────────────────────────
String _formatDistanceKm(double km) {
  final truncated = (km * 100).truncateToDouble() / 100;
  return truncated.toStringAsFixed(2);
}

/// Провайдер: участки с результатами текущего пользователя (Мои + Все).
final segmentsWithMyResultsProvider =
    FutureProvider.family<SegmentsWithMyResults, int>(
  (ref, userId) async {
    if (userId <= 0) {
      return const SegmentsWithMyResults(
        mySegments: [],
        otherSegments: [],
      );
    }
    return SegmentsService().getSegmentsWithMyResults(userId);
  },
);

/// Вкладка «Участки»: два блока — «Мои участки» и «Все участки», с результатами.
class SegmentsContent extends ConsumerStatefulWidget {
  const SegmentsContent({super.key});

  @override
  ConsumerState<SegmentsContent> createState() => _SegmentsContentState();
}

class _SegmentsContentState extends ConsumerState<SegmentsContent> {
  bool _didRequestRefresh = false;

  @override
  Widget build(BuildContext context) {
    if (!_didRequestRefresh) {
      _didRequestRefresh = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uid = ref.read(currentUserIdProvider).valueOrNull ?? 0;
        if (uid > 0) ref.invalidate(segmentsWithMyResultsProvider(uid));
      });
    }
    final userIdAsync = ref.watch(currentUserIdProvider);
    return userIdAsync.when(
      data: (userId) {
        final uid = userId ?? 0;
        final dataAsync = ref.watch(segmentsWithMyResultsProvider(uid));
        return dataAsync.when(
          data: (data) {
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + 60 + 12;
            final hasMy = data.mySegments.isNotEmpty;
            final hasOther = data.otherSegments.isNotEmpty;
            if (!hasMy && !hasOther) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'Нет участков',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
                ],
              );
            }
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (hasMy) ...[
                        _SectionTitle(title: 'Мои участки'),
                        ...data.mySegments.asMap().entries.map((e) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: e.key < data.mySegments.length - 1
                                  ? 6
                                  : (hasOther ? 16 : 0),
                            ),
                            child: _SegmentWithResultCard(segment: e.value),
                          );
                        }),
                      ],
                      if (hasOther) ...[
                        _SectionTitle(title: 'Все участки'),
                        ...data.otherSegments.asMap().entries.map((e) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: e.key < data.otherSegments.length - 1
                                  ? 6
                                  : 0,
                            ),
                            child: _SegmentWithResultCard(segment: e.value),
                          );
                        }),
                      ],
                    ]),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
              ],
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(
              radius: 12,
              color: AppColors.brandPrimary,
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText.rich(
                TextSpan(
                  text: 'Ошибка: ${e.toString()}',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CupertinoActivityIndicator(
          radius: 12,
          color: AppColors.brandPrimary,
        ),
      ),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText.rich(
            TextSpan(
              text: 'Ошибка: ${e.toString()}',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок блока (Мои участки / Все участки).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextSecondaryColor(context),
        ),
      ),
    );
  }
}

/// Карточка участка: название, под ним строка метрик с иконками
/// (позиция, дистанция, время, темп, пульс, каденс).
class _SegmentWithResultCard extends StatelessWidget {
  const _SegmentWithResultCard({required this.segment});

  final SegmentWithMyResult segment;

  @override
  Widget build(BuildContext context) {
    final best = segment.bestResult;
    final secondary = AppColors.getTextSecondaryColor(context);
    final primary = AppColors.getTextPrimaryColor(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.twinchip,
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            segment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (segment.position > 0)
                _MetricChip(
                  icon: Icons.emoji_events_outlined,
                  value: '${segment.position}',
                  color: secondary,
                ),
              _MetricChip(
                icon: Icons.straighten,
                value: '${_formatDistanceKm(segment.displayDistanceKm)} км',
                color: secondary,
              ),
              if (best != null) ...[
                _MetricChip(
                  icon: Icons.timer_outlined,
                  value: formatDuration(best.durationSec),
                  color: secondary,
                ),
                if (best.paceMinPerKm != null && best.paceMinPerKm! > 0)
                  _MetricChip(
                    icon: Icons.speed,
                    value: formatPace(best.paceMinPerKm!),
                    color: secondary,
                  ),
                if (best.avgHeartRate != null && best.avgHeartRate! > 0)
                  _MetricChip(
                    icon: CupertinoIcons.heart_fill,
                    value: best.avgHeartRate!.round().toString(),
                    color: AppColors.error,
                  ),
                if (best.avgCadence != null && best.avgCadence! > 0)
                  _MetricChip(
                    icon: Icons.directions_run,
                    value: best.avgCadence!.round().toString(),
                    color: secondary,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Компактная метрика: иконка + значение (без подписи).
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
        const SizedBox(width: 4),
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
