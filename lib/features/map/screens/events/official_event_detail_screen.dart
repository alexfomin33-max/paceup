// lib/screens/map/events/official_event_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';
import '../../../../core/widgets/interactive_back_swipe.dart';
import '../../../../core/widgets/transparent_route.dart';
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
            // ── проверяем mounted внутри callback, так как виджет может быть размонтирован к моменту выполнения
            if (mounted) {
              _prefetchImages(context);
            }
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
        _error = ErrorHandler.format(e);
        _loading = false;
      });
    }
  }

  /// ──────────────────────── Префетч изображений ────────────────────────
  void _prefetchImages(BuildContext context) {
    if (_eventData == null) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Фоновая картинка (соотношение сторон 2.1:1)
    final backgroundUrl = _eventData!['background_url'] as String?;
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

    // Если событие было обновлено, перезагружаем данные и возвращаем сигнал на карту
    if (result == true) {
      await _loadEvent();
      if (!mounted) return;
      // ── возвращаем сигнал об обновлении, чтобы карта обновила маркеры
      Navigator.of(context).pop('updated');
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

  /// Открытие ссылки на мероприятие
  Future<void> _openEventLink(String url) async {
    // Убеждаемся, что URL имеет правильный формат
    Uri? uri;
    try {
      uri = Uri.parse(url);
      // Если URL не содержит схему, добавляем https://
      if (!uri.hasScheme) {
        uri = Uri.parse('https://$url');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Некорректная ссылка'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Пытаемся открыть ссылку напрямую (без проверки canLaunchUrl)
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось открыть ссылку'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _tab = 0; // 0 — Описание, 1 — Участники

  /// ──────────────────────── Форматирование даты с годом ────────────────────────
  /// Добавляет год к дате, если это не текущий год
  String _formatDateWithYear(String dateFormattedShort) {
    if (dateFormattedShort.isEmpty || _eventData == null) {
      return dateFormattedShort;
    }

    // Пытаемся получить полную дату из данных события
    dynamic eventDateRaw = _eventData!['event_date'];
    eventDateRaw ??= _eventData!['date'];

    if (eventDateRaw == null) {
      return dateFormattedShort;
    }

    // Парсим дату
    DateTime? eventDate;
    try {
      if (eventDateRaw is String) {
        // Пробуем разные форматы
        if (eventDateRaw.contains(' ')) {
          // Формат "YYYY-MM-DD HH:mm:ss"
          eventDate = DateTime.parse(eventDateRaw.split(' ')[0]);
        } else if (eventDateRaw.contains('.')) {
          // Формат "DD.MM.YYYY"
          final parts = eventDateRaw.split('.');
          if (parts.length == 3) {
            eventDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } else {
          // Формат "YYYY-MM-DD"
          eventDate = DateTime.parse(eventDateRaw);
        }
      }
    } catch (e) {
      // Если не удалось распарсить, возвращаем исходную строку
      return dateFormattedShort;
    }

    if (eventDate == null) {
      return dateFormattedShort;
    }

    // Сравниваем год с текущим
    final currentYear = DateTime.now().year;
    if (eventDate.year != currentYear) {
      // Добавляем год к дате
      return '$dateFormattedShort ${eventDate.year}';
    }

    return dateFormattedShort;
  }

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

    final backgroundUrl = _eventData!['background_url'] as String? ?? '';
    final name = _eventData!['name'] as String? ?? '';
    final dateFormattedShort =
        _eventData!['date_formatted_short'] as String? ?? '';
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];

    // ── Форматируем дату с добавлением года, если это не текущий год
    // ── Убираем запятую, если она есть (для официальных событий время не показываем)
    final dateFormattedRaw = _formatDateWithYear(dateFormattedShort);
    final dateFormatted = dateFormattedRaw.replaceAll(', ', ' ').replaceAll(',', '');

    // ── Извлекаем ссылку на регистрацию (поддерживаем оба варианта названия)
    dynamic linkRaw = _eventData!['registration_link'];
    if (linkRaw == null || (linkRaw is String && linkRaw.isEmpty)) {
      linkRaw = _eventData!['event_link'];
    }
    final registrationLink = (linkRaw?.toString().trim() ?? '').replaceAll(
      ' ',
      '',
    );

    // ── Извлекаем дистанции из данных события (массив в метрах)
    // Обрабатываем разные форматы: числа, строки, null
    final distancesRaw = _eventData!['distances'];
    final List<num> distances = [];

    if (distancesRaw != null) {
      if (distancesRaw is List) {
        for (final d in distancesRaw) {
          if (d == null) continue;
          num? value;
          if (d is num) {
            value = d;
          } else if (d is String) {
            final parsed = num.tryParse(d.trim());
            value = parsed;
          }
          if (value != null && value > 0) {
            distances.add(value);
          }
        }
      } else if (distancesRaw is num && distancesRaw > 0) {
        // Если дистанция одна и пришла как число
        distances.add(distancesRaw);
      }
    }

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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Cover изображение (если есть)
                            if (backgroundUrl.isNotEmpty)
                              _BackgroundImage(url: backgroundUrl)
                            else
                              Builder(
                                builder: (context) {
                                  final screenW = MediaQuery.of(
                                    context,
                                  ).size.width;
                                  final calculatedHeight =
                                      screenW /
                                      2.1; // Вычисляем высоту по соотношению 2.1:1
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
                                      onTap: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                    const Spacer(),
                                    // Показываем карандаш для создателя, закладку для остальных
                                    if (_canEdit)
                                      _CircleIconBtn(
                                        icon: CupertinoIcons.pencil,
                                        semantic: 'Редактировать',
                                        onTap: _openEditScreen,
                                      )
                                    else
                                      _CircleIconBtn(
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
                          ],
                        ),
                        // Остальная часть шапки
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Название события выровнено по левому краю
                              Builder(
                                builder: (context) => Text(
                                  name,
                                  textAlign: TextAlign.left,
                                  style: AppTextStyles.h17w6.copyWith(
                                    color: AppColors.getTextPrimaryColor(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ── Адрес
                              _InfoRow(
                                icon: CupertinoIcons.location,
                                text: place,
                              ),

                              // ── Дата
                              const SizedBox(height: 6),
                              _InfoRow(
                                icon: CupertinoIcons.calendar_today,
                                text: dateFormatted,
                              ),

                              // ── Ссылка на мероприятие (URL)
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
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

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
                          Builder(
                            builder: (context) => Container(
                              width: 0.5,
                              height: 24,
                              color: AppColors.getBorderColor(context),
                            ),
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
                          distances: distances,
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
}

/// ─── helpers

/// Полупрозрачная круглая кнопка-иконка
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final String? semantic;
  final VoidCallback? onTap;
  final Color? color; // Цвет иконки (для закладки может быть оранжевым)
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

    // В светлой теме иконки светлые (белые), в темной — как обычно
    // Если передан явный цвет (например, для закладки), используем его
    final brightness = Theme.of(context).brightness;
    final iconColor =
        color ??
        (brightness == Brightness.light
            ? Colors.white
            : AppColors.getIconPrimaryColor(context));

    // В темной теме увеличиваем непрозрачность кружочка
    final backgroundColor = brightness == Brightness.dark
        ? AppColors.scrim60
        : AppColors.scrim40;

    return Semantics(
      label: semantic,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
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

/// Фоновая картинка события (соотношение сторон 2.1:1)
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
  final List<num> distances;
  const EventDescriptionContent({
    super.key,
    required this.description,
    required this.distances,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      height: 1.35,
      color: AppColors.getTextPrimaryColor(context),
    );

    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Текст описания
          if (description.isEmpty)
            Text('Описание отсутствует', style: style)
          else
            Text(description, style: style, textAlign: TextAlign.start),

          // Дистанции после описания (если есть)
          if (distances.isNotEmpty) ...[
            if (description.isNotEmpty) const SizedBox(height: 12),
            // Заголовок "Дистанции"
            Text(
              'Дистанции',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            // Маркированный список дистанций
            ...distances.map((distance) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: style),
                    Expanded(
                      child: Text(
                        _formatDistance(distance),
                        style: style,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// ──────────────────────── Форматирование одной дистанции ────────────────────────
  /// Преобразует дистанцию в метрах в читаемую строку
  String _formatDistance(num distance) {
    final meters = distance.toDouble();
    if (meters >= 1000) {
      // Если >= 1000 м, показываем в километрах с одним знаком после запятой
      final km = meters / 1000;
      // Если целое число, показываем без десятичных
      if (km == km.roundToDouble()) {
        return '${km.toInt()} км';
      } else {
        return '${km.toStringAsFixed(1)} км';
      }
    } else {
      // Если < 1000 м, показываем в метрах
      return '${meters.toInt()} м';
    }
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

class _EventMembersSliverState extends ConsumerState<_EventMembersSliver> {
  final List<Map<String, dynamic>> _participants = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 1;
  static const int _limit = 25;
  final Map<int, bool> _togglingSubscriptions =
      {}; // Для отслеживания процесса подписки/отписки

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

  /// ──────────────────────── Подписка/отписка на пользователя ────────────────────────
  Future<void> _toggleSubscribe(
    int targetUserId,
    bool currentlySubscribed,
  ) async {
    // Проверяем, не идет ли уже процесс подписки/отписки для этого пользователя
    if (_togglingSubscriptions[targetUserId] == true) return;

    if (!mounted) return;
    setState(() {
      _togglingSubscriptions[targetUserId] = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final action = currentlySubscribed ? 'unsubscribe' : 'subscribe';

      final data = await api.post(
        '/toggle_subscribe.php',
        body: {'target_user_id': targetUserId.toString(), 'action': action},
      );

      if (!mounted) return;

      if (data['success'] == true) {
        final isSubscribed = data['is_subscribed'] as bool? ?? false;

        // Обновляем статус подписки в списке участников
        setState(() {
          final index = _participants.indexWhere(
            (p) => (p['user_id'] as int?) == targetUserId,
          );
          if (index != -1) {
            _participants[index]['is_subscribed'] = isSubscribed;
          }
          _togglingSubscriptions[targetUserId] = false;
        });
      } else {
        final errorMessage = data['message'] as String? ?? 'Ошибка подписки';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _togglingSubscriptions[targetUserId] = false;
        });
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
      setState(() {
        _togglingSubscriptions[targetUserId] = false;
      });
    }
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
          _error = ErrorHandler.format(e);
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
      return ErrorDisplaySliver(
        error: _error,
        onRetry: () => reloadParticipants(),
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
        final userId = p['user_id'] as int?;
        final isCurrentUser = p['is_current_user'] as bool? ?? false;
        final isSubscribed = p['is_subscribed'] as bool? ?? false;
        final isToggling =
            userId != null && (_togglingSubscriptions[userId] == true);

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
                  userId: userId,
                  isCurrentUser: isCurrentUser,
                  isSubscribed: isSubscribed,
                  isToggling: isToggling,
                  onToggleSubscribe: userId != null && !isCurrentUser
                      ? () => _toggleSubscribe(userId, isSubscribed)
                      : null,
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
  final int? userId;
  final bool isCurrentUser;
  final bool isSubscribed;
  final bool isToggling;
  final VoidCallback? onToggleSubscribe;
  const _MemberRow({
    required this.member,
    this.userId,
    this.isCurrentUser = false,
    this.isSubscribed = false,
    this.isToggling = false,
    this.onToggleSubscribe,
  });

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

          // Иконка подписки: не показываем для текущего пользователя и организатора
          if (!isCurrentUser && userId != null)
            IconButton(
              onPressed: isToggling ? null : onToggleSubscribe,
              splashRadius: 22,
              icon: isToggling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isSubscribed
                          ? CupertinoIcons.person_crop_circle_badge_minus
                          : member.roleIcon ??
                                CupertinoIcons.person_crop_circle_badge_plus,
                      size: 24,
                    ),
              style: IconButton.styleFrom(
                foregroundColor: isSubscribed
                    ? Colors.red
                    : AppColors.brandPrimary,
                disabledForegroundColor: AppColors.disabledText,
              ),
            )
          else if (member.roleIcon != null)
            IconButton(
              onPressed: null,
              splashRadius: 22,
              icon: Icon(member.roleIcon, size: 24),
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
