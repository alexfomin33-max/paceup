import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/communication/communication_providers.dart';
import '../../../../../../core/theme/app_theme.dart';
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
    this.userId,
  });

  final CommunicationTab tab;
  final String query;
  final String emptyTitle;
  final String emptySubtitle;
  final int? userId; // Если null, используется авторизованный пользователь

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = CommunicationListArgs(tab: tab, query: query, userId: userId);
    final asyncState = ref.watch(communicationListProvider(args));
    final notifier = ref.read(communicationListProvider(args).notifier);
    final data = asyncState.valueOrNull;

    final bool isInitialLoading = asyncState.isLoading && data == null;
    final Object? initialError = asyncState.hasError && data == null
        ? asyncState.error
        : null;

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
              _EmptySection(title: emptyTitle, subtitle: emptySubtitle)
            else
              _UsersSliver(users: data!.users, tab: tab, notifier: notifier),
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
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.getTextSecondaryColor(context),
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
              style: AppTextStyles.h15w6.copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.h13w4Sec.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
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
      delegate: SliverChildBuilderDelegate((context, index) {
        final user = users[index];

        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
          ),
          child: _CommunicationUserTile(
            key: ValueKey('comm_user_${user.id}_${tab.name}'),
            user: user,
            tab: tab,
            onToggle: () => notifier.toggleSubscription(user.id),
          ),
        );
      }, childCount: users.length),
    );
  }
}

/// ────────────── Отдельный ряд списка ──────────────
class _CommunicationUserTile extends StatelessWidget {
  const _CommunicationUserTile({
    super.key,
    required this.user,
    required this.tab,
    required this.onToggle,
  });

  final CommunicationUser user;
  final CommunicationTab tab;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
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
                      style: AppTextStyles.h15w5.copyWith(
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h13w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Логика отображения кнопок/иконок в зависимости от вкладки
              if (tab == CommunicationTab.subscriptions)
                // Во вкладке "Подписки": кнопка "Отписаться" если подписан, иначе иконка подписки
                user.isSubscribedByMe
                    ? _UnsubscribeButton(onPressed: onToggle)
                    : IconButton(
                        onPressed: onToggle,
                        splashRadius: 24,
                        icon: const Icon(
                          CupertinoIcons.person_crop_circle_badge_plus,
                          size: 26,
                          color: AppColors.brandPrimary,
                        ),
                      )
              else
                // Во вкладке "Подписчики": кнопка "Подписаться" если не подписан, иначе ничего
                user.isSubscribedByMe
                    ? const SizedBox.shrink()
                    : _SubscribeButton(onPressed: onToggle),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(CommunicationUser user) {
    return user.city.isEmpty ? 'Город не указан' : user.city;
  }
}

/// ────────────── Кнопка "Отписаться" ──────────────
class _UnsubscribeButton extends StatelessWidget {
  const _UnsubscribeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getTextPrimaryColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          child: Text(
            'Отписаться',
            style: AppTextStyles.h14w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// ────────────── Кнопка "Подписаться" ──────────────
class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.button,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            'Подписаться',
            style: AppTextStyles.h14w5.copyWith(
              color: AppColors.surface,
            ),
          ),
        ),
      ),
    );
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
            ? 'https://uploads.paceup.ru/images/users/avatars/def.png'
            : url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: 44,
          height: 44,
          color: AppColors.getBackgroundColor(context),
          alignment: Alignment.center,
          child: CupertinoActivityIndicator(
            radius: 8,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 44,
          height: 44,
          color: AppColors.getBackgroundColor(context),
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.person_fill,
            size: 20,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}
