import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../profile/screens/profile_screen.dart';

/// ──────────────────────── Контент участников клуба из API с пагинацией ────────────────────────
class CoffeeRunVldMembersContent extends ConsumerStatefulWidget {
  final int clubId;
  const CoffeeRunVldMembersContent({super.key, required this.clubId});

  @override
  ConsumerState<CoffeeRunVldMembersContent> createState() =>
      CoffeeRunVldMembersContentState();
}

class CoffeeRunVldMembersContentState
    extends ConsumerState<CoffeeRunVldMembersContent> {
  final List<Map<String, dynamic>> _members = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 25;
  final Map<int, bool> _togglingSubscriptions =
      {}; // Для отслеживания процесса подписки/отписки

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _scrollController.addListener(_onScroll);
  }

  /// ──────────────────────── Обновление списка участников (сброс и перезагрузка) ────────────────────────
  void refreshMembers() {
    if (!mounted) return;
    setState(() {
      _members.clear();
      _currentPage = 1;
      _hasMore = true;
      _loading = false;
    });
    _loadMembers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ──────────────────────── Обработка прокрутки для подгрузки новых участников ────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loading &&
        _hasMore) {
      _loadMembers();
    }
  }

  /// ──────────────────────── Загрузка участников с пагинацией ────────────────────────
  Future<void> _loadMembers() async {
    if (_loading || !_hasMore) return;

    if (!mounted) return; // Проверка перед первым setState
    setState(() {
      _loading = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.get(
        '/get_club_members.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (!mounted) return; // Проверка после асинхронного запроса

      if (data['success'] == true) {
        final members = data['members'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        setState(() {
          _members.addAll(members.map((m) => m as Map<String, dynamic>));
          _hasMore = hasMore;
          _currentPage++;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return; // Проверка в catch блоке
      setState(() {
        _loading = false;
      });
    }
  }

  /// ──────────────────────── Подписка/отписка на пользователя ────────────────────────
  Future<void> _toggleSubscribe(
    int targetUserId,
    bool currentlySubscribed,
  ) async {
    // Проверяем, не идет ли уже процесс подписки/отписки для этого пользователя
    if (_togglingSubscriptions[targetUserId] == true) return;

    if (!mounted) return;
    setState(() {
      _togglingSubscriptions[targetUserId] = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final action = currentlySubscribed ? 'unsubscribe' : 'subscribe';

      final data = await api.post(
        '/toggle_subscribe.php',
        body: {'target_user_id': targetUserId.toString(), 'action': action},
      );

      if (!mounted) return;

      if (data['success'] == true) {
        final isSubscribed = data['is_subscribed'] as bool? ?? false;

        // Обновляем статус подписки в списке участников
        setState(() {
          final index = _members.indexWhere(
            (m) => (m['user_id'] as int?) == targetUserId,
          );
          if (index != -1) {
            _members[index]['is_subscribed'] = isSubscribed;
          }
          _togglingSubscriptions[targetUserId] = false;
        });
      } else {
        final errorMessage = data['message'] as String? ?? 'Ошибка подписки';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _togglingSubscriptions[targetUserId] = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _togglingSubscriptions[targetUserId] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty && !_loading) {
      return Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Участники отсутствуют',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.getTextSecondaryColor(context),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _members.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _members.length) {
          // Индикатор загрузки в конце списка
          return Builder(
            builder: (context) => Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.all(16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final m = _members[index];
        final name = m['name'] as String? ?? 'Пользователь';
        final avatarUrl = m['avatar_url'] as String? ?? '';
        final role = m['role'] as String?;
        final userId = m['user_id'] as int?;
        final isCurrentUser = m['is_current_user'] as bool? ?? false;
        final isSubscribed = m['is_subscribed'] as bool? ?? false;
        final isToggling =
            userId != null && (_togglingSubscriptions[userId] == true);

        return Builder(
          builder: (context) => Container(
            color: AppColors.getSurfaceColor(context),
            child: _MemberRow(
              name: name,
              role: role,
              avatarUrl: avatarUrl,
              userId: userId,
              isCurrentUser: isCurrentUser,
              isSubscribed: isSubscribed,
              isToggling: isToggling,
              onTap: userId != null
                  ? () {
                      Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => ProfileScreen(userId: userId),
                        ),
                      );
                    }
                  : null,
              onToggleSubscribe: userId != null && !isCurrentUser
                  ? () => _toggleSubscribe(userId, isSubscribed)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// ──────────────────────── Карточка участника в стиле событий ────────────────────────
class _MemberRow extends StatelessWidget {
  final String name;
  final String? role;
  final String avatarUrl;
  final int? userId;
  final bool isCurrentUser;
  final bool isSubscribed;
  final bool isToggling;
  final VoidCallback? onTap;
  final VoidCallback? onToggleSubscribe;

  const _MemberRow({
    required this.name,
    this.role,
    required this.avatarUrl,
    this.userId,
    this.isCurrentUser = false,
    this.isSubscribed = false,
    this.isToggling = false,
    this.onTap,
    this.onToggleSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 0, top: 4, bottom: 4),
        child: Row(
          children: [
            ClipOval(
              child: avatarUrl.isNotEmpty
                  ? _Avatar40(url: avatarUrl)
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.getBorderColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.getIconSecondaryColor(context),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // имя + роль
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                  if (role != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      role!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Иконка действий.
            // ── Для текущего пользователя показываем пустое место того же размера,
            //    чтобы высота карточки совпадала с другими пользователями.
            if (isCurrentUser)
              const SizedBox(width: 48, height: 48)
            else if (userId != null)
              IconButton(
                onPressed: isToggling ? null : onToggleSubscribe,
                splashRadius: 22,
                icon: isToggling
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isSubscribed
                            ? CupertinoIcons.person_crop_circle_badge_minus
                            : CupertinoIcons.person_crop_circle_badge_plus,
                        size: 24,
                      ),
                style: IconButton.styleFrom(
                  foregroundColor: isSubscribed
                      ? Colors.red
                      : AppColors.brandPrimary,
                  disabledForegroundColor: AppColors.disabledText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────── Аватар 40×40 с кэшем ────────────────────────
class _Avatar40 extends StatelessWidget {
  final String url;
  const _Avatar40({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (40 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      maxWidthDiskCache: w,
      errorWidget: (context, imageUrl, error) => Builder(
        builder: (context) => Container(
          width: 40,
          height: 40,
          color: AppColors.getBorderColor(context),
          child: Icon(
            Icons.person,
            size: 24,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}
