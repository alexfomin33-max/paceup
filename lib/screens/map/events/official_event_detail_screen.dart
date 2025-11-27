// lib/screens/map/events/official_event_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/services/api_provider.dart';
import '../../../providers/services/auth_provider.dart';
import '../../../core/widgets/interactive_back_swipe.dart';
import '../../../core/widgets/transparent_route.dart';
import 'edit_official_event_screen.dart';

/// Детальная страница официального события (топ события)
class OfficialEventDetailScreen extends ConsumerStatefulWidget {
  final int eventId;

  const OfficialEventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<OfficialEventDetailScreen> createState() =>
      _OfficialEventDetailScreenState();
}

class _OfficialEventDetailScreenState
    extends ConsumerState<OfficialEventDetailScreen> {
  Map<String, dynamic>? _eventData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование
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

        // Проверяем статус закладки
        final isBookmarked = event['is_bookmarked'] as bool? ?? false;

        setState(() {
          _eventData = event;
          _canEdit = canEdit;
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
        builder: (_) => EditOfficialEventScreen(eventId: widget.eventId),
      ),
    );

    // Если событие было удалено, возвращаемся назад
    if (result == 'deleted') {
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final authService = ref.read(authServiceProvider);
    final userId = await authService.getUserId();
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: Пользователь не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTogglingBookmark = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _isTogglingBookmark = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Открытие ссылки на мероприятие (копирование в буфер обмена)
  Future<void> _openEventLink(String url) async {
    // Копируем ссылку в буфер обмена
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ссылка скопирована в буфер обмена'),
        backgroundColor: Colors.green,
      ),
    );
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
    final dateFormatted = _eventData!['date_formatted_short'] as String? ?? '';
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    final registrationLink = _eventData!['registration_link'] as String? ?? '';
    final participantsCount = _eventData!['participants_count'] as int? ?? 0;

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: SafeArea(
          top: false,
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ───────── Шапка без AppBar: SafeArea + кнопки у краёв + логотип по центру
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
                                    onTap: () =>
                                        Navigator.of(context).maybePop(),
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
                                              : null,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Название события выровнено по левому краю
                              Text(
                                name,
                                textAlign: TextAlign.left,
                                style: AppTextStyles.h17w6,
                              ),
                              const SizedBox(height: 10),

                              // Дата и адрес (вместо даты и времени)
                              _InfoRow(
                                icon: CupertinoIcons.calendar_today,
                                text: '$dateFormatted · $place',
                              ),

                              // Ссылка на мероприятие
                              if (registrationLink.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _openEventLink(registrationLink),
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
                                          registrationLink,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            color: AppColors.brandPrimary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Количество участников
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.sportscourt,
                                    size: 18,
                                    color: AppColors.brandPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$participantsCount ${_formatParticipants(participantsCount)}',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: AppColors.getTextPrimaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
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
                                        widgets.add(const SizedBox(width: 10));
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
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ───────── Вкладки: каждая — в своей половине, центрирование текста
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
              ),

              // ───────── Разделитель
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) => Divider(
                    height: 1,
                    color: AppColors.getBorderColor(context),
                  ),
                ),
              ),

              // ───────── Контент активной вкладки
              if (_tab == 0)
                // Вкладка "Описание" — фиксированный контент
                SliverFillRemaining(
                  hasScrollBody: false,
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: EventDescriptionContent(
                          description:
                              _eventData!['description'] as String? ?? '',
                        ),
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
        ),
      ),
    );
  }

  /// Форматирование слова "участник" в зависимости от количества
  String _formatParticipants(int count) {
    final lastDigit = count % 10;
    final lastTwoDigits = count % 100;

    if (lastTwoDigits >= 11 && lastTwoDigits <= 14) {
      return 'участников';
    }

    if (lastDigit == 1) {
      return 'участник';
    } else if (lastDigit >= 2 && lastDigit <= 4) {
      return 'участника';
    } else {
      return 'участников';
    }
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
          child: Icon(
            icon,
            size: 18,
            color: color ?? AppColors.getIconPrimaryColor(context),
          ),
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
      errorWidget: (context, imageUrl, error) => Builder(
        builder: (context) => Container(
          width: 100,
          height: 100,
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
                errorWidget: (context, imageUrl, error) => Builder(
                  builder: (context) => Container(
                    color: AppColors.getBorderColor(context),
                    child: Icon(
                      Icons.image,
                      size: 48,
                      color: AppColors.getIconSecondaryColor(context),
                    ),
                  ),
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
    final color = selected
        ? AppColors.brandPrimary
        : AppColors.getTextPrimaryColor(context);
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
      color: AppColors.getTextPrimaryColor(context),
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
                      errorWidget: (context, imageUrl, error) => Builder(
                        builder: (context) => Container(
                          color: AppColors.getBorderColor(context),
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: AppColors.getIconSecondaryColor(context),
                          ),
                        ),
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
                child: Builder(
                  builder: (context) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.getSurfaceColor(
                        context,
                      ).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Builder(
                      builder: (context) => Icon(
                        CupertinoIcons.xmark,
                        color: AppColors.getSurfaceColor(context),
                        size: 18,
                      ),
                    ),
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
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 1.35,
      color: AppColors.getTextPrimaryColor(context),
    );

    if (description.isEmpty) {
      return Align(
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
class _EventMembersSliver extends ConsumerStatefulWidget {
  final int eventId;
  const _EventMembersSliver({super.key, required this.eventId});

  @override
  ConsumerState<_EventMembersSliver> createState() =>
      _EventMembersSliverState();
}

class _EventMembersSliverState
    extends ConsumerState<_EventMembersSliver> {
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
      final api = ref.read(apiServiceProvider);
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
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    // Показываем ошибку если есть
    if (_error != null && _participants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) => SelectableText.rich(
                  TextSpan(
                    text: 'Ошибка загрузки: ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.getTextSecondaryColor(context),
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
          ),
        ),
      );
    }

    // Показываем пустое состояние
    if (_participants.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Участники отсутствуют',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Используем SliverList для участников (часть общего скролла)
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Индикатор загрузки в конце списка
        if (index >= _participants.length) {
          if (!_loading) return const SizedBox.shrink();
          return Builder(
            builder: (context) => Container(
              color: AppColors.getSurfaceColor(context),
              padding: const EdgeInsets.all(16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final p = _participants[index];
        if (p.isEmpty) return const SizedBox.shrink();

        final name = (p['name'] as String?)?.trim() ?? 'Пользователь';
        final avatarUrl = (p['avatar_url'] as String?)?.trim() ?? '';
        final isOrganizer = p['is_organizer'] as bool? ?? false;

        return Builder(
          builder: (context) => Container(
            color: AppColors.getSurfaceColor(context),
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
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.getBorderColor(context),
                  ),
              ],
            ),
          ),
        );
      }, childCount: _participants.length + (_loading ? 1 : 0)),
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
                  member.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.getTextPrimaryColor(context),
                  ),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.role!,
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
