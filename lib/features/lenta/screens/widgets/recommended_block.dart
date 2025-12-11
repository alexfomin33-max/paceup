import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/providers/search/friends_search_provider.dart';

/// Блок «Рекомендации для вас» с реальными данными из API
class RecommendedBlock extends ConsumerWidget {
  const RecommendedBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedFriendsAsync = ref.watch(recommendedFriendsProvider);

    // ────────────────────────────────────────────────────────────────
    // 🔹 СИНХРОНИЗАЦИЯ КЭША: отслеживаем изменения данных и обновляем
    // кэш состояния подписок после завершения build
    // ────────────────────────────────────────────────────────────────
    // ⚠️ ВАЖНО: нельзя обновлять провайдеры во время build
    // Используем ref.listen для отслеживания изменений и обновления
    // кэша после завершения build через Future.microtask
    ref.listen(recommendedFriendsProvider, (previous, next) {
      next.whenData((friends) {
        // Откладываем обновление кэша до завершения build
        Future.microtask(() {
          final subscriptionNotifier = ref.read(subscriptionStateProvider.notifier);
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
    });

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
            // ────────────────────────────────────────────────────────────────
            // 🔑 КЛЮЧ: используем ValueKey для сохранения состояния виджета
            // при прокрутке горизонтального списка
            // ────────────────────────────────────────────────────────────────
            // Без ключа виджет пересоздается при скролле и теряет локальное
            // состояние подписки. С ключом Flutter понимает, что это тот же
            // виджет и сохраняет его состояние.
            _FriendCard(
              key: ValueKey<int>(friends[i].id),
              friend: friends[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// Одна карточка рекомендации с реальными данными
class _FriendCard extends ConsumerStatefulWidget {
  final FriendUser friend;

  const _FriendCard({super.key, required this.friend});

  @override
  ConsumerState<_FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends ConsumerState<_FriendCard> {
  // ────────────────────────────────────────────────────────────────
  // 🔹 СОСТОЯНИЕ ПЕРЕКЛЮЧЕНИЯ: флаг для блокировки кнопки во время запроса
  // ────────────────────────────────────────────────────────────────
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
        ref.read(subscriptionStateProvider.notifier).updateSubscription(
          targetUserId,
          newStatus,
        );

        setState(() {
          _isToggling = false;
        });

        // ────────────────────────────────────────────────────────────────
        // 🔹 НЕ инвалидируем провайдер - пользователи остаются в списке
        // до обновления экрана (pull-to-refresh). Меняется только кнопка.
        // Состояние сохраняется в subscriptionStateProvider и не теряется
        // при прокрутке списка.
        // ────────────────────────────────────────────────────────────────
      }
    } catch (e) {
      // ────────── ОТКАТ: восстанавливаем исходное состояние при ошибке ──────────
      if (mounted) {
        // Восстанавливаем исходное состояние в кэше
        ref.read(subscriptionStateProvider.notifier).updateSubscription(
          targetUserId,
          currentStatus,
        );

        setState(() {
          _isToggling = false;
        });
      }
      // Логируем ошибку для отладки
      debugPrint('❌ Ошибка подписки/отписки: $e');
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
