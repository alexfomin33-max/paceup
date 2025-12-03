import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../features/profile/providers/search/friends_search_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../features/profile/screens/profile_screen.dart';

/// Контент вкладки «Друзья»
/// Переключатели уже в родительском экране. Здесь — секция и «табличный» блок.
class SearchFriendsContent extends ConsumerStatefulWidget {
  final String query;
  const SearchFriendsContent({super.key, required this.query});

  @override
  ConsumerState<SearchFriendsContent> createState() =>
      _SearchFriendsContentState();
}

class _SearchFriendsContentState extends ConsumerState<SearchFriendsContent> {
  // ────────────────────────────────────────────────────────────────────────
  // Обновление провайдеров при переключении вкладок:
  // При каждом создании виджета (переключении вкладки) инвалидируем провайдеры,
  // чтобы получить свежие данные
  // ────────────────────────────────────────────────────────────────────────
  bool _hasInvalidated = false;

  @override
  Widget build(BuildContext context) {
    // Инвалидируем провайдеры при первом build (переключении вкладки)
    if (!_hasInvalidated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.invalidate(recommendedFriendsProvider);
          _hasInvalidated = true;
        }
      });
    }
    final trimmedQuery = widget.query.trim();

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

    // ────────────────────────────────────────────────────────────────────────
    // Функция обновления данных при pull-to-refresh
    // ────────────────────────────────────────────────────────────────────────
    Future<void> onRefresh() async {
      if (isSearching) {
        // При поиске инвалидируем провайдер поиска
        ref.invalidate(searchFriendsProvider(trimmedQuery));
      } else {
        // При просмотре рекомендованных друзей инвалидируем соответствующий провайдер
        ref.invalidate(recommendedFriendsProvider);
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

              return _FriendsListSliver(friends: friends);
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
            error: (error, stack) {
              // Логируем ошибку для отладки
              log('❌ Ошибка загрузки друзей: $error');
              log('Stack trace: $stack');

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
                        SelectableText.rich(
                          TextSpan(
                            text: 'Ошибка загрузки\n',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                            children: [
                              TextSpan(
                                text: ErrorHandler.format(error),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
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
      ),
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
  bool _isToggling = false; // Флаг процесса подписки/отписки

  bool get _currentIsSubscribed {
    return _localIsSubscribed ?? widget.friend.isSubscribed;
  }

  Future<void> _handleToggleSubscribe() async {
    if (_isToggling) return; // Предотвращаем повторные клики

    final currentStatus = _currentIsSubscribed;

    // Оптимистичное обновление UI
    setState(() {
      _localIsSubscribed = !currentStatus;
      _isToggling = true;
    });

    try {
      // Выполняем подписку/отписку через провайдер
      final params = ToggleSubscribeParams(
        targetUserId: widget.friend.id,
        isSubscribed: currentStatus,
      );

      final newStatus = await ref.read(toggleSubscribeProvider(params).future);

      // Обновляем локальное состояние на основе ответа сервера
      if (mounted) {
        setState(() {
          _localIsSubscribed = newStatus;
          _isToggling = false;
        });
      }

      // НЕ инвалидируем провайдеры - пользователи должны оставаться в списке
      // Только меняется иконка подписки (локальное состояние)
    } catch (e) {
      // В случае ошибки возвращаем предыдущее состояние
      if (mounted) {
        setState(() {
          _localIsSubscribed = currentStatus;
          _isToggling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      log('❌ Ошибка подписки/отписки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = _currentIsSubscribed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => ProfileScreen(userId: widget.friend.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Аватар
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: widget.friend.avatarUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.getSkeletonBaseColor(context),
                    alignment: Alignment.center,
                    child: const CupertinoActivityIndicator(),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 44,
                    height: 44,
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
                      style: AppTextStyles.h15w5.copyWith(
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
                      style: AppTextStyles.h13w4Sec.copyWith(
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка подписки/отписки
              // Если подписан → показываем красную иконку с крестиком
              // Если не подписан → показываем синюю иконку с плюсом
              IconButton(
                onPressed: _isToggling ? null : _handleToggleSubscribe,
                splashRadius: 24,
                icon: _isToggling
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isSubscribed
                            ? CupertinoIcons.person_crop_circle_badge_xmark
                            : CupertinoIcons.person_crop_circle_badge_plus,
                        size: 26,
                      ),
                style: IconButton.styleFrom(
                  foregroundColor: isSubscribed
                      ? AppColors
                            .error // Красный цвет для подписки
                      : AppColors.brandPrimary, // Синий цвет для неподписки
                  disabledForegroundColor: AppColors.disabledText,
                ),
              ),
            ],
          ),
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
          fontWeight: FontWeight.w500,
          color: AppColors.getTextPrimaryColor(context),
        ),
      ),
    );
  }
}

// ──────────────────────────── Список друзей ────────────────────────────
//
//  Структура соответствует стилю из clubs_content.dart для единообразия UI.
//  Используем Container с границами сверху и снизу, Divider между элементами.
class _FriendsListSliver extends StatelessWidget {
  final List<FriendUser> friends;
  const _FriendsListSliver({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
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
  }
}
