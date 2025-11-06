// lib/screens/map/clubs/club_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import '../../../widgets/interactive_back_swipe.dart';

/// Детальная страница клуба (на основе event_detail_screen.dart)
class ClubDetailScreen extends StatefulWidget {
  final int clubId;

  const ClubDetailScreen({super.key, required this.clubId});

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  Map<String, dynamic>? _clubData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  /// Загрузка данных клуба через API
  Future<void> _loadClub() async {
    try {
      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      final data = await api.get(
        '/get_clubs.php',
        queryParams: {'club_id': widget.clubId.toString()},
      );

      if (data['success'] == true && data['club'] != null) {
        final club = data['club'] as Map<String, dynamic>;

        // Проверяем права на редактирование: только создатель может редактировать
        final clubUserId = club['user_id'] as int?;
        final canEdit = userId != null && clubUserId == userId;

        setState(() {
          _clubData = club;
          _canEdit = canEdit;
          _loading = false;
        });

        // ───── После успешной загрузки — лёгкий префетч логотипа и фоновой картинки ─────
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _prefetchImages(context);
          });
        }
      } else {
        setState(() {
          _error = data['message'] as String? ?? 'Клуб не найден';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: ${e.toString()}';
        _loading = false;
      });
    }
  }

  /// ──────────────────────── Префетч изображений ────────────────────────
  void _prefetchImages(BuildContext context) {
    if (_clubData == null) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Логотип в шапке: 100×100
    final logoUrl = _clubData!['logo_url'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final w = (100 * dpr).round();
      final h = (100 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(logoUrl, maxWidth: w, maxHeight: h),
        context,
      );
    }

    // Фоновая картинка
    final backgroundUrl = _clubData!['background_url'] as String?;
    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      final screenW = MediaQuery.of(context).size.width;
      final targetW = (screenW * dpr).round();
      final targetH = (200 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(backgroundUrl, maxWidth: targetW, maxHeight: targetH),
        context,
      );
    }
  }

  int _tab = 0; // 0 — Описание, 1 — Участники

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _clubData == null) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error ?? 'Клуб не найден',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Назад'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final logoUrl = _clubData!['logo_url'] as String? ?? '';
    final name = _clubData!['name'] as String? ?? '';
    final founderName = _clubData!['founder_name'] as String? ?? '';
    final dateFormatted = _clubData!['date_formatted'] as String? ?? '';
    final city = _clubData!['city'] as String? ?? '';
    final backgroundUrl = _clubData!['background_url'] as String? ?? '';
    final members = _clubData!['members'] as List<dynamic>? ?? [];
    final membersCount = _clubData!['members_count'] as int? ?? 0;
    final isOpen = _clubData!['is_open'] as bool? ?? true;
    final activity = _clubData!['activity'] as String? ?? '';

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          bottom: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ───────── Шапка без AppBar: SafeArea + кнопки у краёв + логотип по центру
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 100,
                            child: Row(
                              children: [
                                _CircleIconBtn(
                                  icon: CupertinoIcons.back,
                                  semantic: 'Назад',
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                Expanded(
                                  child: Center(
                                    child: logoUrl.isNotEmpty
                                        ? ClipOval(
                                            child: _HeaderLogo(url: logoUrl),
                                          )
                                        : Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              color: AppColors.border,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.group,
                                              size: 48,
                                            ),
                                          ),
                                  ),
                                ),
                                _CircleIconBtn(
                                  icon: CupertinoIcons.pencil,
                                  semantic: 'Редактировать',
                                  onTap: _canEdit ? () {} : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Остальная часть шапки
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.h17w6,
                            ),
                            const SizedBox(height: 10),

                            _InfoRow(
                              icon: CupertinoIcons.person_crop_circle,
                              text: founderName,
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              icon: CupertinoIcons.calendar_today,
                              text: 'Основан: $dateFormatted',
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              icon: CupertinoIcons.location_solid,
                              text: city,
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              icon: CupertinoIcons.sportscourt,
                              text: activity,
                            ),

                            if (backgroundUrl.isNotEmpty) ...[
                              const SizedBox(height: 12),

                              // Фоновая картинка
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: _BackgroundImage(url: backgroundUrl),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Кнопки действий — secondary, радиус 4
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.brandPrimary,
                                      foregroundColor: AppColors.surface,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.xs,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      isOpen ? 'Вступить в клуб' : 'Подать заявку',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ───────── ЕДИНЫЙ нижний блок: вкладки + контент (растягивается до низа)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Вкладки: каждая — в своей половине, центрирование текста, больше высота
                      SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            Expanded(
                              child: _HalfTab(
                                text: 'Описание',
                                selected: _tab == 0,
                                onTap: () => setState(() => _tab = 0),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: AppColors.border,
                            ),
                            Expanded(
                              child: _HalfTab(
                                text: 'Участники ($membersCount)',
                                selected: _tab == 1,
                                onTap: () => setState(() => _tab = 1),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: AppColors.border),

                      // Контент активной вкладки — растягивается до низа
                      Expanded(
                        child: _tab == 0
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                child: ClubDescriptionContent(
                                  description:
                                      _clubData!['description'] as String? ?? '',
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(top: 0, bottom: 0),
                                child: ClubMembersContent(
                                  members: members,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── helpers

/// Полупрозрачная круглая кнопка-иконка
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final String? semantic;
  final VoidCallback? onTap;
  const _CircleIconBtn({required this.icon, this.onTap, this.semantic});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.scrim20,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.surface),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brandPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
          ),
        ),
      ],
    );
  }
}

/// Круглый логотип 100×100 с кэшем
class _HeaderLogo extends StatelessWidget {
  final String url;
  const _HeaderLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (100 * dpr).round();
    final h = (100 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      memCacheHeight: h,
      maxWidthDiskCache: w,
      maxHeightDiskCache: h,
      errorWidget: (_, __, ___) => Container(
        width: 100,
        height: 100,
        color: AppColors.border,
        child: const Icon(Icons.image, size: 48),
      ),
    );
  }
}

/// Фоновая картинка клуба
class _BackgroundImage extends StatelessWidget {
  final String url;
  const _BackgroundImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenW = MediaQuery.of(context).size.width;
    final targetW = (screenW * dpr).round();
    final targetH = (200 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: targetW,
      memCacheHeight: targetH,
      maxWidthDiskCache: targetW,
      maxHeightDiskCache: targetH,
      errorWidget: (_, __, ___) => Container(
        color: AppColors.border,
        child: const Icon(Icons.image, size: 48),
      ),
    );
  }
}

/// Аватар участника 40×40 с кэшем
class _Avatar40 extends StatelessWidget {
  final String url;
  const _Avatar40({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (40 * dpr).round();
    final h = (40 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      memCacheHeight: h,
      maxWidthDiskCache: w,
      maxHeightDiskCache: h,
      errorWidget: (_, __, ___) => Container(
        width: 40,
        height: 40,
        color: AppColors.border,
        child: const Icon(Icons.person, size: 24),
      ),
    );
  }
}

/// Текст вкладки, центрированный в своей половине.
class _HalfTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _HalfTab({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandPrimary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Контент описания клуба из API
class ClubDescriptionContent extends StatelessWidget {
  final String description;
  const ClubDescriptionContent({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Inter', fontSize: 14, height: 1.35);

    if (description.isEmpty) {
      return const Align(
        alignment: Alignment.topLeft,
        child: Text('Описание отсутствует', style: style),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Text(description, style: style, textAlign: TextAlign.start),
    );
  }
}

/// Контент участников клуба из API
class ClubMembersContent extends StatelessWidget {
  final List<dynamic> members;
  const ClubMembersContent({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Участники отсутствуют', style: TextStyle(fontSize: 14)),
      );
    }

    return Column(
      children: List.generate(members.length, (i) {
        final m = members[i] as Map<String, dynamic>;
        final name = m['name'] as String? ?? 'Пользователь';
        final avatarUrl = m['avatar_url'] as String? ?? '';
        final isCreator = m['is_creator'] as bool? ?? false;

        return Column(
          children: [
            _MemberRow(
              member: _Member(
                name,
                isCreator ? 'Основатель' : null,
                avatarUrl,
                roleIcon: isCreator
                    ? CupertinoIcons.person_crop_circle_fill_badge_checkmark
                    : null,
              ),
            ),
            if (i != members.length - 1)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          ],
        );
      }),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final _Member member;
  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ClipOval(
            child: member.avatar.isNotEmpty
                ? _Avatar40(url: member.avatar)
                : Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 24),
                  ),
          ),
          const SizedBox(width: 12),

          // имя + роль
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.role!,
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
            onPressed: (member.roleIcon != null) ? null : () {},
            splashRadius: 22,
            icon: Icon(
              member.roleIcon ?? CupertinoIcons.person_crop_circle_badge_plus,
              size: 24,
            ),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              disabledForegroundColor: AppColors.disabledText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Member {
  final String name;
  final String? role;
  final String avatar;
  final IconData? roleIcon;
  const _Member(this.name, this.role, this.avatar, {this.roleIcon});
}

