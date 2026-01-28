import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../features/profile/providers/search/friends_search_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/error_handler.dart';
// import '../../../../../../core/widgets/primary_button.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../features/profile/screens/profile_screen.dart';

/// Контент вкладки «Друзья»
/// Переключатели уже в родительском экране. Здесь — секция и «табличный» блок.
/// [customHeaderSlivers] — слайверы (пилюля, поле поиска) вставляются в начало
/// скролла, когда экран поиска скроллит шапку вместе с контентом.
class SearchFriendsContent extends ConsumerStatefulWidget {
  final String query;
  final List<Widget>? customHeaderSlivers;
  const SearchFriendsContent({
    super.key,
    required this.query,
    this.customHeaderSlivers,
  });

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
    // 🔹 СИНХРОНИЗАЦИЯ КЭША: отслеживаем изменения данных и обновляем
    // кэш состояния подписок после завершения build
    // ────────────────────────────────────────────────────────────────────────
    // ⚠️ ВАЖНО: нельзя обновлять провайдеры во время build
    // Используем ref.listen для отслеживания изменений и обновления
    // кэша после завершения build через Future.microtask
    ref.listen(
      isSearching
          ? searchFriendsProvider(trimmedQuery)
          : recommendedFriendsProvider,
      (previous, next) {
        next.whenData((friends) {
          // Откладываем обновление кэша до завершения build
          Future.microtask(() {
            final subscriptionNotifier = ref.read(
              subscriptionStateProvider.notifier,
            );
            for (final friend in friends) {
              // Обновляем кэш только если там нет значения для этого пользователя
              // (чтобы не перезаписать состояние, измененное пользователем)
              if (subscriptionNotifier.getSubscription(friend.id) == null) {
                subscriptionNotifier.updateSubscription(
                  friend.id,
                  friend.isSubscribed,
                );
              }
            }
          });
        });
      },
    );

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
          if (widget.customHeaderSlivers != null) ...widget.customHeaderSlivers!,
          if (widget.customHeaderSlivers != null)
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (widget.customHeaderSlivers == null)
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

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

              // Сетка карточек 2xN
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 201,
                  ),
                  itemCount: friends.length,
                  itemBuilder: (context, i) => _FriendCard(
                    key: ValueKey<int>(friends[i].id),
                    friend: friends[i],
                  ),
                ),
              );
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
          // if (!isSearching) ...[
          //   const SliverToBoxAdapter(child: SizedBox(height: 25)),

          //   SliverToBoxAdapter(
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 16),
          //       child: Center(
          //         child: Text(
          //           'Пригласите друзей, которые еще не пользуются',
          //           textAlign: TextAlign.center,
          //           style: TextStyle(
          //             fontFamily: 'Inter',
          //             fontSize: 13,
          //             color: AppColors.getTextSecondaryColor(context),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),

          //   const SliverToBoxAdapter(child: SizedBox(height: 16)),

          //   SliverToBoxAdapter(
          //     child: Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 16),
          //       child: Center(
          //         child: PrimaryButton(
          //           text: 'Пригласить',
          //           onPressed: () {},
          //           width: 220,
          //         ),
          //       ),
          //     ),
          //   ),
          // ],

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Карточка друга в сетке 2xN
///
/// Отображает аватар, имя, возраст/город и кнопку подписки
/// При нажатии на аватар открывает детальную страницу профиля
class _FriendCard extends ConsumerStatefulWidget {
  final FriendUser friend;
  const _FriendCard({super.key, required this.friend});

  @override
  ConsumerState<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends ConsumerState<_FriendCard> {
  // ────────────────────────────────────────────────────────────────────────
  // 🔹 СОСТОЯНИЕ ПЕРЕКЛЮЧЕНИЯ: флаг для блокировки кнопки во время запроса
  // ────────────────────────────────────────────────────────────────────────
  bool _isToggling = false;

  /// Получает актуальное состояние подписки из провайдера или пропсов
  ///
  /// ⚡ PERFORMANCE & RELIABILITY:
  /// - Сначала проверяет кэш состояния подписок (subscriptionStateProvider)
  /// - Если в кэше нет - использует значение из пропсов
  /// - Это гарантирует сохранение состояния при прокрутке списка
  bool get _currentIsSubscribed {
    final subscriptionState = ref.read(subscriptionStateProvider);
    final cachedState = subscriptionState[widget.friend.id];

    // Если есть кэшированное состояние - используем его
    if (cachedState != null) {
      return cachedState;
    }

    // Иначе используем значение из пропсов
    return widget.friend.isSubscribed;
  }

  /// Переход на страницу профиля пользователя
  ///
  /// ⚡ UX: открывает профиль пользователя при клике на аватарку
  void _navigateToProfile() {
    Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => ProfileScreen(userId: widget.friend.id),
      ),
    );
  }

  /// Обработчик подписки/отписки с защитой от race condition
  ///
  /// ⚡ PERFORMANCE & RELIABILITY:
  /// - Защита от повторных нажатий через флаг _isToggling
  /// - Сохранение исходного состояния для отката при ошибке
  /// - Обновление состояния только после успешного ответа сервера
  /// - Правильная обработка ошибок с восстановлением состояния
  Future<void> _handleSubscribe() async {
    // ────────── ЗАЩИТА: предотвращаем повторные нажатия ──────────
    if (_isToggling) return;

    final currentStatus = _currentIsSubscribed;
    final targetUserId = widget.friend.id;

    // ────────── БЛОКИРУЕМ кнопку перед запросом ──────────
    setState(() {
      _isToggling = true;
    });

    try {
      // ────────── СОЗДАЕМ параметры для запроса ──────────
      final params = ToggleSubscribeParams(
        targetUserId: targetUserId,
        isSubscribed: currentStatus,
      );

      // ────────── ВЫПОЛНЯЕМ запрос к серверу ──────────
      // ✅ Используем .future для получения результата напрямую
      // autoDispose провайдер автоматически очищается после использования
      final newStatus = await ref.read(toggleSubscribeProvider(params).future);

      // ────────── ОБНОВЛЯЕМ состояние только после успешного ответа ──────────
      if (mounted) {
        // Сохраняем новое состояние в провайдер кэша
        ref
            .read(subscriptionStateProvider.notifier)
            .updateSubscription(targetUserId, newStatus);

        setState(() {
          _isToggling = false;
        });

        // ────────────────────────────────────────────────────────────────────────
        // 🔹 НЕ инвалидируем провайдер - пользователи остаются в списке
        // до обновления экрана (pull-to-refresh). Меняется только кнопка.
        // Состояние сохраняется в subscriptionStateProvider и не теряется
        // при прокрутке списка.
        // ────────────────────────────────────────────────────────────────────────
      }
    } catch (e) {
      // ────────── ОТКАТ: восстанавливаем исходное состояние при ошибке ──────────
      if (mounted) {
        // Восстанавливаем исходное состояние в кэше
        ref
            .read(subscriptionStateProvider.notifier)
            .updateSubscription(targetUserId, currentStatus);

        setState(() {
          _isToggling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // Логируем ошибку для отладки
      log('❌ Ошибка подписки/отписки: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final isSubscribed = _currentIsSubscribed;
    final desc = friend.city.isNotEmpty ? friend.city : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.xll),
        boxShadow: const [
          BoxShadow(
            color: AppColors.twinshadow,
            blurRadius: 20,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ────────────────────────────────────────────────────────────────────────
          // 🔹 КЛИКАБЕЛЬНАЯ АВАТАРКА: переход на профиль пользователя
          // ────────────────────────────────────────────────────────────────────────
          GestureDetector(
            onTap: _navigateToProfile,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getBorderColor(context),
                  width: 0.5,
                ),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: friend.avatarUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.getBackgroundColor(context),
                    alignment: Alignment.center,
                    child: CupertinoActivityIndicator(
                      radius: 10,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.getBackgroundColor(context),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.person_fill,
                      size: 32,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Имя с фамилией в стиле названия клуба
          Text(
            friend.fullName,
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
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            // Возраст и город в стиле города клуба
            Text(
              desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.2,
                color: AppColors.getTextPrimaryColor(context),
              ),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                disabledBackgroundColor: AppColors.disabledText,
              ),
              child: _isToggling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CupertinoActivityIndicator(
                        radius: 10,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isSubscribed ? 'Отписаться' : 'Подписаться',
                      style: const TextStyle(
                        fontSize: 13,
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
