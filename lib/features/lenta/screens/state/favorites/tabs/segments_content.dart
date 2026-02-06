import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/services/segments_service.dart';
import '../../../../../../core/utils/activity_format.dart';
import '../../../../../../providers/services/auth_provider.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../edit_segment_bottom_sheet.dart';
import 'segment_description/segment_description_screen.dart';

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
  // ───────────────────────────────────────────────────────────────────────────
  // Параметры постраничной подгрузки (15 элементов за шаг).
  // ───────────────────────────────────────────────────────────────────────────
  static const int _pageSize = 15;
  static const Duration _loadDebounceDelay = Duration(milliseconds: 200);
  int _myPage = 1;
  int _otherPage = 1;
  bool _isLoadingMoreMy = false;
  bool _isLoadingMoreOther = false;
  Timer? _myLoadDebounceTimer;
  Timer? _otherLoadDebounceTimer;
  // ───────────────────────────────────────────────────────────────────────────
  // Локальные данные для оптимистического переименования.
  // ───────────────────────────────────────────────────────────────────────────
  SegmentsWithMyResults? _localSegments;
  int _localUserId = 0;
  bool _hasLocalEdits = false;

  @override
  void dispose() {
    // ── Отменяем таймеры, чтобы не вызывать setState после dispose
    _myLoadDebounceTimer?.cancel();
    _otherLoadDebounceTimer?.cancel();
    super.dispose();
  }

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
            // ── Берём локальные данные (если есть оптимистические правки)
            final viewData = _resolveSegmentsData(uid, data);
            // ── Размеры списков и видимые элементы (постранично)
            final myTotal = viewData.mySegments.length;
            final otherTotal = viewData.otherSegments.length;
            final myVisible = _visibleMyCount(myTotal);
            final otherVisible = _visibleOtherCount(otherTotal);
            final bottomPadding =
                MediaQuery.of(context).viewPadding.bottom + 60 + 12;
            final hasMy = myTotal > 0;
            final hasOther = otherTotal > 0;
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
                if (hasMy) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _SectionTitle(title: 'Мои участки'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // ── Подгружаем следующую страницу при скролле вниз
                          _maybeLoadMoreMy(
                            index: index,
                            totalCount: myTotal,
                          );
                          final segment = viewData.mySegments[index];
                          final bottom = _myItemBottomPadding(
                            index: index,
                            visibleCount: myVisible,
                            totalCount: myTotal,
                            hasOther: hasOther,
                          );
                          return Padding(
                            padding: EdgeInsets.only(bottom: bottom),
                            child: _SegmentWithResultCard(
                              segment: segment,
                              userId: uid,
                              onSegmentUpdated: (updatedName) {
                                // ── Оптимистически обновляем локальные данные
                                _applyOptimisticRename(
                                  segmentId: segment.id,
                                  name: updatedName,
                                );
                              },
                            ),
                          );
                        },
                        childCount: myVisible,
                      ),
                    ),
                  ),
                ],
                if (hasOther) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _SectionTitle(title: 'Все участки'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // ── Подгружаем следующую страницу при скролле вниз
                          _maybeLoadMoreOther(
                            index: index,
                            totalCount: otherTotal,
                          );
                          final segment = viewData.otherSegments[index];
                          final bottom = _otherItemBottomPadding(
                            index: index,
                            visibleCount: otherVisible,
                            totalCount: otherTotal,
                          );
                          return Padding(
                            padding: EdgeInsets.only(bottom: bottom),
                            child: _SegmentWithResultCard(
                              segment: segment,
                              userId: uid,
                              onSegmentUpdated: (updatedName) {
                                // ── Оптимистически обновляем локальные данные
                                _applyOptimisticRename(
                                  segmentId: segment.id,
                                  name: updatedName,
                                );
                              },
                            ),
                          );
                        },
                        childCount: otherVisible,
                      ),
                    ),
                  ),
                ],
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

  // ───────────────────────────────────────────────────────────────────────────
  // Синхронизация данных: берём локальные при наличии правок.
  // ───────────────────────────────────────────────────────────────────────────
  SegmentsWithMyResults _resolveSegmentsData(
    int userId,
    SegmentsWithMyResults fresh,
  ) {
    // ── При смене пользователя сбрасываем локальное состояние
    if (_localUserId != userId) {
      _localUserId = userId;
      _localSegments = fresh;
      _hasLocalEdits = false;
      // ── Сбрасываем параметры пагинации для нового пользователя
      _resetPagination();
    }
    // ── Если правок не было — используем свежие данные провайдера
    if (!_hasLocalEdits) {
      _localSegments = fresh;
    }
    return _localSegments ?? fresh;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Сброс параметров пагинации (используем при смене пользователя).
  // ───────────────────────────────────────────────────────────────────────────
  void _resetPagination() {
    _myPage = 1;
    _otherPage = 1;
    _isLoadingMoreMy = false;
    _isLoadingMoreOther = false;
    _myLoadDebounceTimer?.cancel();
    _otherLoadDebounceTimer?.cancel();
    _myLoadDebounceTimer = null;
    _otherLoadDebounceTimer = null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Количество видимых элементов для секции «Мои участки».
  // ───────────────────────────────────────────────────────────────────────────
  int _visibleMyCount(int totalCount) {
    final maxVisible = _myPage * _pageSize;
    return totalCount < maxVisible ? totalCount : maxVisible;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Количество видимых элементов для секции «Все участки».
  // ───────────────────────────────────────────────────────────────────────────
  int _visibleOtherCount(int totalCount) {
    final maxVisible = _otherPage * _pageSize;
    return totalCount < maxVisible ? totalCount : maxVisible;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Постраничная подгрузка для «Мои участки».
  // ───────────────────────────────────────────────────────────────────────────
  void _maybeLoadMoreMy({
    required int index,
    required int totalCount,
  }) {
    final visibleCount = _visibleMyCount(totalCount);
    if (visibleCount == 0) return;
    if (index != visibleCount - 1) return;
    if (visibleCount >= totalCount) return;
    if (_isLoadingMoreMy) return;
    if (_myLoadDebounceTimer?.isActive ?? false) return;
    _isLoadingMoreMy = true;
    // ── Debounce: защищаемся от частых вызовов на быстром скролле
    _myLoadDebounceTimer = Timer(_loadDebounceDelay, () {
      _myLoadDebounceTimer = null;
      if (!mounted) return;
      // ── Увеличиваем страницу после завершения текущего кадра
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _myPage += 1;
          _isLoadingMoreMy = false;
        });
      });
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Постраничная подгрузка для «Все участки».
  // ───────────────────────────────────────────────────────────────────────────
  void _maybeLoadMoreOther({
    required int index,
    required int totalCount,
  }) {
    final visibleCount = _visibleOtherCount(totalCount);
    if (visibleCount == 0) return;
    if (index != visibleCount - 1) return;
    if (visibleCount >= totalCount) return;
    if (_isLoadingMoreOther) return;
    if (_otherLoadDebounceTimer?.isActive ?? false) return;
    _isLoadingMoreOther = true;
    // ── Debounce: защищаемся от частых вызовов на быстром скролле
    _otherLoadDebounceTimer = Timer(_loadDebounceDelay, () {
      _otherLoadDebounceTimer = null;
      if (!mounted) return;
      // ── Увеличиваем страницу после завершения текущего кадра
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _otherPage += 1;
          _isLoadingMoreOther = false;
        });
      });
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Нижние отступы для элементов «Мои участки».
  // ───────────────────────────────────────────────────────────────────────────
  double _myItemBottomPadding({
    required int index,
    required int visibleCount,
    required int totalCount,
    required bool hasOther,
  }) {
    final itemGap = AppSpacing.sm - (AppSpacing.xs / 2);
    final sectionGap = AppSpacing.md;
    final isLastVisible = index == visibleCount - 1;
    if (!isLastVisible) return itemGap;
    final hasMore = visibleCount < totalCount;
    if (hasMore) return itemGap;
    return hasOther ? sectionGap : 0;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Нижние отступы для элементов «Все участки».
  // ───────────────────────────────────────────────────────────────────────────
  double _otherItemBottomPadding({
    required int index,
    required int visibleCount,
    required int totalCount,
  }) {
    final itemGap = AppSpacing.sm - (AppSpacing.xs / 2);
    final isLastVisible = index == visibleCount - 1;
    if (!isLastVisible) return itemGap;
    final hasMore = visibleCount < totalCount;
    if (hasMore) return itemGap;
    return 0;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Проверка: имя уже совпадает, обновление не нужно.
  // ───────────────────────────────────────────────────────────────────────────
  bool _hasSameName(
    List<SegmentWithMyResult> list,
    int segmentId,
    String name,
  ) {
    for (final item in list) {
      if (item.id == segmentId) {
        return item.name == name;
      }
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Оптимистическое переименование участка в локальных данных.
  // ───────────────────────────────────────────────────────────────────────────
  void _applyOptimisticRename({
    required int segmentId,
    required String name,
  }) {
    final current = _localSegments;
    if (current == null) return;
    // ── Ранний выход: имя не изменилось, setState не нужен
    final isSameName = _hasSameName(
      current.mySegments,
      segmentId,
      name,
    ) ||
        _hasSameName(
          current.otherSegments,
          segmentId,
          name,
        );
    if (isSameName) return;
    // ── Обновляем имя в обеих секциях, если участок там присутствует
    final updated = SegmentsWithMyResults(
      mySegments: _renameInList(
        current.mySegments,
        segmentId,
        name,
      ),
      otherSegments: _renameInList(
        current.otherSegments,
        segmentId,
        name,
      ),
    );
    setState(() {
      _localSegments = updated;
      _hasLocalEdits = true;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Обновление имени в списке участков (иммутабельное копирование).
  // ───────────────────────────────────────────────────────────────────────────
  List<SegmentWithMyResult> _renameInList(
    List<SegmentWithMyResult> list,
    int segmentId,
    String name,
  ) {
    return list.map((item) {
      if (item.id != segmentId) {
        return item;
      }
      return SegmentWithMyResult(
        id: item.id,
        name: name,
        distanceKm: item.distanceKm,
        realDistanceKm: item.realDistanceKm,
        bestResult: item.bestResult,
        position: item.position,
        totalParticipants: item.totalParticipants,
      );
    }).toList();
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
  const _SegmentWithResultCard({
    required this.segment,
    required this.userId,
    required this.onSegmentUpdated,
  });

  final SegmentWithMyResult segment;
  final int userId;
  final void Function(String name) onSegmentUpdated;

  @override
  Widget build(BuildContext context) {
    final best = segment.bestResult;
    final secondary = AppColors.getTextSecondaryColor(context);
    final primary = AppColors.getTextPrimaryColor(context);

    return InkWell(
      onTap: () {
        // ── Открываем экран описания участка без нижнего меню
        pushWithoutNavBar(
          context,
          TransparentPageRoute(
            builder: (_) => SegmentDescriptionScreen(
              segmentId: segment.id,
              userId: userId,
              initialSegment: segment,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.twinchip,
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.sm + (AppSpacing.xs / 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Верхняя строка: название + меню «три точки»
            Row(
              children: [
                Expanded(
                  child: Text(
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
                ),
                const SizedBox(width: AppSpacing.xs),
                _SegmentMenuButton(
                  onEdit: () {
                    // ── Открываем лист переименования участка
                    showEditSegmentBottomSheet(
                      context,
                      segment: segment,
                      userId: userId,
                      onSaved: onSegmentUpdated,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - (AppSpacing.xs / 2)),
            Wrap(
              spacing: AppSpacing.sm + AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (segment.position > 0)
                  _MetricChip(
                    icon: Icons.emoji_events_outlined,
                    value: '${segment.position}',
                    color: secondary,
                  ),
                _MetricChip(
                  icon: Icons.straighten,
                  value:
                      '${_formatDistanceKm(segment.displayDistanceKm)} км',
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Меню «три точки» для карточки участка (только пункт «Изменить»).
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentMenuButton extends StatelessWidget {
  const _SegmentMenuButton({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    // ── Меню с единым пунктом «Изменить»
    return SizedBox(
      width: AppSpacing.md,
      child: Align(
        alignment: Alignment.centerRight,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xll),
          ),
          color: AppColors.surface,
          elevation: 8,
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: AppColors.getIconSecondaryColor(context),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 22,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md - AppSpacing.xs),
                  Text(
                    'Изменить',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.getTextPrimaryColor(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
