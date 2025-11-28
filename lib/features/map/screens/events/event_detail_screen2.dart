// lib/screens/map/events/event_detail_screen2.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import 'edit_event_screen.dart';

/// Детальная страница события (на основе coffeerun_screen.dart)
class EventDetailScreen2 extends ConsumerStatefulWidget {
  final int eventId;

  const EventDetailScreen2({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen2> createState() =>
      _EventDetailScreen2State();
}

class _EventDetailScreen2State extends ConsumerState<EventDetailScreen2> {
  Map<String, dynamic>? _eventData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование
  String? _currentUserAvatar; // Аватар текущего пользователя из профиля

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  /// Загрузка данных события через API
  Future<void> _loadEvent() async {
    try {
      final api = ref.read(apiServiceProvider);
      final authService = ref.read(authServiceProvider);
      final userId = await authService.getUserId();

      final data = await api.get(
        '/get_events.php',
        queryParams: {'event_id': widget.eventId.toString()},
      );

      if (data['success'] == true && data['event'] != null) {
        final event = data['event'] as Map<String, dynamic>;

        // Проверяем права на редактирование: только создатель может редактировать
        final eventUserId = event['user_id'] as int?;
        final canEdit = userId != null && eventUserId == userId;

        // ─── Загружаем аватар текущего пользователя из профиля (если это организатор)
        String? currentUserAvatar;
        if (userId != null && eventUserId == userId) {
          try {
            final profileData = await api.post(
              '/user_profile_header.php',
              body: {'user_id': userId.toString()},
            );
            final profile =
                profileData['profile'] ?? profileData['data'] ?? profileData;
            if (profile is Map) {
              currentUserAvatar = profile['avatar'] as String?;
            }
          } catch (e) {
            // Игнорируем ошибки загрузки аватара
          }
        }

        setState(() {
          _eventData = event;
          _canEdit = canEdit;
          _currentUserAvatar = currentUserAvatar;
          _loading = false;
        });

        // ───── После успешной загрузки — лёгкий префетч логотипа и фото ─────
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _prefetchImages(context);
          });
        }
      } else {
        setState(() {
          _error = data['message'] as String? ?? 'Событие не найдено';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ErrorHandler.formatWithContext(e, context: 'загрузке события');
        _loading = false;
      });
    }
  }

  /// ──────────────────────── Префетч изображений ────────────────────────
  void _prefetchImages(BuildContext context) {
    if (_eventData == null) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Логотип в шапке: 92×92
    final logoUrl = _eventData!['logo_url'] as String?;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final w = (100 * dpr).round();
      final h = (100 * dpr).round();
      precacheImage(
        CachedNetworkImageProvider(logoUrl, maxWidth: w, maxHeight: h),
        context,
      );
    }

    // Первые 6 фото для сетки превью (3 столбца с отступами 12/10)
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    if (photos.isEmpty) return;
    final screenW = MediaQuery.of(context).size.width;
    final cell = ((screenW - 12 * 2 - 10 * 2) / 3).clamp(60.0, 400.0);
    final cw = (cell * dpr).round();
    final ch = cw; // квадрат
    final limit = photos.length < 6 ? photos.length : 6;
    for (var i = 0; i < limit; i++) {
      final url = photos[i] as String?;
      if (url == null || url.isEmpty) continue;
      precacheImage(
        CachedNetworkImageProvider(url, maxWidth: cw, maxHeight: ch),
        context,
      );
    }
  }

  /// Открытие экрана редактирования
  Future<void> _openEditScreen() async {
    if (!_canEdit) return;

    final result = await Navigator.of(context).push<bool>(
      TransparentPageRoute(
        builder: (_) => EditEventScreen(eventId: widget.eventId),
      ),
    );

    // Если событие было обновлено, перезагружаем данные
    if (result == true) {
      await _loadEvent();
    }
  }

  int _tab = 0; // 0 — Описание, 1 — Участники

  void _openGallery(int startIndex) {
    if (_eventData == null) return;
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    if (photos.isEmpty) return;

    showDialog(
      context: context,
      barrierColor: AppColors.scrim40,
      builder: (_) =>
          _GalleryViewer(images: photos.cast<String>(), startIndex: startIndex),
    );
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

    if (_error != null || _eventData == null) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.getBackgroundColor(context),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error ?? 'Событие не найдено',
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

    final logoUrl = _eventData!['logo_url'] as String? ?? '';
    final name = _eventData!['name'] as String? ?? '';
    final organizerName = _eventData!['organizer_name'] as String? ?? '';
    final organizerAvatarUrl =
        _eventData!['organizer_avatar_url'] as String? ?? '';
    // Используем аватар из профиля, если аватар организатора отсутствует
    final finalOrganizerAvatar = organizerAvatarUrl.isNotEmpty
        ? organizerAvatarUrl
        : (_currentUserAvatar?.isNotEmpty ?? false)
        ? _currentUserAvatar!
        : '';
    final dateFormatted = _eventData!['date_formatted_short'] as String? ?? '';
    final time = _eventData!['event_time'] as String? ?? '';
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    final participants = _eventData!['participants'] as List<dynamic>? ?? [];
    final participantsCount = _eventData!['participants_count'] as int? ?? 0;

    // ─── Извлекаем данные для метрик (опциональные поля из API)
    final distanceMeters = _eventData!['distance_meters'] as num?;
    final durationSeconds = _eventData!['duration_seconds'] as num?;

    // ─── Форматирование метрик
    String formatDistance(double? meters) {
      if (meters == null || meters <= 0) return '5 - 7 км';
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(2)} км';
    }

    // ─── Форматирование сложности
    String formatDifficulty(double? meters, int? seconds) {
      if (meters == null || meters <= 0 || seconds == null || seconds <= 0) {
        return 'Лёгкая';
      }
      // Если данные есть, можно добавить логику определения сложности
      // Пока возвращаем "Лёгкая" по умолчанию
      return 'Лёгкая';
    }

    // ─── Подготовка метрик с цветными тинтами
    final metrics = <_EventMetric>[
      _EventMetric(
        label: 'Адрес',
        value: place.isNotEmpty ? place : '—',
        tint: CupertinoColors.systemTeal,
      ),
      _EventMetric(
        label: 'Дата',
        value: dateFormatted.isNotEmpty ? dateFormatted : '—',
        tint: CupertinoColors.systemIndigo,
      ),
      _EventMetric(
        label: 'Время',
        value: time.isNotEmpty ? time : '—',
        tint: CupertinoColors.systemPurple,
      ),
      _EventMetric(
        label: 'Дистанция',
        value: formatDistance(distanceMeters?.toDouble()),
        tint: CupertinoColors.activeBlue,
      ),
      _EventMetric(
        label: 'Сложность',
        value: formatDifficulty(
          distanceMeters?.toDouble(),
          durationSeconds?.toInt(),
        ),
        tint: CupertinoColors.systemGreen,
      ),
    ];

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // ───────── Скроллируемый контент
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ───────── Шапка без AppBar: SafeArea + кнопки у краёв + логотип по центру
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 255, 255, 255),
                        border: Border(
                          bottom: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: SizedBox(
                                height: 100,
                                child: Row(
                                  children: [
                                    _CircleIconBtn(
                                      icon: CupertinoIcons.back,
                                      semantic: 'Назад',
                                      onTap: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: logoUrl.isNotEmpty
                                            ? ClipOval(
                                                child: _HeaderLogo(
                                                  url: logoUrl,
                                                ),
                                              )
                                            : Container(
                                                width: 100,
                                                height: 100,
                                                decoration: const BoxDecoration(
                                                  color: AppColors.border,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.event,
                                                  size: 48,
                                                ),
                                              ),
                                      ),
                                    ),
                                    _CircleIconBtn(
                                      icon: CupertinoIcons.pencil,
                                      semantic: 'Редактировать',
                                      onTap: _canEdit ? _openEditScreen : null,
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

                                // ─── Организатор с аватаркой 40×40
                                Row(
                                  children: [
                                    ClipOval(
                                      child: Builder(
                                        builder: (context) {
                                          if (finalOrganizerAvatar.isEmpty) {
                                            return Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                color: AppColors.border,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.person,
                                                size: 24,
                                              ),
                                            );
                                          }
                                          final dpr = MediaQuery.of(
                                            context,
                                          ).devicePixelRatio;
                                          final cacheWidth = (40 * dpr).round();
                                          return CachedNetworkImage(
                                            imageUrl: finalOrganizerAvatar,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            fadeInDuration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            memCacheWidth: cacheWidth,
                                            errorWidget:
                                                (context, imageUrl, error) =>
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      color: AppColors.border,
                                                      child: const Icon(
                                                        Icons.person,
                                                        size: 20,
                                                      ),
                                                    ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Организатор',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            organizerName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // ─── Цветные метрики (как в training_day_screen)
                                const SizedBox(height: 12),
                                _EventMetricBlock(metrics: metrics),

                                if (photos.isNotEmpty) ...[
                                  const SizedBox(height: 12),

                                  // Фотографии: всегда 3 ячейки для одинакового размера
                                  Row(
                                    children: () {
                                      final widgets = <Widget>[];
                                      for (var index = 0; index < 3; index++) {
                                        final hasPhoto = index < photos.length;
                                        final photoUrl = hasPhoto
                                            ? photos[index] as String
                                            : '';

                                        widgets.add(
                                          Expanded(
                                            child: hasPhoto
                                                ? _SquarePhoto(
                                                    photoUrl,
                                                    onTap: () =>
                                                        _openGallery(index),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        );

                                        if (index < 2) {
                                          widgets.add(
                                            const SizedBox(width: 10),
                                          );
                                        }
                                      }
                                      return widgets;
                                    }(),
                                  ),
                                ],
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
                                    text: 'Участники ($participantsCount)',
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
                                    child: EventDescriptionContent(
                                      description:
                                          _eventData!['description']
                                              as String? ??
                                          '',
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: 0,
                                      bottom: 0,
                                    ),
                                    child: EventMembersContent(
                                      participants: participants,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ───────── Плавающая кнопка поверх контента
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Material(
                      color: AppColors.brandPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      elevation: 0,
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowMedium,
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Присоединиться',
                            style: TextStyle(
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

/// Круглый логотип 92×92 с кэшем
class _HeaderLogo extends StatelessWidget {
  final String url;
  const _HeaderLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = (100 * dpr).round();
    return CachedNetworkImage(
      imageUrl: url,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      maxWidthDiskCache: w,
      errorWidget: (context, imageUrl, error) => Container(
        width: 100,
        height: 100,
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
    return CachedNetworkImage(
      imageUrl: url,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth: w,
      maxWidthDiskCache: w,
      errorWidget: (context, imageUrl, error) => Container(
        width: 40,
        height: 40,
        color: AppColors.border,
        child: const Icon(Icons.person, size: 24),
      ),
    );
  }
}

class _SquarePhoto extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  const _SquarePhoto(this.url, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              final target = (side * dpr).round();
              return CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                memCacheWidth: target,
                maxWidthDiskCache: target,
                errorWidget: (context, imageUrl, error) => Container(
                  color: AppColors.border,
                  child: const Icon(Icons.image, size: 48),
                ),
              );
            },
          ),
        ),
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

/// Полноэкранный просмотрщик: пейджер + зум
class _GalleryViewer extends StatefulWidget {
  final List<String> images;
  final int startIndex;
  const _GalleryViewer({required this.images, required this.startIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.startIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.textPrimary,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              itemBuilder: (_, i) {
                return Center(
                  child: InteractiveViewer(
                    maxScale: 4,
                    minScale: 1,
                    child: CachedNetworkImage(
                      imageUrl: widget.images[i],
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 120),
                      errorWidget: (context, imageUrl, error) => Container(
                        color: AppColors.border,
                        child: const Icon(Icons.image, size: 48),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.surface,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Контент описания события из API
class EventDescriptionContent extends StatelessWidget {
  final String description;
  const EventDescriptionContent({super.key, required this.description});

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

/// Контент участников события из API
class EventMembersContent extends StatelessWidget {
  final List<dynamic> participants;
  const EventMembersContent({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Участники отсутствуют', style: TextStyle(fontSize: 14)),
      );
    }

    return Column(
      children: List.generate(participants.length, (i) {
        final p = participants[i] as Map<String, dynamic>;
        final name = p['name'] as String? ?? 'Пользователь';
        final avatarUrl = p['avatar_url'] as String? ?? '';
        final isOrganizer = p['is_organizer'] as bool? ?? false;

        return Column(
          children: [
            _MemberRow(
              member: _Member(
                name,
                isOrganizer ? 'Организатор' : null,
                avatarUrl,
                roleIcon: isOrganizer
                    ? CupertinoIcons.person_crop_circle_fill_badge_checkmark
                    : null,
              ),
            ),
            if (i != participants.length - 1)
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

/// ─── Структура метрики события
class _EventMetric {
  final String label;
  final String value;
  final Color tint;
  const _EventMetric({
    required this.label,
    required this.value,
    required this.tint,
  });
}

/// ─── Сетка метрик события (аналогично _MetricBlock из training_day_screen)
class _EventMetricBlock extends StatelessWidget {
  const _EventMetricBlock({required this.metrics});
  final List<_EventMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final itemWidth = width >= 420
        ? (width - 12 * 2 - 8 * 2) / 3
        : (width >= 360 ? (width - 12 * 2 - 8) / 2 : width - 12 * 2);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics.asMap().entries.map((entry) {
        final index = entry.key;
        final m = entry.value;
        // Первое поле (Адрес) занимает ширину двух полей
        final isFirst = index == 0;
        final fieldWidth = isFirst ? (itemWidth * 2 + 8) : itemWidth;
        final bg = m.tint.withValues(alpha: 0.06);
        final br = m.tint.withValues(alpha: 0.22);
        return SizedBox(
          width: fieldWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: br, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: AppTextStyles.h12w4Ter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  m.value,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: isFirst ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
