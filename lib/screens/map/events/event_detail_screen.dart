// lib/screens/map/events/event_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../service/api_service.dart';
import '../../../service/auth_service.dart';
import '../../../widgets/transparent_route.dart';
import '../../../widgets/interactive_back_swipe.dart';
import 'edit_event_screen.dart';

/// Детальная страница события (на основе coffeerun_screen.dart)
class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _eventData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование
  bool _isParticipant = false; // Является ли текущий пользователь участником
  bool _isTogglingParticipation = false; // Флаг процесса присоединения/выхода
  bool _isBookmarked = false; // Находится ли событие в закладках
  bool _isTogglingBookmark =
      false; // Флаг процесса добавления/удаления закладки
  final ScrollController _scrollController =
      ScrollController(); // Контроллер для отслеживания прокрутки
  final GlobalKey<_EventMembersSliverState> _membersSliverKey =
      GlobalKey(); // Ключ для доступа к состоянию участников

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Обработка прокрутки для пагинации участников
  void _onScroll() {
    if (_tab == 1 && _scrollController.hasClients) {
      final position = _scrollController.position;
      // Подгружаем новые участники при достижении 80% прокрутки
      if (position.pixels >= position.maxScrollExtent * 0.8) {
        _membersSliverKey.currentState?.checkAndLoadMore();
      }
    }
  }

  /// Загрузка данных события через API
  Future<void> _loadEvent() async {
    try {
      final api = ApiService();
      final authService = AuthService();
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

        // Проверяем, является ли текущий пользователь участником
        final participants = event['participants'] as List<dynamic>? ?? [];
        bool isParticipant = false;
        if (userId != null) {
          for (final p in participants) {
            final pMap = p as Map<String, dynamic>;
            final pUserId = pMap['user_id'] as int?;
            if (pUserId == userId) {
              isParticipant = true;
              break;
            }
          }
        }

        // Проверяем статус закладки
        final isBookmarked = event['is_bookmarked'] as bool? ?? false;

        setState(() {
          _eventData = event;
          _canEdit = canEdit;
          _isParticipant = isParticipant;
          _isBookmarked = isBookmarked;
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
        _error = 'Ошибка загрузки: ${e.toString()}';
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

    final result = await Navigator.of(context).push<dynamic>(
      TransparentPageRoute(
        builder: (_) => EditEventScreen(eventId: widget.eventId),
      ),
    );

    // Если событие было удалено, возвращаемся назад
    if (result == 'deleted') {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    // Если событие было обновлено, перезагружаем данные
    if (result == true) {
      await _loadEvent();
    }
  }

  /// ──────────────────────── Добавление/удаление из закладок ────────────────────────
  Future<void> _toggleBookmark() async {
    if (_isTogglingBookmark || _eventData == null) return;

    // Проверяем, что userId доступен
    final authService = AuthService();
    final userId = await authService.getUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isTogglingBookmark = true;
    });

    try {
      final api = ApiService();
      final data = await api.post(
        '/toggle_event_bookmark.php',
        body: {'event_id': widget.eventId},
      );

      if (data['success'] == true) {
        final isBookmarked = data['is_bookmarked'] as bool? ?? false;

        // Обновляем состояние
        setState(() {
          _isBookmarked = isBookmarked;
          _isTogglingBookmark = false;
        });

        // Обновляем данные события
        if (_eventData != null) {
          setState(() {
            _eventData = {..._eventData!, 'is_bookmarked': isBookmarked};
          });
        }
      } else {
        final errorMessage = data['message'] as String? ?? 'Неизвестная ошибка';
        setState(() {
          _isTogglingBookmark = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTogglingBookmark = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ──────────────────────── Присоединение/выход из события ────────────────────────
  Future<void> _toggleParticipation() async {
    if (_isTogglingParticipation || _eventData == null) return;

    // Проверяем, что userId доступен
    final authService = AuthService();
    final userId = await authService.getUserId();
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: Пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isTogglingParticipation = true;
    });

    try {
      final api = ApiService();
      final action = _isParticipant ? 'leave' : 'join';

      final data = await api.post(
        '/join_event.php',
        body: {'event_id': widget.eventId, 'action': action},
      );

      if (data['success'] == true) {
        final isParticipant = data['is_participant'] as bool? ?? false;
        final participantsCount = data['participants_count'] as int? ?? 0;

        // Обновляем состояние
        setState(() {
          _isParticipant = isParticipant;
          _isTogglingParticipation = false;
        });

        // Обновляем счетчик участников в данных события
        if (_eventData != null) {
          setState(() {
            _eventData = {
              ..._eventData!,
              'participants_count': participantsCount,
            };
          });
        }

        // Если открыта вкладка участников, обновляем список
        // (при присоединении пользователь появится, при выходе - исчезнет)
        if (_tab == 1) {
          // Небольшая задержка для завершения обновления состояния
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _membersSliverKey.currentState?.reloadParticipants();
            }
          });
        }
      } else {
        final errorMessage = data['message'] as String? ?? 'Неизвестная ошибка';
        setState(() {
          _isTogglingParticipation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTogglingParticipation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      return const InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _eventData == null) {
      return InteractiveBackSwipe(
        child: Scaffold(
          backgroundColor: AppColors.background,
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
    final dateFormatted = _eventData!['date_formatted_short'] as String? ?? '';
    final time = _eventData!['event_time'] as String? ?? '';
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // ───────── Скроллируемый контент
              CustomScrollView(
                controller: _scrollController,
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
                                    // Показываем карандаш для создателя, закладку для остальных
                                    _canEdit
                                        ? _CircleIconBtn(
                                            icon: CupertinoIcons.pencil,
                                            semantic: 'Редактировать',
                                            onTap: _openEditScreen,
                                          )
                                        : _CircleIconBtn(
                                            icon: CupertinoIcons.star_fill,
                                            semantic: _isBookmarked
                                                ? 'Удалить из закладок'
                                                : 'Добавить в закладки',
                                            onTap: _isTogglingBookmark
                                                ? null
                                                : _toggleBookmark,
                                            color: _isBookmarked
                                                ? AppColors.orange
                                                : AppColors.surface,
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
                                  text: organizerName,
                                ),
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: CupertinoIcons.calendar_today,
                                  text: '$dateFormatted, $time',
                                ),
                                const SizedBox(height: 6),
                                _InfoRow(
                                  icon: CupertinoIcons.location_solid,
                                  text: place,
                                ),

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

                  // ───────── Вкладки: каждая — в своей половине, центрирование текста
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          top: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      child: SizedBox(
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
                                text:
                                    'Участники (${_eventData?['participants_count'] ?? 0})',
                                selected: _tab == 1,
                                onTap: () => setState(() => _tab = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ───────── Разделитель
                  const SliverToBoxAdapter(
                    child: Divider(height: 1, color: AppColors.border),
                  ),

                  // ───────── Контент активной вкладки
                  if (_tab == 0)
                    // Вкладка "Описание" — фиксированный контент
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: EventDescriptionContent(
                            description:
                                _eventData!['description'] as String? ?? '',
                          ),
                        ),
                      ),
                    )
                  else
                    // Вкладка "Участники" — скроллируемый список
                    _EventMembersSliver(
                      key: _membersSliverKey,
                      eventId: widget.eventId,
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
                      color: _isParticipant
                          ? AppColors.red
                          : AppColors.brandPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      elevation: 0,
                      child: InkWell(
                        onTap: _isTogglingParticipation
                            ? null
                            : _toggleParticipation,
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _isParticipant
                                ? AppColors.red
                                : AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowMedium,
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: _isTogglingParticipation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.surface,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isParticipant ? 'Выйти' : 'Присоединиться',
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
  final Color? color; // Цвет иконки (по умолчанию AppColors.surface)
  const _CircleIconBtn({
    required this.icon,
    this.onTap,
    this.semantic,
    this.color,
  });

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
          child: Icon(icon, size: 18, color: color ?? AppColors.surface),
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
      errorWidget: (_, __, ___) => Container(
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
      errorWidget: (_, __, ___) => Container(
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
                errorWidget: (_, __, ___) => Container(
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
                      errorWidget: (_, __, ___) => Container(
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

/// Sliver для участников события с пагинацией (используется в CustomScrollView)
class _EventMembersSliver extends StatefulWidget {
  final int eventId;
  const _EventMembersSliver({super.key, required this.eventId});

  @override
  State<_EventMembersSliver> createState() => _EventMembersSliverState();
}

class _EventMembersSliverState extends State<_EventMembersSliver> {
  final List<Map<String, dynamic>> _participants = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 1;
  static const int _limit = 25;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  /// Проверка и загрузка новых участников (вызывается из родительского ScrollController)
  void checkAndLoadMore() {
    if (!_loading && _hasMore && _error == null) {
      _loadParticipants();
    }
  }

  /// Перезагрузка списка участников с первой страницы
  /// Используется после присоединения/выхода из события
  void reloadParticipants() {
    setState(() {
      _participants.clear();
      _currentPage = 1;
      _hasMore = true;
      _error = null;
    });
    _loadParticipants();
  }

  /// Загрузка участников с пагинацией
  Future<void> _loadParticipants() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final data = await api.get(
        '/get_event_participants.php',
        queryParams: {
          'event_id': widget.eventId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (data['success'] == true) {
        final participants = data['participants'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        setState(() {
          _participants.addAll(
            participants
                .where((p) => p != null && p is Map<String, dynamic>)
                .map((p) => p as Map<String, dynamic>),
          );
          _hasMore = hasMore;
          _currentPage++;
          _loading = false;
        });
      } else {
        final errorMessage =
            data['message'] as String? ?? 'Ошибка загрузки участников';
        setState(() {
          _loading = false;
          if (_participants.isEmpty) {
            _error = errorMessage;
          }
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        if (_participants.isEmpty) {
          _error = 'Ошибка: ${e.toString()}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки при первой загрузке
    if (_loading && _participants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Показываем ошибку если есть
    if (_error != null && _participants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText.rich(
              TextSpan(
                text: 'Ошибка загрузки: ',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: _error,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Показываем пустое состояние
    if (_participants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Участники отсутствуют',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );
    }

    // Используем SliverList для участников (часть общего скролла)
    // Каждый элемент обёрнут в Container с фоном surface
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Индикатор загрузки в конце списка
        if (index >= _participants.length) {
          if (!_loading) return const SizedBox.shrink();
          return Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final p = _participants[index];
        if (p.isEmpty) return const SizedBox.shrink();

        final name = (p['name'] as String?)?.trim() ?? 'Пользователь';
        final avatarUrl = (p['avatar_url'] as String?)?.trim() ?? '';
        final isOrganizer = p['is_organizer'] as bool? ?? false;

        return Container(
          color: AppColors.surface,
          child: Column(
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
              if (index < _participants.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.border,
                ),
            ],
          ),
        );
      }, childCount: _participants.length + (_loading ? 1 : 0)),
    );
  }
}

/// Контент участников события из API с пагинацией (для использования вне CustomScrollView)
class EventMembersContent extends StatefulWidget {
  final int eventId;
  const EventMembersContent({super.key, required this.eventId});

  @override
  State<EventMembersContent> createState() => _EventMembersContentState();
}

class _EventMembersContentState extends State<EventMembersContent> {
  final List<Map<String, dynamic>> _participants = [];
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 25;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Обработка прокрутки для подгрузки новых участников
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loading &&
        _hasMore) {
      _loadParticipants();
    }
  }

  /// Загрузка участников с пагинацией
  Future<void> _loadParticipants() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      final api = ApiService();
      final data = await api.get(
        '/get_event_participants.php',
        queryParams: {
          'event_id': widget.eventId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (data['success'] == true) {
        final participants = data['participants'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        setState(() {
          _participants.addAll(
            participants.map((p) => p as Map<String, dynamic>),
          );
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
    if (_participants.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Участники отсутствуют', style: TextStyle(fontSize: 14)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: _participants.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _participants.length) {
          // Индикатор загрузки в конце списка
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final p = _participants[index];
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
            if (index < _participants.length - 1)
              const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          ],
        );
      },
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
