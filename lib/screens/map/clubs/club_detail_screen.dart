// lib/screens/map/clubs/club_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/interactive_back_swipe.dart';
import 'coffeerun_vld/tabs/photo_content.dart';
import 'coffeerun_vld/tabs/members_content.dart';
import 'coffeerun_vld/tabs/stats_content.dart';
import 'coffeerun_vld/tabs/glory_content.dart';
import 'edit_club_screen.dart';
import '../../../core/widgets/transparent_route.dart';
import '../../../providers/profile/user_clubs_provider.dart';

/// Детальная страница клуба (на основе event_detail_screen.dart)
class ClubDetailScreen extends ConsumerStatefulWidget {
  final int clubId;

  const ClubDetailScreen({super.key, required this.clubId});

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  Map<String, dynamic>? _clubData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование
  bool _isMember = false; // Является ли пользователь участником
  bool _isRequest = false; // Подана ли заявка (для закрытых клубов)
  bool _isJoining = false; // Идёт ли процесс вступления

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

        // Проверяем, является ли пользователь участником клуба
        bool isMember = false;
        if (userId != null) {
          final members = club['members'] as List<dynamic>? ?? [];
          isMember = members.any((m) => m['user_id'] == userId);
        }

        setState(() {
          _clubData = club;
          _canEdit = canEdit;
          _isMember = isMember;
          _isRequest = false; // Сбрасываем статус заявки при загрузке
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

    // Логотип в шапке: 90×90
    final logoUrl = _clubData!['logo_url'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final w = (90 * dpr).round();
      final h = (90 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(logoUrl, maxWidth: w, maxHeight: h),
        context,
      );
    }

    // Фоновая картинка (соотношение сторон 2.3:1)
    final backgroundUrl = _clubData!['background_url'] as String?;
    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      final screenW = MediaQuery.of(context).size.width;
      final calculatedHeight =
          screenW / 2.3; // Вычисляем высоту по соотношению 2.3:1
      final targetW = (screenW * dpr).round();
      final targetH = (calculatedHeight * dpr).round();
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

  /// ──────────────────────── Вступление в клуб ────────────────────────
  Future<void> _joinClub() async {
    if (_isJoining || _clubData == null) return;

    try {
      setState(() => _isJoining = true);

      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Необходимо войти в систему'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isJoining = false);
        return;
      }

      final data = await api.post(
        '/join_club.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && mounted) {
        final isMember = data['is_member'] as bool? ?? false;
        final isRequest = data['is_request'] as bool? ?? false;

        setState(() {
          _isMember = isMember;
          _isRequest = isRequest;
          _isJoining = false;
        });

        // Обновляем данные клуба (чтобы обновилось количество участников)
        _loadClub();

        // Инвалидируем provider клубов пользователя для обновления списка в clubs_tab.dart
        // userId гарантированно не null после проверки выше
        ref.invalidate(userClubsProvider(userId));
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Ошибка вступления в клуб';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isJoining = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() => _isJoining = false);
    }
  }

  /// ──────────────────────── Выход из клуба ────────────────────────
  Future<void> _leaveClub() async {
    if (_isJoining || _clubData == null) return;

    try {
      setState(() => _isJoining = true);

      final api = ApiService();
      final authService = AuthService();
      final userId = await authService.getUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Необходимо войти в систему'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isJoining = false);
        return;
      }

      final data = await api.post(
        '/leave_club.php',
        body: {
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (data['success'] == true && mounted) {
        setState(() {
          _isMember = false;
          _isRequest = false;
          _isJoining = false;
        });

        // Обновляем данные клуба (чтобы обновилось количество участников)
        _loadClub();

        // Инвалидируем provider клубов пользователя для обновления списка в clubs_tab.dart
        // userId гарантированно не null после проверки выше
        ref.invalidate(userClubsProvider(userId));
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Ошибка выхода из клуба';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isJoining = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() => _isJoining = false);
    }
  }

  Widget _vDivider() => Builder(
    builder: (context) => Container(
      width: 1,
      height: 24,
      color: AppColors.getBorderColor(context),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _clubData == null) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) => Text(
                      _error ?? 'Клуб не найден',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.getTextPrimaryColor(context),
                      ),
                    ),
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
        backgroundColor: AppColors.getBackgroundColor(context),
        body: SafeArea(
          top: false,
          bottom: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ───────── Cover + overlay-кнопки + логотип
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) => Container(
                    color: AppColors.getSurfaceColor(
                      context,
                    ), // Цвет полоски для нижней половины логотипа
                    padding: const EdgeInsets.only(
                      bottom: 46,
                    ), // Место для нижней половины логотипа с обводкой
                    child: Stack(
                      clipBehavior: Clip
                          .none, // Разрешаем отображение элементов за пределами Stack
                      children: [
                        // Cover изображение (если есть)
                        if (backgroundUrl.isNotEmpty)
                          _BackgroundImage(url: backgroundUrl)
                        else
                          Builder(
                            builder: (context) {
                              final screenW = MediaQuery.of(context).size.width;
                              final calculatedHeight =
                                  screenW /
                                  2.3; // Вычисляем высоту по соотношению 2.3:1
                              return Container(
                                width: double.infinity,
                                height: calculatedHeight,
                                color: AppColors.getBorderColor(context),
                              );
                            },
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
                                      if (!context.mounted) return;
                                      if (result == true) {
                                        _loadClub();
                                      }
                                      // Если клуб был удалён, возвращаемся назад с результатом
                                      if (result == 'deleted') {
                                        Navigator.of(context).pop('deleted');
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Логотип наполовину на фоне (позиционирован внизу фона)
                        Positioned(
                          left: 12,
                          bottom:
                              -46, // Половина логотипа с обводкой (92/2 = 46) выходит за границу фона
                          child: Builder(
                            builder: (context) => Container(
                              width:
                                  92, // 90 + 1*2 (логотип + обводка с двух сторон)
                              height: 92,
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceColor(context),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(
                                1,
                              ), // Толщина обводки
                              child: ClipOval(
                                child: logoUrl.isNotEmpty
                                    ? _HeaderLogo(url: logoUrl)
                                    : Builder(
                                        builder: (context) => Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: AppColors.getBorderColor(
                                              context,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.group,
                                            size: 12,
                                            color:
                                                AppColors.getIconSecondaryColor(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ───────── «Шапка» карточки клуба
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      10, // Небольшой отступ от нижней половины логотипа (которая уже в полоске выше)
                      12,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Имя клуба (логотип теперь в Stack выше)
                        Text(
                          name,
                          style: AppTextStyles.h17w6.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Описание
                        if (description.isNotEmpty)
                          Builder(
                            builder: (context) => Text(
                              description,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.getTextSecondaryColor(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (description.isNotEmpty) const SizedBox(height: 12),

                        // Инфо-блок
                        Column(
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
                        const SizedBox(height: 12),

                        // Кнопка действия
                        Align(
                          alignment: Alignment.center,
                          child: Builder(
                            builder: (context) => ElevatedButton(
                              onPressed: _isJoining
                                  ? null
                                  : _isMember
                                  ? _leaveClub
                                  : _joinClub,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isMember
                                    ? AppColors.getBackgroundColor(context)
                                    : AppColors.brandPrimary,
                                foregroundColor: _isMember
                                    ? AppColors.getTextSecondaryColor(context)
                                    : AppColors.getSurfaceColor(context),
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
                              child: _isJoining
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.getSurfaceColor(
                                                context,
                                              ),
                                            ),
                                      ),
                                    )
                                  : Builder(
                                      builder: (context) => Text(
                                        _isMember
                                            ? 'Выйти из клуба'
                                            : _isRequest
                                            ? 'Заявка подана'
                                            : isOpen
                                            ? 'Вступить в клуб'
                                            : 'Подать заявку',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: _isMember
                                              ? AppColors.getTextSecondaryColor(
                                                  context,
                                                )
                                              : AppColors.getSurfaceColor(
                                                  context,
                                                ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ───────── Табы + контент
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(context),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color: AppColors.getBorderColor(context),
                          width: 1,
                        ),
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
                        Builder(
                          builder: (context) => Divider(
                            height: 1,
                            color: AppColors.getBorderColor(context),
                          ),
                        ),

                        if (_tab == 0)
                          const Padding(
                            padding: EdgeInsets.all(2),
                            child: CoffeeRunVldPhotoContent(),
                          )
                        else if (_tab == 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 0, bottom: 0),
                            child: CoffeeRunVldMembersContent(
                              clubId: widget.clubId,
                            ),
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
    // В светлой теме иконки светлые (белые), в темной — как обычно
    final brightness = Theme.of(context).brightness;
    final iconColor = brightness == Brightness.light
        ? Colors.white
        : AppColors.getIconPrimaryColor(context);

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.scrim40,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: iconColor),
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
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Круглый логотип 90×90 с кэшем
class _HeaderLogo extends StatelessWidget {
  final String url;
  const _HeaderLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (90 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      maxWidthDiskCache: w,
      errorWidget: (context, imageUrl, error) => Builder(
        builder: (context) => Container(
          width: 90,
          height: 90,
          color: AppColors.getBorderColor(context),
          child: Icon(
            Icons.image,
            size: 32,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

/// Фоновая картинка клуба (соотношение сторон 2.3:1)
class _BackgroundImage extends StatelessWidget {
  final String url;
  const _BackgroundImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final calculatedHeight =
        screenW / 2.3; // Вычисляем высоту по соотношению 2.3:1
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final targetW = (screenW * dpr).round();
    final targetH = (calculatedHeight * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: calculatedHeight,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: targetW,
      memCacheHeight: targetH,
      maxWidthDiskCache: targetW,
      maxHeightDiskCache: targetH,
      errorWidget: (context, imageUrl, error) => Builder(
        builder: (context) => Container(
          width: double.infinity,
          height: calculatedHeight,
          color: AppColors.getBorderColor(context),
          child: Icon(
            Icons.image,
            size: 48,
            color: AppColors.getIconSecondaryColor(context),
          ),
        ),
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
    final color = selected
        ? AppColors.brandPrimary
        : AppColors.getTextPrimaryColor(context);
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
