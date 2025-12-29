import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_user.dart';
import '../providers/users_search_provider.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/widgets/app_bar.dart';
import '../../../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import 'personal_chat_screen.dart';
import '../../../../../profile/screens/profile_screen.dart';

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
        backgroundColor: AppColors.getBackgroundColor(context),
        appBar: const PaceAppBar(title: 'Начать общение'),
        body: Column(
          children: [
            // ─── Поле поиска ───
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
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
    return TextField(
      controller: controller,
      cursorColor: AppColors.getTextSecondaryColor(context),
      textInputAction: TextInputAction.search,
      style: AppTextStyles.h14w4.copyWith(
        color: AppColors.getTextPrimaryColor(context),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          CupertinoIcons.search,
          size: 18,
          color: AppColors.getIconSecondaryColor(context),
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.getSurfaceColor(context),
        hintText: hintText,
        hintStyle: AppTextStyles.h14w4Place.copyWith(
          color: AppColors.getTextPlaceholderColor(context),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.getBorderColor(context),
            width: 1,
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.getTextSecondaryColor(context),
              ),
              children: [
                TextSpan(
                  text: error,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.error,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Пользователи не найдены',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.getTextSecondaryColor(context),
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
              children: users.map((user) => _RowTile(user: user)).toList(),
            ),
          ),
        ),

        // Индикатор загрузки или кнопка "Загрузить ещё"
        if (isLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
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
class _RowTile extends StatefulWidget {
  final ChatUser user;

  const _RowTile({required this.user});

  @override
  State<_RowTile> createState() => _RowTileState();
}

class _RowTileState extends State<_RowTile> {
  bool _suppressChatTap = false;

  /// Формирование URL для аватара
  String _getAvatarUrl(String avatar, int userId) {
    if (avatar.isEmpty) {
      return 'http://uploads.paceup.ru/images/users/avatars/def.png';
    }
    if (avatar.startsWith('http')) return avatar;
    return 'http://uploads.paceup.ru/images/users/avatars/$userId/$avatar';
  }

  /// ─── Открытие чата с выбранным пользователем ───
  Future<void> _openChat(BuildContext context) async {
    if (_suppressChatTap) return;

    final result = await Navigator.of(context, rootNavigator: true).push(
      TransparentPageRoute(
        builder: (_) => PersonalChatScreen(
          chatId: 0, // Новый чат, будет создан на сервере
          userId: widget.user.id,
          userName: widget.user.fullName,
          userAvatar: widget.user.avatar,
        ),
      ),
    );

    if (!mounted) return;
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// ─── Переход в профиль пользователя ───
  Future<void> _openProfile(BuildContext context) async {
    _suppressChatTap = true;
    await Navigator.of(context).push(
      TransparentPageRoute(
        builder: (_) => ProfileScreen(userId: widget.user.id),
      ),
    );
    Future.microtask(() => _suppressChatTap = false);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _getAvatarUrl(widget.user.avatar, widget.user.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openChat(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // ─── Аватар → переход в профиль ───
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openProfile(context),
              child: ClipOval(
                child: Builder(
                  builder: (context) {
                    final dpr = MediaQuery.of(context).devicePixelRatio;
                    final w = (44 * dpr).round();
                    return CachedNetworkImage(
                      imageUrl: avatarUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      // ── Встроенная анимация fade-in работает по умолчанию
                      memCacheWidth: w,
                      maxWidthDiskCache: w,
                      placeholder: (context, url) => Container(
                        width: 44,
                        height: 44,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceMuted
                            : AppColors.skeletonBase,
                        child: Center(
                          child: CupertinoActivityIndicator(
                            radius: 9,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
                      ),
                      errorWidget: (context, imageUrl, error) {
                        return Container(
                          width: 44,
                          height: 44,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSurfaceMuted
                              : AppColors.skeletonBase,
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.person,
                            size: 20,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ─── Имя/возраст/город → переход в профиль ───
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openProfile(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.user.age} лет, ${widget.user.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

            // ─── Остальная зона карточки → чат ───
            IconButton(
              tooltip: 'Написать',
              splashRadius: 22,
              icon: const Icon(
                CupertinoIcons.chat_bubble_text,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              onPressed: () => _openChat(context),
            ),
          ],
        ),
      ),
    );
  }
}
