// lib/features/map/screens/clubs/club_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/expandable_text.dart';
import 'tabs/club_photo_content.dart';
import 'coffeerun_vld/tabs/members_content.dart';
import 'coffeerun_vld/tabs/stats_content.dart';
import 'edit_club_screen.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../profile/providers/user_clubs_provider.dart';
import '../../providers/search/clubs_search_provider.dart';

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
  int?
  _updatedMembersCount; // Обновленное количество участников (если было изменено)

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  /// Загрузка данных клуба через API
  Future<void> _loadClub() async {
    try {
      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
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
        _error = ErrorHandler.formatWithContext(e, context: 'загрузке клуба');
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

    // Фоновая картинка (соотношение сторон 2.1:1)
    final backgroundUrl = _clubData!['background_url'] as String?;
    if (backgroundUrl != null && backgroundUrl.isNotEmpty) {
      final screenW = MediaQuery.of(context).size.width;
      final calculatedHeight =
          screenW / 2.1; // Вычисляем высоту по соотношению 2.1:1
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

  int _tab = 0; // 0 — Фото, 1 — Участники, 2 — Статистика
  final GlobalKey<CoffeeRunVldMembersContentState> _membersContentKey =
      GlobalKey<CoffeeRunVldMembersContentState>();

  /// ──────────────────────── Вступление в клуб ────────────────────────
  Future<void> _joinClub() async {
    if (_isJoining || _clubData == null) return;

    try {
      setState(() => _isJoining = true);

      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
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
        final membersCount = data['members_count'] as int?;

        setState(() {
          _isMember = isMember;
          _isRequest = isRequest;
          _isJoining = false;
        });

        // Обновляем данные клуба (чтобы обновилось количество участников)
        await _loadClub();

        // ── Сохраняем информацию об обновлении для передачи при возврате
        // Это будет использовано при закрытии экрана для обновления списка клубов
        // Используем значение из ответа API или из обновленного _clubData
        if (membersCount != null) {
          _updatedMembersCount = membersCount;
        } else if (_clubData != null) {
          _updatedMembersCount = _clubData!['members_count'] as int? ?? 0;
        }

        // Инвалидируем provider клубов пользователя для обновления списка в clubs_tab.dart
        // userId гарантированно не null после проверки выше
        ref.invalidate(userClubsProvider(userId));

        // Инвалидируем провайдер рекомендованных клубов, чтобы обновить список
        // в экране поиска клубов (clubs_content.dart)
        ref.invalidate(recommendedClubsProvider);

        // ── Обновляем список участников на вкладке "Участники", если она открыта
        if (_tab == 1 && _membersContentKey.currentState != null) {
          _membersContentKey.currentState!.refreshMembers();
        }
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
            content: Text(ErrorHandler.format(e)),
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

      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
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
        final membersCount = data['members_count'] as int?;

        setState(() {
          _isMember = false;
          _isRequest = false;
          _isJoining = false;
        });

        // Обновляем данные клуба (чтобы обновилось количество участников)
        await _loadClub();

        // ── Сохраняем информацию об обновлении для передачи при возврате
        // Это будет использовано при закрытии экрана для обновления списка клубов
        // Используем значение из ответа API или из обновленного _clubData
        if (membersCount != null) {
          _updatedMembersCount = membersCount;
        } else if (_clubData != null) {
          _updatedMembersCount = _clubData!['members_count'] as int? ?? 0;
        }

        // Инвалидируем provider клубов пользователя для обновления списка в clubs_tab.dart
        // userId гарантированно не null после проверки выше
        ref.invalidate(userClubsProvider(userId));

        // Инвалидируем провайдер рекомендованных клубов, чтобы обновить список
        // в экране поиска клубов (clubs_content.dart)
        ref.invalidate(recommendedClubsProvider);

        // ── Обновляем список участников на вкладке "Участники", если она открыта
        if (_tab == 1 && _membersContentKey.currentState != null) {
          _membersContentKey.currentState!.refreshMembers();
        }
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
            content: Text(ErrorHandler.format(e)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      setState(() => _isJoining = false);
    }
  }

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
    final link = _clubData!['link'] as String? ?? '';

    final description = _clubData!['description'] as String? ?? '';

    return PopScope(
      canPop: _updatedMembersCount == null,
      onPopInvokedWithResult: (didPop, result) {
        // ── Если количество участников было обновлено и pop еще не произошел, возвращаем результат
        if (!didPop && _updatedMembersCount != null && mounted) {
          Navigator.of(context).pop({
            'members_count_updated': true,
            'members_count': _updatedMembersCount,
            'club_id': widget.clubId,
          });
        }
      },
      child: InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          body: SafeArea(
            top: false,
            bottom: true,
            child: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ───────── Cover + overlay-кнопки + логотип
                    SliverToBoxAdapter(
                      child: Builder(
                        builder: (context) {
                          final screenW = MediaQuery.of(context).size.width;
                          final calculatedHeight =
                              screenW /
                              2.1; // Вычисляем высоту по соотношению 2.1:1
                          final containerHeight =
                              calculatedHeight + 68; // Высота фона + 60px
                          return Container(
                            height: containerHeight,
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(
                                context,
                              ), // Цвет фона для нижней части с логотипом
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(AppRadius.xl),
                                bottomRight: Radius.circular(AppRadius.xl),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(AppRadius.xl),
                                bottomRight: Radius.circular(AppRadius.xl),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Cover изображение (если есть)
                                  if (backgroundUrl.isNotEmpty)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: calculatedHeight,
                                      child: _BackgroundImage(
                                        url: backgroundUrl,
                                      ),
                                    )
                                  else
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      height: calculatedHeight,
                                      child: Container(
                                        width: double.infinity,
                                        height: calculatedHeight,
                                        color: AppColors.getBorderColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  // ── Логотип внизу контейнера
                                  Positioned(
                                    left: 12,
                                    bottom: 8, // В самом низу контейнера
                                    child: Builder(
                                      builder: (context) => Container(
                                        width:
                                            92, // 90 + 1*2 (логотип + обводка с двух сторон)
                                        height: 92,
                                        decoration: BoxDecoration(
                                          color: AppColors.getSurfaceColor(
                                            context,
                                          ),
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
                                                      color:
                                                          AppColors.getBorderColor(
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
                                  // ── Название клуба и информация справа от логотипа
                                  Positioned(
                                    left:
                                        116, // 12 (отступ слева) + 92 (ширина логотипа) + 12 (отступ)
                                    right: 12,
                                    top:
                                        calculatedHeight +
                                        12, // Чуть ниже фоновой картинки
                                    child: Builder(
                                      builder: (context) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Название клуба
                                          Text(
                                            name,
                                            style: AppTextStyles.h17w6.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  AppColors.getTextPrimaryColor(
                                                    context,
                                                  ),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          // Участники и тип сообщества
                                          Row(
                                            children: [
                                              Text(
                                                'Участников: $membersCount',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.getTextPrimaryColor(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '·',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.getTextPrimaryColor(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isOpen
                                                    ? 'Открытое'
                                                    : 'Закрытое',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.getTextPrimaryColor(
                                                        context,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Промежуточный блок: ссылка на сайт клуба (если есть)
                    if (link.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.getBorderColor(context),
                                width: 1,
                              ),
                            ),
                            child: _LinkRow(link: link),
                          ),
                        ),
                      ),

                    if (link.isNotEmpty)
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Промежуточный блок: информация
                    if (description.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.getBorderColor(context),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Информация',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.getTextSecondaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) => ExpandableText(
                                    text: description,
                                    textStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      height: 1.35,
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (description.isNotEmpty)
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Промежуточный блок: дата основания и кнопка
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            // Блок с датой основания
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceColor(context),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Дата основания',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.getTextSecondaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateFormatted.isNotEmpty
                                          ? dateFormatted
                                          : '—',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Кнопка действия
                            Builder(
                              builder: (context) => Material(
                                color: _isMember
                                    ? AppColors.red
                                    : AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xxl,
                                ),
                                elevation: 0,
                                child: InkWell(
                                  onTap: _isJoining
                                      ? null
                                      : _isMember
                                      ? _leaveClub
                                      : _joinClub,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xxl,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _isMember ? 30 : 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isMember
                                          ? AppColors.red
                                          : AppColors.brandPrimary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xxl,
                                      ),
                                    ),
                                    child: _isJoining
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.surface,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            _isMember
                                                ? 'Выйти'
                                                : _isRequest
                                                ? 'Заявка подана'
                                                : isOpen
                                                ? 'Вступить'
                                                : 'Подать заявку',
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.surface,
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

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Промежуточный блок: количество участников и тип сообщества
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            // Блок с количеством участников
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceColor(context),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Участников',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.getTextSecondaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      membersCount.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Блок с типом сообщества
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceColor(context),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                  border: Border.all(
                                    color: AppColors.getBorderColor(context),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Тип сообщества',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.getTextSecondaryColor(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isOpen ? 'Открытое' : 'Закрытое',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
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

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Пилюля с табами
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Builder(
                          builder: (context) => Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(
                                AppRadius.xxl,
                              ),
                              border: Border.all(
                                color: AppColors.getBorderColor(context),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _PillTabBtn(
                                    text: 'Фото',
                                    selected: _tab == 0,
                                    onTap: () => setState(() => _tab = 0),
                                  ),
                                ),
                                Expanded(
                                  child: _PillTabBtn(
                                    text: 'Участники',
                                    selected: _tab == 1,
                                    onTap: () => setState(() => _tab = 1),
                                  ),
                                ),
                                Expanded(
                                  child: _PillTabBtn(
                                    text: 'Статистика',
                                    selected: _tab == 2,
                                    onTap: () => setState(() => _tab = 2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    // ───────── Контент табов
                    if (_tab == 0)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                              child: ClubPhotoContent(
                                clubId: widget.clubId,
                                canEdit: _canEdit,
                                clubData: _clubData,
                                onPhotosUpdated: _loadClub,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_tab == 1)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                              child: CoffeeRunVldMembersContent(
                                key: _membersContentKey,
                                clubId: widget.clubId,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        sliver: SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color: AppColors.getBorderColor(context),
                                  width: 1,
                                ),
                              ),
                              child: CoffeeRunVldStatsContent(
                                clubId: widget.clubId,
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),

                // ───────── Плавающие круглые иконки (назад + редактирование)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CircleIconBtn(
                            icon: CupertinoIcons.back,
                            semantic: 'Назад',
                            onTap: () {
                              // ── Если количество участников было обновлено, возвращаем результат
                              if (_updatedMembersCount != null) {
                                Navigator.of(context).pop({
                                  'members_count_updated': true,
                                  'members_count': _updatedMembersCount,
                                  'club_id': widget.clubId,
                                });
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
                          ),
                          if (_canEdit)
                            _CircleIconBtn(
                              icon: CupertinoIcons.pencil,
                              semantic: 'Редактировать',
                              onTap: () async {
                                // Переходим на экран редактирования клуба
                                final result = await Navigator.of(context).push(
                                  TransparentPageRoute(
                                    builder: (_) =>
                                        EditClubScreen(clubId: widget.clubId),
                                  ),
                                );
                                // Если редактирование прошло успешно, обновляем данные
                                if (!context.mounted) return;
                                if (result == true) {
                                  _loadClub();
                                }
                                // Если клуб был удалён, возвращаемся назад с результатом
                                // (приоритет удаления выше, чем обновление участников)
                                if (result == 'deleted') {
                                  Navigator.of(context).pop('deleted');
                                }
                              },
                            )
                          else
                            const SizedBox(width: 38, height: 38),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    // Цвет иконки теперь привязан к первичному тексту
    final iconColor = AppColors.getTextPrimaryColor(context);

    // Цвет фона совпадает с background и имеет лёгкую прозрачность
    final backgroundColor = AppColors.getBackgroundColor(
      context,
    ).withValues(alpha: 0.7);

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

/// Строка со ссылкой на сайт клуба (кликабельная)
class _LinkRow extends StatelessWidget {
  final String link;
  const _LinkRow({required this.link});

  Future<void> _openLink(BuildContext context) async {
    try {
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть ссылку'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при открытии ссылки: ${ErrorHandler.format(e)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openLink(context),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.globe,
            size: 18,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              link,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.brandPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

/// Фоновая картинка клуба (соотношение сторон 2.1:1)
class _BackgroundImage extends StatelessWidget {
  final String url;
  const _BackgroundImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final calculatedHeight =
        screenW / 2.1; // Вычисляем высоту по соотношению 2.1:1
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

/// Кнопка вкладки в пилюле
class _PillTabBtn extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _PillTabBtn({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selected
                  ? AppColors.getSurfaceColor(context)
                  : AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
