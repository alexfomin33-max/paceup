import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../../../core/services/auth_service.dart';
import '../../../../../../../../../core/services/segments_service.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../features/profile/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Провайдеры лидерборда (Все / Друзья)
// ─────────────────────────────────────────────────────────────────────────────
final segmentLeaderboardAllProvider =
    FutureProvider.family.autoDispose<List<SegmentLeaderboardItem>, int>(
  (ref, segmentId) async {
    final userId = await AuthService().getUserId();
    return SegmentsService().getSegmentLeaderboard(
      segmentId: segmentId,
      filter: 'all',
      userId: userId ?? 0,
    );
  },
);

final segmentLeaderboardFriendsProvider =
    FutureProvider.family.autoDispose<List<SegmentLeaderboardItem>, int>(
  (ref, segmentId) async {
    final userId = await AuthService().getUserId();
    if (userId == null) {
      return [];
    }
    return SegmentsService().getSegmentLeaderboard(
      segmentId: segmentId,
      filter: 'friends',
      userId: userId,
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Экран: Общие результаты по участку.
// ─────────────────────────────────────────────────────────────────────────────
class SegmentAllResultsScreen extends ConsumerStatefulWidget {
  const SegmentAllResultsScreen({
    super.key,
    required this.segmentId,
    required this.segmentTitle,
  });

  final int segmentId;
  final String segmentTitle;

  @override
  ConsumerState<SegmentAllResultsScreen> createState() =>
      _SegmentAllResultsScreenState();
}

class _SegmentAllResultsScreenState
    extends ConsumerState<SegmentAllResultsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Общие результаты',
          showBottomDivider: false,
        ),
        body: Column(
          children: [
            // ── Подшапка с названием участка
            Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Center(
                child: Text(
                  widget.segmentTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
              ),
            ),
            // ── Слайдер «Все / Друзья»
            Container(
              color: AppColors.getSurfaceColor(context),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: AppColors.brandPrimary,
                unselectedLabelColor:
                    AppColors.getTextPrimaryColor(context),
                indicatorColor: AppColors.brandPrimary,
                indicatorWeight: 1,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tabs: const [
                  Tab(child: _TabLabel(text: 'Все')),
                  Tab(child: _TabLabel(text: 'Друзья')),
                ],
              ),
            ),
            // ── Содержимое вкладок
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: [
                  _ResultsList(
                    segmentId: widget.segmentId,
                    provider: segmentLeaderboardAllProvider,
                  ),
                  _ResultsList(
                    segmentId: widget.segmentId,
                    provider: segmentLeaderboardFriendsProvider,
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

// ─────────────────────────────────────────────────────────────────────────────
// Вкладка-список с загрузкой данных
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsList extends ConsumerWidget {
  const _ResultsList({
    required this.segmentId,
    required this.provider,
  });

  final int segmentId;
  final AutoDisposeFutureProviderFamily<List<SegmentLeaderboardItem>, int>
      provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(provider(segmentId));
    return leaderboardAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return Center(
            child: Text(
              'Нет результатов',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(context),
              ),
            ),
          );
        }
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.sm),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: _LeaderCard(item: data.first),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.sm),
            ),
            if (data.length > 1)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 0.5,
                        ),
                        bottom: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 0.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? AppColors.darkShadowSoft
                              : AppColors.shadowSoft,
                          offset: const Offset(0, 1),
                          blurRadius: 1,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: List.generate(data.length - 1, (i) {
                        final r = data[i + 1];
                        return _ResultRow(
                          item: r,
                          isLast: i == data.length - 2,
                        );
                      }),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSpacing.lg),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: SelectableText.rich(
          TextSpan(
            text: 'Ошибка загрузки: ${error.toString()}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI-элементы
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.item});

  final SegmentLeaderboardItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: item.userId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.getBorderColor(context),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkShadowSoft
                  : AppColors.shadowSoft,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              child: Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: AppColors.gold,
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Text(
                item.dateText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentYellow,
                        ),
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: item.avatar,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 68,
                              height: 68,
                              color: AppColors.getBorderColor(context),
                              child: const Icon(Icons.person),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentYellow,
                          ),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCenter(
                        icon: CupertinoIcons.time,
                        text: item.durationText,
                      ),
                    ),
                    if (item.paceText != null &&
                        item.paceText!.isNotEmpty)
                      Expanded(
                        child: _MetricCenter(
                          materialIcon: Icons.speed,
                          text: item.paceText!,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCenter extends StatelessWidget {
  const _MetricCenter({
    this.icon,
    this.materialIcon,
    required this.text,
  });

  final IconData? icon;
  final IconData? materialIcon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final resolved = icon ?? materialIcon;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (resolved != null) const SizedBox(width: AppSpacing.xs),
        if (resolved != null)
          Icon(
            resolved,
            size: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        if (resolved != null) const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.isLast,
  });

  final SegmentLeaderboardItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.getBorderColor(context);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: item.userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: item.avatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.person),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.durationText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.dateText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, overflow: TextOverflow.ellipsis);
  }
}
