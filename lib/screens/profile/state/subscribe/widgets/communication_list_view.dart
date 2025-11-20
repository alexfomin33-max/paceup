import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../providers/communication/communication_providers.dart';
import '../../../../../theme/app_theme.dart';
import '../../../profile_screen.dart';

/// ────────────────────────────────────────────────────────────────────────────
///                     Универсальный список подписок/подписчиков
/// ────────────────────────────────────────────────────────────────────────────
class CommunicationListView extends ConsumerWidget {
  const CommunicationListView({
    super.key,
    required this.tab,
    required this.query,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final CommunicationTab tab;
  final String query;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = CommunicationListArgs(tab: tab, query: query);
    final asyncState = ref.watch(communicationListProvider(args));
    final notifier = ref.read(communicationListProvider(args).notifier);
    final data = asyncState.valueOrNull;

    final bool isInitialLoading = asyncState.isLoading && data == null;
    final Object? initialError =
        asyncState.hasError && data == null ? asyncState.error : null;

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      onRefresh: () => notifier.refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical &&
              notification.metrics.extentAfter < 200 &&
              (data?.hasMore ?? false)) {
            notifier.loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (isInitialLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              )
            else if (initialError != null)
              _ErrorSection(message: initialError.toString())
            else if ((data?.users.isEmpty ?? true))
              _EmptySection(
                title: emptyTitle,
                subtitle: emptySubtitle,
              )
            else
              _UsersSliver(
                users: data!.users,
                tab: tab,
                notifier: notifier,
              ),
            if ((data?.lastError?.isNotEmpty ?? false))
              _HintError(message: data!.lastError!),
            if (data?.isLoadingMore ?? false)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// ────────────── Секция ошибки (начальная загрузка) ──────────────
class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: SelectableText.rich(
          TextSpan(
            text: 'Ошибка загрузки\n',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
            children: [
              TextSpan(
                text: message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// ────────────── Секция пустого состояния ──────────────
class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h15w6,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.h13w4Sec,
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────── Секция подсказки об ошибке (во время пагинации) ──────────────
class _HintError extends StatelessWidget {
  const _HintError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SelectableText.rich(
          TextSpan(
            text: 'Ошибка обновления: ',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
            children: [
              TextSpan(
                text: message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ────────────── Список пользователей ──────────────
class _UsersSliver extends StatelessWidget {
  const _UsersSliver({
    required this.users,
    required this.tab,
    required this.notifier,
  });

  final List<CommunicationUser> users;
  final CommunicationTab tab;
  final CommunicationListNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final user = users[index];
          final isFirst = index == 0;
          final isLast = index == users.length - 1;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: isFirst ? 0.5 : 0,
                ),
                bottom: BorderSide(
                  color: AppColors.border,
                  width: isLast ? 0.5 : 0,
                ),
              ),
            ),
            child: Column(
              children: [
                _CommunicationUserTile(
                  key: ValueKey('comm_user_${user.id}_${tab.name}'),
                  user: user,
                  onToggle: () => notifier.toggleSubscription(user.id),
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.divider,
                  ),
              ],
            ),
          );
        },
        childCount: users.length,
      ),
    );
  }
}

/// ────────────── Отдельный ряд списка ──────────────
class _CommunicationUserTile extends StatelessWidget {
  const _CommunicationUserTile({
    super.key,
    required this.user,
    required this.onToggle,
  });

  final CommunicationUser user;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => ProfileScreen(userId: user.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Avatar(url: user.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h15w5,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h13w4Sec,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggle,
                splashRadius: 24,
                icon: Icon(
                  user.isSubscribedByMe
                      ? CupertinoIcons.person_crop_circle_badge_xmark
                      : CupertinoIcons.person_crop_circle_badge_plus,
                  size: 26,
                  color: user.isSubscribedByMe
                      ? AppColors.error
                      : AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(CommunicationUser user) {
    if (user.age > 0 && user.city.isNotEmpty) {
      return '${user.age} лет, ${user.city}';
    }
    if (user.age > 0) {
      return '${user.age} лет';
    }
    return user.city.isEmpty ? 'Город не указан' : user.city;
  }
}

/// ────────────── Аватар с graceful fallback ──────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url.isEmpty
            ? 'http://uploads.paceup.ru/images/users/avatars/def.png'
            : url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: 44,
          height: 44,
          color: AppColors.skeletonBase,
          alignment: Alignment.center,
          child: const CupertinoActivityIndicator(),
        ),
        errorWidget: (context, url, error) => Container(
          width: 44,
          height: 44,
          color: AppColors.skeletonBase,
          alignment: Alignment.center,
          child: const Icon(
            CupertinoIcons.person,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}


