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
  final bool canManageMembers;
  final bool canAssignAdmins;
  final ScrollController scrollController;
  const CoffeeRunVldMembersContent({
    super.key,
    required this.clubId,
    required this.scrollController,
    this.isOwner = false,
    this.canManageMembers = false,
    this.canAssignAdmins = false,
  });

  @override
  ConsumerState<CoffeeRunVldMembersContent> createState() =>
      CoffeeRunVldMembersContentState();
}

class CoffeeRunVldMembersContentState
    extends ConsumerState<CoffeeRunVldMembersContent> {
  final List<Map<String, dynamic>> _members = [];
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 25;
  // ───── Права текущего пользователя ─────
  bool _currentUserIsOwner = false;
  bool _currentUserIsAdmin = false;
  bool _currentUserCanManageMembers = false;
  bool _currentUserCanAssignAdmins = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    // ───── Подписываемся на скролл родительского контроллера ─────
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(CoffeeRunVldMembersContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ───── Если контроллер скролла изменился, переназначаем слушатель ─────
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
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
    // ───── Отписываемся от родительского контроллера ─────
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  /// ──────────────────────── Обработка прокрутки для подгрузки новых участников ────────────────────────
  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    if (widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent * 0.8 &&
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
        final currentUserIsOwner =
            data['current_user_is_owner'] as bool? ?? false;
        final currentUserIsAdmin =
            data['current_user_is_admin'] as bool? ?? false;
        final currentUserCanManageMembers =
            data['current_user_can_manage_members'] as bool? ?? false;
        final currentUserCanAssignAdmins =
            data['current_user_can_assign_admins'] as bool? ?? false;

        setState(() {
          _members.addAll(members.map((m) => m as Map<String, dynamic>));
          _hasMore = hasMore;
          _currentPage++;
          _loading = false;
          _currentUserIsOwner = currentUserIsOwner || widget.isOwner;
          _currentUserIsAdmin = currentUserIsAdmin;
          _currentUserCanManageMembers = currentUserCanManageMembers ||
              widget.canManageMembers ||
              widget.isOwner;
          _currentUserCanAssignAdmins = currentUserCanAssignAdmins ||
              widget.canAssignAdmins ||
              widget.isOwner;
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

  /// ──────────────────────── Показать меню действий для участника ────────────────────────
  void _showMemberMenu(
    BuildContext context,
    GlobalKey menuKey,
    int memberUserId,
    String memberName,
    bool isMemberAdmin,
    bool isMemberCreator,
  ) {
    final items = <MoreMenuItem>[];

    // ───── Пункт "Сделать админом" (только владелец, только для не-админов) ─────
    if (_currentUserCanAssignAdmins && !isMemberCreator && !isMemberAdmin) {
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
    }

    // ───── Пункт "Забрать Админа" (только владелец, только для админов) ─────
    if (_currentUserCanAssignAdmins && !isMemberCreator && isMemberAdmin) {
      items.add(
        MoreMenuItem(
          text: 'Забрать Админа',
          icon: CupertinoIcons.minus_circle,
          iconColor: AppColors.red,
          textStyle: const TextStyle(color: AppColors.red),
          onTap: () async {
            MoreMenuHub.hide();
            await _removeAdmin(memberUserId, memberName);
          },
        ),
      );
    }

    // ───── Пункт "Исключить из клуба" (владелец или админ) ─────
    final canRemove = _currentUserCanManageMembers &&
        !isMemberCreator &&
        !(_currentUserIsAdmin && isMemberAdmin);
    if (canRemove) {
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
    }

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
            _members[index]['role'] = 'Админ';
            _members[index]['is_admin'] = true;
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
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(ErrorHandler.format(e));
    }
  }

  /// ──────────────────────── Забрать права администратора у участника ────────────────────────
  Future<void> _removeAdmin(int memberUserId, String memberName) async {
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.post(
        '/update_club_member_role.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': memberUserId.toString(),
          'role': 'member',
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
            _members[index]['role'] = null;
            _members[index]['is_admin'] = false;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('У $memberName сняты права администратора'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorMessage = data['message'] as String? ??
            'Ошибка снятия прав администратора';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(ErrorHandler.format(e));
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
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(ErrorHandler.format(e));
    }
  }

  /// ──────────────────────── Показ ошибки в диалоге ────────────────────────
  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Ошибка'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText.rich(
            TextSpan(
              text: message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.error,
              ),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ок'),
          ),
        ],
      ),
    );
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
      physics: const NeverScrollableScrollPhysics(),
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
        final isCreator = m['is_creator'] as bool? ?? false;
        final isAdmin = m['is_admin'] as bool? ?? false;
        final canAssignAdmin =
            _currentUserCanAssignAdmins && !isCreator && !isAdmin;
        final canRemove = _currentUserCanManageMembers &&
            !isCreator &&
            !isCurrentUser &&
            !(_currentUserIsAdmin && isAdmin);
        final canShowMenu = canAssignAdmin || canRemove;

        return Builder(
          builder: (context) => Container(
            color: AppColors.getSurfaceColor(context),
            child: _MemberRow(
              name: name,
              role: role,
              avatarUrl: avatarUrl,
              userId: userId,
              isCurrentUser: isCurrentUser,
              isOwner: _currentUserIsOwner || widget.isOwner,
              onTap: userId != null
                  ? () {
                      Navigator.of(context).push(
                        TransparentPageRoute(
                          builder: (_) => ProfileScreen(userId: userId),
                        ),
                      );
                    }
                  : null,
              onShowMenu: canShowMenu && userId != null
                  ? (menuKey) => _showMemberMenu(
                        context,
                        menuKey,
                        userId,
                        name,
                        isAdmin,
                        isCreator,
                      )
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
