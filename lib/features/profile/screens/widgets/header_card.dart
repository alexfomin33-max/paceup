import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../edit_profile_screen.dart';
import '../state/subscribe/communication_screen.dart';
import '../../../../domain/models/user_profile_header.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/avatar.dart';
import '../../../../providers/services/auth_provider.dart';

class HeaderCard extends ConsumerWidget {
  final UserProfileHeader? profile;
  final int userId;
  final VoidCallback onReload;

  const HeaderCard({
    super.key,
    this.profile,
    required this.userId,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ────────────────────────────────────────────────────────────────
    // 🎨 SKELETON LOADER: показываем заглушку пока profile == null
    // ────────────────────────────────────────────────────────────────
    if (profile == null) {
      return Container(
        color: AppColors.getSurfaceColor(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Скелетон аватарки
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceMuted
                    : AppColors.skeletonBase,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Скелетон имени
                  Container(
                    height: 20,
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 180),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceMuted
                          : AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Скелетон подзаголовка
                  Container(
                    height: 14,
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 120),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurfaceMuted
                          : AppColors.skeletonBase,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Скелетон подписок
                  Row(
                    children: [
                      Container(
                        height: 14,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Container(
                        height: 14,
                        width: 80,
                        decoration: BoxDecoration(
                          color: AppColors.skeletonBase,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ────────────────────────────────────────────────────────────────
    // 📝 ОСНОВНОЙ РЕНДЕР: показываем реальные данные профиля
    // ────────────────────────────────────────────────────────────────

    // Локальная переменная для null-safety (уже прошли проверку выше)
    final p = profile!;

    return Container(
      color: AppColors.getSurfaceColor(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // ─── Аватарка с unified Avatar виджетом ───
              // ✅ Автоматически использует avatarVersionProvider для cache-busting
              // ✅ Синхронизирована с лентой и редактированием профиля
              // ✅ Оптимизация памяти через memCacheWidth
              Avatar(
                image: (p.avatar != null && p.avatar!.isNotEmpty)
                    ? p.avatar!
                    : 'assets/avatar_0.png',
                size: 64,
                fadeIn: true,
                gapless: true,
              ),

              // Positioned(
              //   bottom: -20,
              //   left: 0,
              //   right: 0,
              //   child: Center(
              //     child: Container(
              //       padding: const EdgeInsets.symmetric(
              //         horizontal: 6,
              //         vertical: 0,
              //       ),
              //       decoration: BoxDecoration(
              //         color: AppColors.chipBg,
              //         borderRadius: BorderRadius.circular(AppRadius.xs),
              //       ),
              //       child: const Text('Pro', style: AppTextStyles.h11w6),
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (() {
                          final fn = (p.firstName).trim();
                          final ln = (p.lastName).trim();
                          final full = [
                            fn,
                            ln,
                          ].where((s) => s.isNotEmpty).join(' ').trim();
                          return full.isNotEmpty ? full : 'Пользователь';
                        })(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h16w6.copyWith(
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // ────────────────────────────────────────────────────
                    // 🔹 ИКОНКА РЕДАКТИРОВАНИЯ: показываем только для своего
                    // профиля. Для чужого профиля меню теперь в AppBar.
                    // ────────────────────────────────────────────────────
                    Builder(
                      builder: (context) {
                        final currentUserIdAsync = ref.watch(
                          currentUserIdProvider,
                        );
                        final currentUserId = currentUserIdAsync.value;
                        final isOwnProfile =
                            currentUserId != null && currentUserId == userId;

                        if (isOwnProfile) {
                          // Свой профиль - показываем иконку карандаша для редактирования
                          return _SmallIconBtn(
                            icon: CupertinoIcons.pencil,
                            onPressed: () async {
                              final changed = await Navigator.of(context)
                                  .push<bool>(
                                    TransparentPageRoute(
                                      builder: (_) =>
                                          EditProfileScreen(userId: userId),
                                    ),
                                  );
                              if (changed == true) {
                                onReload(); // ← одна строка на авто-рефреш
                              }
                            },
                          );
                        } else {
                          // Чужой профиль — ничего не показываем, меню в AppBar
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 0),
                Text(
                  _subtitleFrom(p) ?? '',
                  style: AppTextStyles.h13w4.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _FollowStat(
                      label: 'Подписки',
                      value: (p.following).toString(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => CommunicationPrefsPage(
                              startIndex: 0,
                              userId: userId,
                            ), // Подписки
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 24),
                    _FollowStat(
                      label: 'Подписчики',
                      value: (p.followers).toString(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => CommunicationPrefsPage(
                              startIndex: 1,
                              userId: userId,
                            ), // Подписчики
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _yearsRu(int? n) {
    if (n == null) return 'лет';
    final last2 = n % 100;
    if (11 <= last2 && last2 <= 14) return 'лет';
    switch (n % 10) {
      case 1:
        return 'год';
      case 2:
      case 3:
      case 4:
        return 'года';
      default:
        return 'лет';
    }
  }

  String? _subtitleFrom(UserProfileHeader? p) {
    if (p == null) return null;
    final parts = <String>[];
    if (p.age != null) parts.add('${p.age} ${_yearsRu(p.age)}');
    if ((p.city ?? '').isNotEmpty) parts.add(p.city!);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SmallIconBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurfaceMuted
              : AppColors.skeletonBase,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.getIconPrimaryColor(context),
        ),
      ),
    );
  }
}


class _FollowStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _FollowStat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Делаем удобную область тапа и не меняем внешний вид текста
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const TextSpan(
                text: '\u200B',
              ), // микропробел для ровного переноса
              TextSpan(
                text: value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
