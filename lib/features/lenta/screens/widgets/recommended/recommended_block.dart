import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../profile/providers/search/friends_search_provider.dart';

/// Блок «Рекомендации для вас» с реальными данными из API
class RecommendedBlock extends ConsumerWidget {
  const RecommendedBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedFriendsAsync = ref.watch(recommendedFriendsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Рекомендации для вас',
            style: AppTextStyles.h15w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        recommendedFriendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) {
              return const SizedBox.shrink();
            }
            return _RecommendedList(friends: friends);
          },
          loading: () => const SizedBox(
            height: 286,
            child: Center(child: CupertinoActivityIndicator()),
          ),
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Горизонтальный список карточек рекомендаций с реальными данными
class _RecommendedList extends StatelessWidget {
  final List<FriendUser> friends;

  const _RecommendedList({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 254,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (int i = 0; i < friends.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _FriendCard(friend: friends[i]),
          ],
        ],
      ),
    );
  }
}

/// Одна карточка рекомендации с реальными данными
class _FriendCard extends ConsumerStatefulWidget {
  final FriendUser friend;

  const _FriendCard({required this.friend});

  @override
  ConsumerState<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends ConsumerState<_FriendCard> {
  bool? _localIsSubscribed;
  bool _isToggling = false;

  bool get _currentIsSubscribed {
    return _localIsSubscribed ?? widget.friend.isSubscribed;
  }

  Future<void> _handleSubscribe() async {
    if (_isToggling) return;

    final currentStatus = _currentIsSubscribed;

    setState(() {
      _localIsSubscribed = !currentStatus;
      _isToggling = true;
    });

    try {
      final params = ToggleSubscribeParams(
        targetUserId: widget.friend.id,
        isSubscribed: currentStatus,
      );

      final newStatus = await ref.read(toggleSubscribeProvider(params).future);

      if (mounted) {
        setState(() {
          _localIsSubscribed = newStatus;
          _isToggling = false;
        });

        // ────────────────────────────────────────────────────────────────
        // 🔹 НЕ инвалидируем провайдер - пользователи остаются в списке
        // до обновления экрана (pull-to-refresh). Меняется только кнопка.
        // ────────────────────────────────────────────────────────────────
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _localIsSubscribed = currentStatus;
          _isToggling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final isSubscribed = _currentIsSubscribed;
    final desc = friend.age > 0
        ? '${friend.age} лет${friend.city.isNotEmpty ? ', ${friend.city}' : ''}'
        : friend.city.isNotEmpty
        ? friend.city
        : '';

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.getBorderColor(context),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: friend.avatarUrl,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 120,
                height: 120,
                color: AppColors.getSkeletonBaseColor(context),
                alignment: Alignment.center,
                child: const CupertinoActivityIndicator(),
              ),
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 120,
                color: AppColors.getSkeletonBaseColor(context),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.person,
                  size: 40,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            friend.fullName,
            style: AppTextStyles.h14w5.copyWith(
              color: AppColors.getTextPrimaryColor(context),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              desc,
              style: AppTextStyles.h12w4Sec.copyWith(
                color: AppColors.getTextSecondaryColor(context),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isToggling ? null : _handleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubscribed
                    ? Colors.red
                    : AppColors.brandPrimary,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surface
                    : AppColors.getSurfaceColor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                disabledBackgroundColor: AppColors.disabledText,
              ),
              child: _isToggling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isSubscribed ? 'Отписаться' : 'Подписаться',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
