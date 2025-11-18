import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../service/api_service.dart';

/// ──────────────────────── Контент участников клуба из API с пагинацией ────────────────────────
class CoffeeRunVldMembersContent extends StatefulWidget {
  final int clubId;
  const CoffeeRunVldMembersContent({super.key, required this.clubId});

  @override
  State<CoffeeRunVldMembersContent> createState() =>
      _CoffeeRunVldMembersContentState();
}

class _CoffeeRunVldMembersContentState
    extends State<CoffeeRunVldMembersContent> {
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

    setState(() {
      _loading = true;
    });

    try {
      final api = ApiService();
      final data = await api.get(
        '/get_club_members.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

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
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Участники отсутствуют',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textSecondary,
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
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final m = _members[index];
        final name = m['name'] as String? ?? 'Пользователь';
        final avatarUrl = m['avatar_url'] as String? ?? '';
        final role = m['role'] as String?;
        final rank = index + 1; // Номер позиции (начиная с 1)

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      rank.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? _Avatar36(url: avatarUrl)
                        : Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, size: 20),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (role != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    // Для пользователей с ролью (владелец) иконка неактивна
                    // Для обычных пользователей — клик добавит в друзья (реализуем позже)
                    onPressed: role != null
                        ? null
                        : () {
                            // TODO: Реализовать добавление в друзья
                          },
                    splashRadius: 22,
                    icon: Icon(
                      role != null
                          ? CupertinoIcons
                                .person_crop_circle_fill_badge_checkmark
                          : CupertinoIcons.person_crop_circle_badge_plus,
                      size: 24,
                      color: role != null
                          ? AppColors.iconTertiary
                          : AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (index < _members.length - 1)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          ],
        );
      },
    );
  }
}

/// ──────────────────────── Аватар 36×36 с кэшем ────────────────────────
class _Avatar36 extends StatelessWidget {
  final String url;
  const _Avatar36({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (36 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 36,
      height: 36,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      maxWidthDiskCache: w,
      errorWidget: (_, __, ___) => Container(
        width: 36,
        height: 36,
        color: AppColors.border,
        child: const Icon(Icons.person, size: 20),
      ),
    );
  }
}
