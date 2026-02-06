import 'dart:async';

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
// Типы и параметры фильтрации по полу
// ─────────────────────────────────────────────────────────────────────────────
enum _SegmentGenderFilter {
  // ── Мужской фильтр (М)
  male,
  // ── Женский фильтр (Ж)
  female,
}

// ─────────────────────────────────────────────────────────────────────────────
// Маппинг фильтра пола в параметр API
// ─────────────────────────────────────────────────────────────────────────────
extension _SegmentGenderFilterX on _SegmentGenderFilter {
  // ── Значение, которое ожидает API
  String get apiValue => this == _SegmentGenderFilter.male
      ? 'male'
      : 'female';
}

// ─────────────────────────────────────────────────────────────────────────────
// Параметры загрузки лидерборда
// ─────────────────────────────────────────────────────────────────────────────
class _SegmentLeaderboardQuery {
  const _SegmentLeaderboardQuery({
    required this.segmentId,
    required this.genderFilter,
  });

  // ── ID участка
  final int segmentId;
  // ── Текущий фильтр по полу (null = без фильтра)
  final _SegmentGenderFilter? genderFilter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SegmentLeaderboardQuery &&
          other.segmentId == segmentId &&
          other.genderFilter == genderFilter;

  @override
  int get hashCode => Object.hash(segmentId, genderFilter);
}

// ─────────────────────────────────────────────────────────────────────────────
// Провайдеры лидерборда (Все / Друзья)
// ─────────────────────────────────────────────────────────────────────────────
final segmentLeaderboardAllProvider =
    FutureProvider.family.autoDispose<List<SegmentLeaderboardItem>,
        _SegmentLeaderboardQuery>(
  (ref, query) async {
    // ── Кешируем результаты на короткое время, чтобы не дергать сеть
    //    при переключении вкладок или смене фильтра пола.
    final keepAliveLink = ref.keepAlive();
    final keepAliveTimer = Timer(
      const Duration(seconds: 30),
      keepAliveLink.close,
    );
    ref.onDispose(keepAliveTimer.cancel);

    final userId = await AuthService().getUserId();
    // ── Фильтр по полу прокидываем в API (null = без фильтрации)
    return SegmentsService().getSegmentLeaderboard(
      segmentId: query.segmentId,
      filter: 'all',
      gender: query.genderFilter?.apiValue,
      userId: userId ?? 0,
    );
  },
);

final segmentLeaderboardFriendsProvider =
    FutureProvider.family.autoDispose<List<SegmentLeaderboardItem>,
        _SegmentLeaderboardQuery>(
  (ref, query) async {
    // ── Кешируем результаты на короткое время, чтобы не дергать сеть
    //    при переключении вкладок или смене фильтра пола.
    final keepAliveLink = ref.keepAlive();
    final keepAliveTimer = Timer(
      const Duration(seconds: 30),
      keepAliveLink.close,
    );
    ref.onDispose(keepAliveTimer.cancel);

    final userId = await AuthService().getUserId();
    if (userId == null) {
      return [];
    }
    return SegmentsService().getSegmentLeaderboard(
      segmentId: query.segmentId,
      filter: 'friends',
      gender: query.genderFilter?.apiValue,
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
  // ── Контроллер вкладок
  late final TabController _tab;
  // ── Текущий индекс вкладки (нужен для ленивой загрузки)
  int _currentTabIndex = 0;
  // ── Текущий фильтр по полу (null = без фильтра)
  _SegmentGenderFilter? _selectedGender;

  // ───────────────────────────────────────────────────────────────────────────
  // Инициализация контроллера вкладок
  // ───────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _currentTabIndex = _tab.index;
    _tab.addListener(_handleTabChanged);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Обновление состояния при смене вкладки
  // ───────────────────────────────────────────────────────────────────────────
  void _handleTabChanged() {
    if (_currentTabIndex == _tab.index) {
      return;
    }
    setState(() {
      _currentTabIndex = _tab.index;
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Переключение фильтра по полу (повторный тап снимает фильтр)
  // ───────────────────────────────────────────────────────────────────────────
  void _toggleGenderFilter(_SegmentGenderFilter gender) {
    setState(() {
      _selectedGender = _selectedGender == gender ? null : gender;
    });
  }

  @override
  void dispose() {
    _tab.removeListener(_handleTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Параметры загрузки лидерборда с учётом фильтра по полу
    final query = _SegmentLeaderboardQuery(
      segmentId: widget.segmentId,
      genderFilter: _selectedGender,
    );
    // ── Ленивая загрузка: грузим только активную вкладку
    final shouldLoadAllTab = _currentTabIndex == 0;
    final shouldLoadFriendsTab = _currentTabIndex == 1;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(
          title: 'Общие результаты',
          showBottomDivider: false,
        ),
        body: Column(
          children: [
            // ── Подшапка с названием участка и фильтром по полу
            Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Название участка
                  Center(
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
                  const SizedBox(height: AppSpacing.sm),
                  // ── Фильтр по полу (М / Ж)
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GenderFilterButton(
                          label: 'М',
                          isSelected:
                              _selectedGender == _SegmentGenderFilter.male,
                          onTap: () =>
                              _toggleGenderFilter(_SegmentGenderFilter.male),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _GenderFilterButton(
                          label: 'Ж',
                          isSelected:
                              _selectedGender == _SegmentGenderFilter.female,
                          onTap: () =>
                              _toggleGenderFilter(_SegmentGenderFilter.female),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    query: query,
                    provider: segmentLeaderboardAllProvider,
                    shouldLoad: shouldLoadAllTab,
                  ),
                  _ResultsList(
                    query: query,
                    provider: segmentLeaderboardFriendsProvider,
                    shouldLoad: shouldLoadFriendsTab,
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
    required this.query,
    required this.provider,
    required this.shouldLoad,
  });

  // ── Параметры загрузки лидерборда
  final _SegmentLeaderboardQuery query;
  final AutoDisposeFutureProviderFamily<List<SegmentLeaderboardItem>,
      _SegmentLeaderboardQuery> provider;
  // ── Ленивая загрузка: сеть не дергаем, пока вкладка не открыта
  final bool shouldLoad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Если вкладка не посещена, ничего не загружаем
    if (!shouldLoad) {
      return const SizedBox.shrink();
    }
    // ── Слушаем результат с учётом текущих параметров фильтрации
    final leaderboardAsync = ref.watch(provider(query));
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
// ─────────────────────────────────────────────────────────────────────────────
// Кнопка фильтра по полу (М / Ж)
// ─────────────────────────────────────────────────────────────────────────────
class _GenderFilterButton extends StatelessWidget {
  const _GenderFilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  // ── Текст кнопки (М или Ж)
  final String label;
  // ── Активность выбранного состояния
  final bool isSelected;
  // ── Колбэк на нажатие
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ── Цвета для активного/неактивного состояния
    final backgroundColor = isSelected
        ? AppColors.brandPrimary
        : AppColors.getSurfaceColor(context);
    final borderColor = isSelected
        ? AppColors.brandPrimary
        : AppColors.getBorderColor(context);
    final textColor = isSelected
        ? AppColors.surface
        : AppColors.getTextPrimaryColor(context);

    return Material(
      color: backgroundColor,
      shape: CircleBorder(
        side: BorderSide(
          color: borderColor,
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.h14w6.copyWith(
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
