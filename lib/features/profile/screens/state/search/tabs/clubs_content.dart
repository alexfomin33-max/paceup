import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../features/map/providers/search/clubs_search_provider.dart';
import '../../../../../../features/map/screens/clubs/club_detail_screen.dart';

/// Контент вкладки «Клубы»
/// Табличный список «в одну коробку» (как на карте/в маршрутных списках).
class SearchClubsContent extends ConsumerWidget {
  final String query;
  const SearchClubsContent({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmedQuery = query.trim();
    final isSearching = trimmedQuery.isNotEmpty;
    
    final clubsAsync = isSearching
        ? ref.watch(searchClubsProvider(trimmedQuery))
        : ref.watch(recommendedClubsProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (!isSearching)
          const SliverToBoxAdapter(
            child: _SectionTitle('Рекомендованные клубы'),
          ),
        clubsAsync.when(
          data: (clubs) {
            if (clubs.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      isSearching
                          ? 'Клубы не найдены'
                          : 'Рекомендованные клубы отсутствуют',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Сортируем клубы по количеству участников (по убыванию)
            // Если количество одинаковое, сортируем по имени
            final sortedClubs = List<ClubSearch>.from(clubs)
              ..sort((a, b) {
                final countDiff = b.membersCount.compareTo(a.membersCount);
                if (countDiff != 0) return countDiff;
                return a.name.compareTo(b.name);
              });

            return SliverToBoxAdapter(
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
                ),
                child: Column(
                  children: List.generate(sortedClubs.length, (i) {
                    final club = sortedClubs[i];
                    return Column(
                      children: [
                        _ClubRow(club: club),
                        if (i != sortedClubs.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: AppColors.getDividerColor(context),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
          ),
          error: (error, stack) {
            debugPrint('❌ Ошибка загрузки клубов: $error');
            debugPrint('Stack trace: $stack');
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 48,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка загрузки',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ClubRow extends StatelessWidget {
  final ClubSearch club;
  const _ClubRow({required this.club});

  void _onTap(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ClubDetailScreen(clubId: club.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _onTap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Превью (логотип клуба)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: CachedNetworkImage(
                imageUrl: club.logoUrl,
                width: 80,
                height: 55,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 55,
                  color: AppColors.getSkeletonBaseColor(context),
                  alignment: Alignment.center,
                  child: const CupertinoActivityIndicator(),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 55,
                  color: AppColors.getSkeletonBaseColor(context),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 20,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Название и детали
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h14w6.copyWith(
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${club.city}  ·  Участников: ${_fmt(club.membersCount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h13w4.copyWith(
                      color: AppColors.getTextSecondaryColor(context),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.getTextPrimaryColor(context),
        ),
      ),
    );
  }
}

/// Форматирование числа участников с разделителями тысяч
String _fmt(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('\u202F'); // узкий неразрывный
  }
  return b.toString();
}
