import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../providers/services/api_provider.dart';
import '../../../../../core/utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/transparent_route.dart';
import '../../../../../core/widgets/more_menu_overlay.dart';
import '../../../../../core/widgets/more_menu_hub.dart';
import '../../../../profile/screens/profile_screen.dart';

/// ──────────────────────── Контент участников клуба из API с пагинацией ────────────────────────
class CoffeeRunVldMembersContent extends ConsumerStatefulWidget {
  final int clubId;
  final bool isOwner; // Является ли текущий пользователь владельцем клуба
  const CoffeeRunVldMembersContent({
    super.key,
    required this.clubId,
    this.isOwner = false,
  });

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

  /// ──────────────────────── Показать меню действий для участника (только для владельца) ────────────────────────
  void _showMemberMenu(
    BuildContext context,
    GlobalKey menuKey,
    int memberUserId,
    String memberName,
  ) {
    final items = <MoreMenuItem>[];

    // Пункт "Сделать админом"
    items.add(
      MoreMenuItem(
        text: 'Сделать админом',
        icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        onTap: () async {
          MoreMenuHub.hide();
          await _makeAdmin(memberUserId, memberName);
        },
      ),
    );

    // Пункт "Исключить из клуба"
    items.add(
      MoreMenuItem(
        text: 'Исключить из клуба',
        icon: CupertinoIcons.person_crop_circle_badge_minus,
        iconColor: AppColors.red,
        textStyle: const TextStyle(color: AppColors.red),
        onTap: () async {
          MoreMenuHub.hide();
          await _removeMember(memberUserId, memberName);
        },
      ),
    );

    // Показываем попап меню
    MoreMenuOverlay(anchorKey: menuKey, items: items).show(context);
  }

  /// ──────────────────────── Сделать участника админом ────────────────────────
  Future<void> _makeAdmin(int memberUserId, String memberName) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/update_club_member_role.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': memberUserId.toString(),
          'role': 'admin',
        },
      );

      if (!mounted) return;

      if (data['success'] == true) {
        // Обновляем роль в списке участников
        setState(() {
          final index = _members.indexWhere(
            (m) => (m['user_id'] as int?) == memberUserId,
          );
          if (index != -1) {
            _members[index]['role'] = 'admin';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName назначен администратором'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Ошибка назначения администратора';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
    }
  }

  /// ──────────────────────── Исключить участника из клуба ────────────────────────
  Future<void> _removeMember(int memberUserId, String memberName) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/remove_club_member.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': memberUserId.toString(),
        },
      );

      if (!mounted) return;

      if (data['success'] == true) {
        // Удаляем участника из списка
        setState(() {
          _members.removeWhere(
            (m) => (m['user_id'] as int?) == memberUserId,
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$memberName исключен из клуба'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Ошибка исключения из клуба';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
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
              child: const Center(child: CupertinoActivityIndicator(radius: 10)),
            ),
          );
        }

        final m = _members[index];
        final name = m['name'] as String? ?? 'Пользователь';
        final avatarUrl = m['avatar_url'] as String? ?? '';
        final role = m['role'] as String?;
        final userId = m['user_id'] as int?;
        final isCurrentUser = m['is_current_user'] as bool? ?? false;

        return Builder(
          builder: (context) => Container(
            color: AppColors.getSurfaceColor(context),
            child: _MemberRow(
              name: name,
              role: role,
              avatarUrl: avatarUrl,
              userId: userId,
              isCurrentUser: isCurrentUser,
              isOwner: widget.isOwner,
              onTap: userId != null
                  ? () {
                      Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => ProfileScreen(userId: userId),
                        ),
                      );
                    }
                  : null,
              onShowMenu: widget.isOwner && userId != null && !isCurrentUser
                  ? (menuKey) => _showMemberMenu(context, menuKey, userId, name)
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
  final bool isOwner;
  final VoidCallback? onTap;
  final void Function(GlobalKey)? onShowMenu;

  const _MemberRow({
    required this.name,
    this.role,
    required this.avatarUrl,
    this.userId,
    this.isCurrentUser = false,
    this.isOwner = false,
    this.onTap,
    this.onShowMenu,
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
            // ── Для владельца клуба показываем иконку трех точек для меню действий.
            if (isCurrentUser)
              const SizedBox(width: 48, height: 48)
            else if (isOwner && onShowMenu != null)
              Builder(
                builder: (context) {
                  final menuKey = GlobalKey();
                  return IconButton(
                    key: menuKey,
                    onPressed: () => onShowMenu!(menuKey),
                    splashRadius: 22,
                    icon: const Icon(
                      CupertinoIcons.ellipsis_vertical,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.getIconPrimaryColor(context),
                    ),
                  );
                },
              )
            else
              const SizedBox(width: 48, height: 48),
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
      memCacheWidth: w,
      maxWidthDiskCache: w,
      placeholder: (context, url) => Container(
        width: 40,
        height: 40,
        color: AppColors.getBorderColor(context),
        child: Center(
          child: CupertinoActivityIndicator(
            radius: 8,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
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
