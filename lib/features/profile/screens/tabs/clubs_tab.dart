// lib/screens/profile/tabs/clubs_tab.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../state/search/search_screen.dart';
import '../../../../features/map/screens/clubs/club_detail_screen.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../providers/user_clubs_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../domain/models/club.dart';

/// Вкладка "Клубы" в профиле пользователя
///
/// Загружает клубы указанного пользователя через API
/// и отображает их в сетке 2xN
/// Кнопка "Найти клуб" показывается только для текущего авторизованного пользователя
class ClubsTab extends ConsumerStatefulWidget {
  /// ID пользователя, чьи клубы нужно отобразить
  final int userId;
  const ClubsTab({super.key, required this.userId});

  @override
  ConsumerState<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends ConsumerState<ClubsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Загружаем клубы указанного пользователя через provider
    final clubsAsync = ref.watch(userClubsProvider(widget.userId));

    // Получаем текущего авторизованного пользователя для проверки,
    // нужно ли показывать кнопку "Найти клуб"
    final currentUserIdAsync = ref.watch(currentUserIdProvider);

    return currentUserIdAsync.when(
      data: (currentUserId) {
        // Определяем, является ли открытый профиль профилем текущего пользователя
        final isOwnProfile = currentUserId != null && currentUserId == widget.userId;

        return _buildClubsContent(clubsAsync, isOwnProfile: isOwnProfile);
      },
      loading: () {
        // Показываем клубы даже во время загрузки информации о текущем пользователе
        return _buildClubsContent(clubsAsync, isOwnProfile: false);
      },
      error: (err, stack) {
        // В случае ошибки загрузки текущего пользователя,
        // показываем клубы без кнопки (isOwnProfile = false)
        return _buildClubsContent(clubsAsync, isOwnProfile: false);
      },
    );
  }

  /// Строит контент с клубами
  ///
  /// [isOwnProfile] - true, если открыт профиль текущего авторизованного пользователя
  Widget _buildClubsContent(
    AsyncValue<List<Club>> clubsAsync, {
    required bool isOwnProfile,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Обработка состояний загрузки/ошибок/данных
        clubsAsync.when(
          data: (clubs) {
            if (clubs.isEmpty) {
              // Пустой список клубов
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
                          'У вас пока нет клубов',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
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
            final sortedClubs = List<Club>.from(clubs)
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
          error: (err, stack) => SliverToBoxAdapter(
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
                      err.toString(),
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
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 25)),

        // Кнопка "Найти клуб" показывается только в профиле текущего пользователя
        if (isOwnProfile)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: PrimaryButton(
                  text: 'Найти клуб',
                  leading: const Icon(CupertinoIcons.search, size: 18),
                  width: MediaQuery.of(context).size.width / 2,
                  onPressed: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) =>
                            const SearchPrefsPage(startIndex: 1), // сразу «Клубы»
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

/// Карточка клуба в сетке
///
/// Отображает логотип, название и количество участников
/// При нажатии открывает детальную страницу клуба
class _ClubCard extends StatelessWidget {
  final Club club;
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
          SizedBox(
            height: 100,
            width: 100,
            child: ClipOval(child: _ClubLogoImage(logoUrl: club.logoUrl)),
          ),
          const SizedBox(height: 8),

          // Название клуба
          Text(
            club.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 6),

          // Количество участников
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Участников: ${_formatMembers(club.membersCount)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.2,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
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
  final String? logoUrl;
  const _ClubLogoImage({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    // Если логотип не указан, показываем placeholder
    if (logoUrl == null || logoUrl!.isEmpty) {
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
      imageUrl: logoUrl!,
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

// Формат "58 234"
String _formatMembers(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) {
      buf.write('\u202F'); // узкий неразрывный пробел
    }
  }
  return buf.toString();
}
