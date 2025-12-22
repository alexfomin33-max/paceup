import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../features/map/providers/search/clubs_search_provider.dart';
import '../../../../../../features/map/screens/clubs/club_detail_screen.dart';

/// Контент вкладки «Клубы»
/// Отображает клубы в сетке карточек 2xN (как во вкладке "Клубы" профиля).
class SearchClubsContent extends ConsumerStatefulWidget {
  final String query;
  const SearchClubsContent({super.key, required this.query});

  @override
  ConsumerState<SearchClubsContent> createState() => _SearchClubsContentState();
}

class _SearchClubsContentState extends ConsumerState<SearchClubsContent> {
  // ────────────────────────────────────────────────────────────────────────
  // Обновление провайдеров при переключении вкладок и возврате на экран:
  // Отслеживаем видимость маршрута для обновления данных при возврате
  // ────────────────────────────────────────────────────────────────────────
  bool _wasRouteActive = false;

  @override
  Widget build(BuildContext context) {
    // Проверяем видимость маршрута и обновляем данные при возврате на экран
    _checkRouteVisibility();
    final trimmedQuery = widget.query.trim();
    final isSearching = trimmedQuery.isNotEmpty;

    final clubsAsync = isSearching
        ? ref.watch(searchClubsProvider(trimmedQuery))
        : ref.watch(recommendedClubsProvider);

    // ────────────────────────────────────────────────────────────────────────
    // Функция обновления данных при pull-to-refresh
    // ────────────────────────────────────────────────────────────────────────
    Future<void> onRefresh() async {
      if (isSearching) {
        // При поиске инвалидируем провайдер поиска
        ref.invalidate(searchClubsProvider(trimmedQuery));
      } else {
        // При просмотре рекомендованных клубов инвалидируем соответствующий провайдер
        ref.invalidate(recommendedClubsProvider);
      }
      // Ждем завершения обновления
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.brandPrimary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          clubsAsync.when(
            data: (clubs) {
              if (clubs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.group,
                            size: 48,
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSearching
                                ? 'Клубы не найдены'
                                : 'Рекомендованные клубы отсутствуют',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                        ],
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

              // Сетка карточек 2xN
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 174,
                  ),
                  itemCount: sortedClubs.length,
                  itemBuilder: (context, i) => _ClubCard(club: sortedClubs[i]),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stack) {
              debugPrint('❌ Ошибка загрузки клубов: $error');
              debugPrint('Stack trace: $stack');
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          size: 48,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ошибка загрузки клубов',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.getTextSecondaryColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Проверка видимости экрана и обновление данных при отображении
  // Вызывается при каждом build для отслеживания видимости маршрута
  // ────────────────────────────────────────────────────────────────────────
  void _checkRouteVisibility() {
    final route = ModalRoute.of(context);
    final isRouteActive = route?.isCurrent ?? false;

    // Если маршрут стал активным (видимым), обновляем данные
    if (isRouteActive && !_wasRouteActive) {
      _wasRouteActive = true;

      // Обновляем список рекомендованных клубов при возврате на экран
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final trimmedQuery = widget.query.trim();
        final isSearching = trimmedQuery.isNotEmpty;

        if (isSearching) {
          // При поиске инвалидируем провайдер поиска
          ref.invalidate(searchClubsProvider(trimmedQuery));
        } else {
          // При просмотре рекомендованных клубов инвалидируем соответствующий провайдер
          ref.invalidate(recommendedClubsProvider);
        }
      });
    } else if (!isRouteActive) {
      // Если маршрут стал неактивным, сбрасываем флаг для следующего отображения
      _wasRouteActive = false;
    }
  }
}

/// Карточка клуба в сетке
///
/// Отображает логотип, название и количество участников
/// При нажатии открывает детальную страницу клуба
class _ClubCard extends StatelessWidget {
  final ClubSearch club;
  const _ClubCard({required this.club});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Логотип клуба (круглый)
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.getBorderColor(context),
                width: 0.5,
              ),
            ),
            child: ClipOval(child: _ClubLogoImage(logoUrl: club.logoUrl)),
          ),
          const SizedBox(height: 8),

          // Название клуба с горизонтальным скроллом
          // Центрируем короткие названия, длинные можно прокрутить
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Text(
                club.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Количество участников
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.person_2,
                  size: 15,
                  color: AppColors.getTextPrimaryColor(context),
                ),
                const SizedBox(width: 4),
                Text(
                  _fmt(club.membersCount),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.2,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                if (club.city.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      '  ·  ${club.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.2,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Делаем карточку кликабельной для перехода на детальную страницу
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          TransparentPageRoute(
            builder: (_) => ClubDetailScreen(clubId: club.id),
          ),
        );
      },
      child: card,
    );
  }
}

/// Виджет для отображения логотипа клуба
///
/// Использует CachedNetworkImage для загрузки изображения из API
/// Показывает placeholder при отсутствии логотипа или ошибке загрузки
class _ClubLogoImage extends StatelessWidget {
  final String logoUrl;
  const _ClubLogoImage({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    // Если логотип не указан, показываем placeholder
    if (logoUrl.isEmpty) {
      return Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.group,
          size: 40,
          color: AppColors.textSecondary,
        ),
      );
    }

    // Загружаем логотип из сети с кэшированием
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (100 * dpr).round();

    return CachedNetworkImage(
      imageUrl: logoUrl,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: targetW,
      maxWidthDiskCache: targetW,
      errorWidget: (context, imageUrl, error) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: AppColors.textSecondary,
        ),
      ),
      placeholder: (context, imageUrl) => Container(
        color: AppColors.skeletonBase,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
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
