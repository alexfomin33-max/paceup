// lib/screens/map/clubs/club_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import '../../../widgets/interactive_back_swipe.dart';
import 'coffeerun_vld/tabs/photo_content.dart';
import 'coffeerun_vld/tabs/members_content.dart';
import 'coffeerun_vld/tabs/stats_content.dart';
import 'coffeerun_vld/tabs/glory_content.dart';
import 'edit_club_screen.dart';
import '../../../widgets/transparent_route.dart';

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

    // Логотип в шапке: 64×64
    final logoUrl = _clubData!['logo_url'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final w = (64 * dpr).round();
      final h = (64 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(logoUrl, maxWidth: w, maxHeight: h),
        context,
      );
    }

    // Фоновая картинка (cover 160px)
    final backgroundUrl = _clubData!['background_url'] as String?;
    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      final screenW = MediaQuery.of(context).size.width;
      final targetW = (screenW * dpr).round();
      final targetH = (160 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(
          backgroundUrl,
          maxWidth: targetW,
          maxHeight: targetH,
        ),
        context,
      );
    }
  }

  int _tab = 0; // 0 — Фото, 1 — Участники, 2 — Статистика, 3 — Зал славы

  Widget _vDivider() =>
      Container(width: 1, height: 24, color: AppColors.border);

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
    final dateFormatted = _clubData!['date_formatted'] as String? ?? '';
    final backgroundUrl = _clubData!['background_url'] as String? ?? '';
    final membersCount = _clubData!['members_count'] as int? ?? 0;
    final isOpen = _clubData!['is_open'] as bool? ?? true;

    final description = _clubData!['description'] as String? ?? '';

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          bottom: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ───────── Cover + overlay-кнопки
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Cover изображение (если есть)
                    if (backgroundUrl.isNotEmpty)
                      _BackgroundImage(url: backgroundUrl)
                    else
                      Container(
                        width: double.infinity,
                        height: 160,
                        color: AppColors.border,
                      ),
                    // Верхние кнопки
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            _CircleIconBtn(
                              icon: CupertinoIcons.back,
                              semantic: 'Назад',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            if (_canEdit)
                              _CircleIconBtn(
                                icon: CupertinoIcons.pencil,
                                semantic: 'Редактировать',
                                onTap: () async {
                                  // Переходим на экран редактирования клуба
                                  final result = await Navigator.of(context)
                                      .push(
                                        TransparentPageRoute(
                                          builder: (_) => EditClubScreen(
                                            clubId: widget.clubId,
                                          ),
                                        ),
                                      );
                                  // Если редактирование прошло успешно, обновляем данные
                                  if (result == true && mounted) {
                                    _loadClub();
                                  }
                                  // Если клуб был удалён, возвращаемся назад
                                  if (result == 'deleted' && mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ───────── «Шапка» карточки клуба
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Лого + имя
                      Row(
                        children: [
                          ClipOval(
                            child: logoUrl.isNotEmpty
                                ? _HeaderLogo(url: logoUrl)
                                : Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      color: AppColors.border,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.group, size: 32),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name, style: AppTextStyles.h17w6),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Описание
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      if (description.isNotEmpty) const SizedBox(height: 10),

                      // Инфо-блок
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.disabled,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            // Статус открытости клуба
                            _InfoRow(
                              icon: isOpen
                                  ? CupertinoIcons.lock_open
                                  : CupertinoIcons.lock_fill,
                              text: isOpen
                                  ? 'Открытое беговое сообщество'
                                  : 'Закрытое беговое сообщество',
                            ),
                            const SizedBox(height: 6),
                            if (dateFormatted.isNotEmpty) ...[
                              _InfoRow(
                                icon: CupertinoIcons.calendar_today,
                                text: 'Основан: $dateFormatted',
                              ),
                              const SizedBox(height: 6),
                            ],
                            // Количество участников
                            _InfoRow(
                              icon: CupertinoIcons.person_2_fill,
                              text: 'Участников: $membersCount',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Кнопка действия
                      Align(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brandPrimary,
                            foregroundColor: AppColors.surface,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.xxl,
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
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ───────── Табы + контент
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                      bottom: BorderSide(color: AppColors.border, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            _TabBtn(
                              text: 'Фото',
                              selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0),
                            ),
                            _vDivider(),
                            _TabBtn(
                              text: 'Участники',
                              selected: _tab == 1,
                              onTap: () => setState(() => _tab = 1),
                            ),
                            _vDivider(),
                            _TabBtn(
                              text: 'Статистика',
                              selected: _tab == 2,
                              onTap: () => setState(() => _tab = 2),
                            ),
                            _vDivider(),
                            _TabBtn(
                              text: 'Зал славы',
                              selected: _tab == 3,
                              onTap: () => setState(() => _tab = 3),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),

                      if (_tab == 0)
                        const Padding(
                          padding: EdgeInsets.all(2),
                          child: CoffeeRunVldPhotoContent(),
                        )
                      else if (_tab == 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 0, bottom: 0),
                          child: CoffeeRunVldMembersContent(),
                        )
                      else if (_tab == 2)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: CoffeeRunVldStatsContent(),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: CoffeeRunVldGloryContent(),
                        ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
  final VoidCallback onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.semantic,
  });

  @override
  Widget build(BuildContext context) {
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
        Icon(icon, size: 14, color: AppColors.brandPrimary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Круглый логотип 64×64 с кэшем
class _HeaderLogo extends StatelessWidget {
  final String url;
  const _HeaderLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (64 * dpr).round();
    final h = (64 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 64,
      height: 64,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      memCacheHeight: h,
      maxWidthDiskCache: w,
      maxHeightDiskCache: h,
      errorWidget: (_, __, ___) => Container(
        width: 64,
        height: 64,
        color: AppColors.border,
        child: const Icon(Icons.image, size: 32),
      ),
    );
  }
}

/// Фоновая картинка клуба (cover 160px высота)
class _BackgroundImage extends StatelessWidget {
  final String url;
  const _BackgroundImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenW = MediaQuery.of(context).size.width;
    final targetW = (screenW * dpr).round();
    final targetH = (160 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: 160,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: targetW,
      memCacheHeight: targetH,
      maxWidthDiskCache: targetW,
      maxHeightDiskCache: targetH,
      errorWidget: (_, __, ___) => Container(
        width: double.infinity,
        height: 160,
        color: AppColors.border,
        child: const Icon(Icons.image, size: 48),
      ),
    );
  }
}

/// Кнопка вкладки
class _TabBtn extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TabBtn({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandPrimary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        // одинаковый отступ от текста до вертикального разделителя
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ),
    );
  }
}
