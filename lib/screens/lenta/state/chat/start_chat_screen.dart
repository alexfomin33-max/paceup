import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/chat_user.dart';
import '../../../../providers/chat/users_search_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/app_bar.dart';
import '../../../../widgets/interactive_back_swipe.dart';
import '../../../../widgets/transparent_route.dart';
import 'personal_chat_screen.dart';

/// Страница для начала нового чата с поиском пользователей
class StartChatScreen extends ConsumerStatefulWidget {
  const StartChatScreen({super.key});

  @override
  ConsumerState<StartChatScreen> createState() => _StartChatScreenState();
}

class _StartChatScreenState extends ConsumerState<StartChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Загружаем подписчиков при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usersSearchProvider.notifier).loadSubscribedUsers();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Обработка изменения текста в поле поиска с debounce
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      final notifier = ref.read(usersSearchProvider.notifier);
      
      if (query.isEmpty) {
        // Если запрос пустой, загружаем подписчиков
        notifier.loadSubscribedUsers();
      } else {
        // Иначе ищем пользователей
        notifier.searchUsers(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(usersSearchProvider);

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const PaceAppBar(title: 'Начать общение'),
        body: Column(
          children: [
            // ─── Поле поиска ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: _SearchField(
                controller: _searchController,
                hintText: 'Поиск пользователей',
              ),
            ),

            // ─── Список людей ───
            Expanded(
              child: _PeopleList(
                users: searchState.users,
                isLoading: searchState.isLoading,
                hasMore: searchState.hasMore,
                error: searchState.error,
                onLoadMore: () {
                  final query = _searchController.text.trim();
                  final notifier = ref.read(usersSearchProvider.notifier);
                  
                  if (query.isEmpty) {
                    notifier.loadMoreSubscribedUsers();
                  } else {
                    notifier.loadMoreSearchResults(query);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Виджет поля поиска ───
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _SearchField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        cursorColor: AppColors.textPrimary,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            CupertinoIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: AppColors.textPlaceholder,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border, width: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.outline, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
      ),
    );
  }
}

/// ─── Список людей ───
class _PeopleList extends StatelessWidget {
  final List<ChatUser> users;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final VoidCallback onLoadMore;

  const _PeopleList({
    required this.users,
    required this.isLoading,
    required this.hasMore,
    this.error,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    // Показываем ошибку если есть
    if (error != null && users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText.rich(
            TextSpan(
              text: 'Ошибка загрузки: ',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              children: [
                TextSpan(
                  text: error,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Показываем пустое состояние если нет пользователей
    if (!isLoading && users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Пользователи не найдены',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Табличный блок
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Column(
              children: List.generate(users.length, (i) {
                final user = users[i];
                return Column(
                  children: [
                    if (i.isEven)
                      ColoredBox(
                        color: AppColors.surfaceMuted,
                        child: _RowTile(user: user),
                      )
                    else
                      _RowTile(user: user),
                  ],
                );
              }),
            ),
          ),
        ),

        // Индикатор загрузки или кнопка "Загрузить ещё"
        if (isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CupertinoActivityIndicator(),
              ),
            ),
          )
        else if (hasMore && users.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: GestureDetector(
                  onTap: onLoadMore,
                  child: const Text(
                    'Загрузить ещё',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// ─── Строка в списке людей ───
class _RowTile extends StatelessWidget {
  final ChatUser user;

  const _RowTile({required this.user});

  /// Формирование URL для аватара
  String _getAvatarUrl(String avatar, int userId) {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    return 'http://uploads.paceup.ru/images/users/avatars/$userId/$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _getAvatarUrl(user.avatar, user.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        // Открываем персональный чат
        final result = await Navigator.of(context).push(
          TransparentPageRoute(
            builder: (_) => PersonalChatScreen(
              chatId: 0, // Новый чат, будет создан на сервере
              userId: user.id,
              userName: user.fullName,
              userAvatar: user.avatar,
            ),
          ),
        );

        // Возвращаемся назад после создания чата
        if (result == true && context.mounted) {
          Navigator.of(context).pop(true);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // Аватар пользователя
            ClipOval(
              child: Builder(
                builder: (context) {
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final w = (44 * dpr).round();
                  final h = (44 * dpr).round();
                  return CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 120),
                    memCacheWidth: w,
                    memCacheHeight: h,
                    maxWidthDiskCache: w,
                    maxHeightDiskCache: h,
                    errorWidget: (_, __, ___) {
                      return Container(
                        width: 44,
                        height: 44,
                        color: AppColors.skeletonBase,
                        alignment: Alignment.center,
                        child: const Icon(
                          CupertinoIcons.person,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.age} лет, ${user.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Написать',
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.chat_bubble_text,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  TransparentPageRoute(
                    builder: (_) => PersonalChatScreen(
                      chatId: 0,
                      userId: user.id,
                      userName: user.fullName,
                      userAvatar: user.avatar,
                    ),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
