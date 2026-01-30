import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../../../../core/services/auth_service.dart';
import '../../../../../../../../../core/services/routes_service.dart';
import '../../../../../../../../../core/theme/app_theme.dart';
import '../../../../../../../../../core/widgets/app_bar.dart';
import '../../../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../../../features/profile/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Провайдер для загрузки лидерборда "Все"
// ─────────────────────────────────────────────────────────────────────────────
final routeLeaderboardAllProvider = FutureProvider.family
    .autoDispose<List<RouteLeaderboardItem>, int>((ref, routeId) async {
  final userId = await AuthService().getUserId();
  return RoutesService().getRouteLeaderboard(
    routeId: routeId,
    filter: 'all',
    userId: userId ?? 0,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Провайдер для загрузки лидерборда "Друзья"
// ─────────────────────────────────────────────────────────────────────────────
final routeLeaderboardFriendsProvider = FutureProvider.family
    .autoDispose<List<RouteLeaderboardItem>, int>((ref, routeId) async {
  final userId = await AuthService().getUserId();
  if (userId == null) {
    return [];
  }
  return RoutesService().getRouteLeaderboard(
    routeId: routeId,
    filter: 'friends',
    userId: userId,
  );
});

class AllResultsScreen extends ConsumerStatefulWidget {
  final int routeId;
  final String routeTitle;
  final String? difficultyText; // например: "Средний маршрут"

  const AllResultsScreen({
    super.key,
    required this.routeId,
    required this.routeTitle,
    this.difficultyText,
  });

  @override
  ConsumerState<AllResultsScreen> createState() => _AllResultsScreenState();
}

class _AllResultsScreenState extends ConsumerState<AllResultsScreen>
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
            // ── подшапка с названием маршрута и сложностью
            Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      widget.routeTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                  if ((widget.difficultyText ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: _DifficultyChip(text: widget.difficultyText!),
                    ),
                  ],
                ],
              ),
            ),

            // ── слайдер «Все / Друзья»
            Container(
              color: AppColors.getSurfaceColor(context),
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: AppColors.brandPrimary,
                unselectedLabelColor: AppColors.getTextPrimaryColor(context),
                indicatorColor: AppColors.brandPrimary,
                indicatorWeight: 1,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: const [
                  Tab(child: _TabLabel(text: 'Все')),
                  Tab(child: _TabLabel(text: 'Друзья')),
                ],
              ),
            ),

            // ── содержимое вкладок
            Expanded(
              child: TabBarView(
                controller: _tab,
                physics: const BouncingScrollPhysics(),
                children: [
                  _ResultsList(
                    routeId: widget.routeId,
                    provider: routeLeaderboardAllProvider,
                  ),
                  _ResultsList(
                    routeId: widget.routeId,
                    provider: routeLeaderboardFriendsProvider,
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
// ВКЛАДКА-СПИСОК с загрузкой данных
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsList extends ConsumerWidget {
  final int routeId;
  final AutoDisposeFutureProviderFamily<List<RouteLeaderboardItem>, int>
      provider;

  const _ResultsList({
    required this.routeId,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(provider(routeId));

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
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── карточка лидера (первое место)
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: _LeaderCard(item: data.first),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── таблица остальных результатов (если есть больше одного результата)
            if (data.length > 1)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                          color: Theme.of(context).brightness == Brightness.dark
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

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Center(
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
  final RouteLeaderboardItem item;
  const _LeaderCard({required this.item});

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
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            // ── трофей — слева сверху
            const Positioned(
              left: 0,
              top: 0,
              child: Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: AppColors.gold,
              ),
            ),
            // ── дата — справа сверху
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

            // ── основной центрированный контент
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                // ── аватар по центру с желтой обводкой и кружком с цифрой "1"
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── желтая обводка вокруг аватара
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentYellow,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: item.avatar,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Container(
                              width: 68,
                              height: 68,
                              color: AppColors.getBorderColor(context),
                              child: const Icon(Icons.person),
                            ),
                          ),
                        ),
                      ),
                      // ── маленький желтый кружок с цифрой "1"
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
                const SizedBox(height: 10),

                // ── имя по центру
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

                const SizedBox(height: 10),

                // ── метрики: время и темп (если доступен)
                Row(
                  children: [
                    Expanded(
                      child: _MetricCenter(
                        icon: CupertinoIcons.time,
                        text: item.durationText,
                      ),
                    ),
                    if (item.paceText != null && item.paceText!.isNotEmpty)
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
  final IconData? icon;
  final IconData? materialIcon;
  final String text;

  const _MetricCenter({this.icon, this.materialIcon, required this.text});

  @override
  Widget build(BuildContext context) {
    final IconData? resolved = icon ?? materialIcon;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (resolved != null) const SizedBox(width: 2),
        if (resolved != null)
          Icon(
            resolved,
            size: 14,
            color: AppColors.getTextSecondaryColor(context),
          ),
        if (resolved != null) const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
        if (resolved != null) const SizedBox(width: 2),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final RouteLeaderboardItem item;
  final bool isLast;

  const _ResultRow({
    required this.item,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final row = GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: item.userId),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Text(
                '${item.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: item.avatar,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 36,
                  height: 36,
                  color: AppColors.getBorderColor(context),
                  child: const Icon(Icons.person, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // ── имя + дата (две строки)
            Expanded(
              flex: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.getTextSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            // ── Правая колонка: ИКОНКА + ВРЕМЯ
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.time,
                    size: 14,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.durationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        row,
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.getDividerColor(context),
          ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  const _TabLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.getTextPrimaryColor(context),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String text;
  const _DifficultyChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final lc = text.toLowerCase();
    Color c;
    if (lc.contains('лёгк')) {
      c = AppColors.success;
    } else if (lc.contains('средн')) {
      c = AppColors.warning;
    } else {
      c = AppColors.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: c,
        ),
      ),
    );
  }
}
