import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/primary_button.dart';
import '../../../../../providers/search/friends_search_provider.dart';

/// Контент вкладки «Друзья»
/// Переключатели уже в родительском экране. Здесь — секция и «табличный» блок.
class SearchFriendsContent extends ConsumerWidget {
  final String query;
  const SearchFriendsContent({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trimmedQuery = query.trim();
    
    // ────────────────────────────────────────────────────────────────────────
    // Логика переключения между поиском и рекомендованными друзьями:
    // • Если строка поиска НЕ пустая → показываем результаты поиска
    // • Если строка поиска пустая → ВСЕГДА показываем рекомендованных друзей
    // ────────────────────────────────────────────────────────────────────────
    
    // Критически важно: при пустом query ВСЕГДА используем рекомендованных друзей
    // Это гарантирует, что при очистке поля поиска список рекомендованных друзей
    // сразу отобразится
    final isSearching = trimmedQuery.isNotEmpty;
    final friendsAsync = isSearching
        ? ref.watch(searchFriendsProvider(trimmedQuery))
        : ref.watch(recommendedFriendsProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ───── Заголовок секции (показываем только если не идет поиск)
        if (!isSearching)
          const SliverToBoxAdapter(
            child: _SectionTitle('Рекомендованные друзья'),
          ),

        // ───── Контент: список друзей или результаты поиска
        friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      isSearching
                          ? 'Ничего не найдено'
                          : 'Нет рекомендованных друзей',
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
                  children: List.generate(friends.length, (i) {
                    final friend = friends[i];
                    return Column(
                      children: [
                        _FriendRow(friend: friend),
                        if (i != friends.length - 1)
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
            // Логируем ошибку для отладки
            debugPrint('❌ Ошибка загрузки друзей: $error');
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

        // ───── Подпись и кнопка «Пригласить» (показываем только если не идет поиск)
        if (!isSearching) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Пригласите друзей, которые еще не пользуются',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: PrimaryButton(
                  text: 'Пригласить',
                  onPressed: () {},
                  width: 220,
                ),
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _FriendRow extends ConsumerStatefulWidget {
  final FriendUser friend;
  const _FriendRow({required this.friend});

  @override
  ConsumerState<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends ConsumerState<_FriendRow> {
  // Локальное состояние для оптимистичного обновления UI
  bool? _localIsSubscribed;

  bool get _currentIsSubscribed {
    return _localIsSubscribed ?? widget.friend.isSubscribed;
  }

  Future<void> _handleToggleSubscribe() async {
    final currentStatus = _currentIsSubscribed;
    
    // Оптимистичное обновление UI
    setState(() {
      _localIsSubscribed = !currentStatus;
    });

    try {
      // Выполняем подписку/отписку через провайдер
      final params = ToggleSubscribeParams(
        targetUserId: widget.friend.id,
        isSubscribed: currentStatus,
      );
      
      final newStatus = await ref.read(
        toggleSubscribeProvider(params).future,
      );

      // Обновляем локальное состояние на основе ответа сервера
      setState(() {
        _localIsSubscribed = newStatus;
      });

      // НЕ инвалидируем провайдеры - пользователи должны оставаться в списке
      // Только меняется иконка подписки (локальное состояние)
    } catch (e) {
      // В случае ошибки возвращаем предыдущее состояние
      setState(() {
        _localIsSubscribed = currentStatus;
      });
      
      debugPrint('❌ Ошибка подписки/отписки: $e');
      
      // Можно показать сообщение об ошибке пользователю
      if (mounted) {
        // TODO: Показать SnackBar или другое уведомление об ошибке
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = _currentIsSubscribed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Аватар
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.friend.avatarUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 40,
                height: 40,
                color: AppColors.getSkeletonBaseColor(context),
                alignment: Alignment.center,
                child: const CupertinoActivityIndicator(),
              ),
              errorWidget: (context, url, error) => Container(
                width: 40,
                height: 40,
                color: AppColors.getSkeletonBaseColor(context),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.person,
                  size: 20,
                  color: AppColors.getTextSecondaryColor(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Имя + возраст/город
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friend.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h14w5.copyWith(
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.friend.age > 0
                      ? '${widget.friend.age} лет, ${widget.friend.city}'
                      : widget.friend.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h12w4Sec.copyWith(
                    color: AppColors.getTextSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),

          // Кнопка подписки/отписки
          // Если подписан → показываем красную иконку "checkmark"
          // Если не подписан → показываем синюю иконку "plus"
          IconButton(
            onPressed: _handleToggleSubscribe,
            splashRadius: 24,
            icon: Icon(
              isSubscribed
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.person_crop_circle_badge_plus,
              size: 26,
              color: isSubscribed
                  ? Colors.red // Красный цвет для подписки
                  : AppColors.brandPrimary, // Синий цвет для подписки
            ),
          ),
        ],
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
          fontWeight: FontWeight.w500,
          color: AppColors.getTextPrimaryColor(context),
        ),
      ),
    );
  }
}
