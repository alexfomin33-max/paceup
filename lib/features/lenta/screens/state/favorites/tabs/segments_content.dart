import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/segments_service.dart';
import '../../../../../../providers/services/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Формат дистанции: до 2 знаков после запятой (как в маршрутах).
// ─────────────────────────────────────────────────────────────────────────────
String _formatDistanceKm(double km) {
  final truncated = (km * 100).truncateToDouble() / 100;
  return truncated.toStringAsFixed(2);
}

/// Провайдер списка участков пользователя.
final mySegmentsProvider = FutureProvider.family<List<ActivitySegmentItem>, int>(
  (ref, userId) async {
    if (userId <= 0) return [];
    return SegmentsService().getMySegments(userId);
  },
);

/// Вкладка «Участки»: список участков (название, под ним — расстояние).
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
        if (uid > 0) ref.invalidate(mySegmentsProvider(uid));
      });
    }
    final userIdAsync = ref.watch(currentUserIdProvider);
    return userIdAsync.when(
      data: (userId) {
        final uid = userId ?? 0;
        final segmentsAsync = ref.watch(mySegmentsProvider(uid));
        return segmentsAsync.when(
          data: (segments) {
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + 60 + 12;
            if (segments.isEmpty) {
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
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final s = segments[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i < segments.length - 1 ? 6 : 0,
                          ),
                          child: _SegmentCard(segment: s),
                        );
                      },
                      childCount: segments.length,
                    ),
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

/// Карточка участка: название, под ним расстояние.
class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.segment});

  final ActivitySegmentItem segment;

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDistanceKm(segment.distanceKm)} км',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
