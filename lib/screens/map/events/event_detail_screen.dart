// lib/screens/map/events/event_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/interactive_back_swipe.dart';

/// Экран подробной информации о событии
class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const EventDetailScreen({
    super.key,
    required this.eventData,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  int _tab = 0; // 0 — Описание, 1 — Участники

  /// Форматирование даты события
  String _formatEventDate(String? eventDate, String? eventTime) {
    if (eventDate == null) return 'Дата не указана';
    try {
      final date = DateTime.parse(eventDate);
      final dateStr = DateFormat('d MMMM', 'ru').format(date);
      if (eventTime != null && eventTime.isNotEmpty) {
        final time = eventTime.split(':');
        if (time.length >= 2) {
          return '$dateStr, ${time[0]}:${time[1]}';
        }
      }
      return dateStr;
    } catch (e) {
      return eventDate;
    }
  }

  void _openGallery(List<String> images, int startIndex) {
    showDialog(
      context: context,
      barrierColor: AppColors.scrim40,
      builder: (_) => _GalleryViewer(
        images: images,
        startIndex: startIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.eventData;
    final logoUrl = event['logo_url'] as String?;
    final name = event['name'] as String? ?? 'Событие';
    final clubName = event['club_name'] as String? ?? '';
    final place = event['place'] as String? ?? 'Место не указано';
    final eventDate = event['event_date'] as String?;
    final eventTime = event['event_time'] as String?;
    final description = event['description'] as String? ?? '';
    final participantsCount = event['participants_count'] as int? ?? 0;
    final photosUrls = (event['photos_urls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          bottom: true,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ───────── Шапка: кнопка назад + логотип + кнопка редактирования
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
                            height: 92,
                            child: Row(
                              children: [
                                _CircleIconBtn(
                                  icon: CupertinoIcons.back,
                                  semantic: 'Назад',
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                Expanded(
                                  child: Center(
                                    child: ClipOval(
                                      child: logoUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: logoUrl,
                                              width: 92,
                                              height: 92,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                width: 92,
                                                height: 92,
                                                color: AppColors.border,
                                                child: const Icon(
                                                  Icons.event,
                                                  size: 40,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                width: 92,
                                                height: 92,
                                                color: AppColors.border,
                                                child: const Icon(
                                                  Icons.event,
                                                  size: 40,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 92,
                                              height: 92,
                                              color: AppColors.border,
                                              child: const Icon(
                                                Icons.event,
                                                size: 40,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                _CircleIconBtn(
                                  icon: CupertinoIcons.pencil,
                                  semantic: 'Редактировать',
                                  onTap: () {
                                    // TODO: Открыть экран редактирования события
                                  },
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

                            if (clubName.isNotEmpty)
                              _InfoRow(
                                icon: CupertinoIcons.person_crop_circle,
                                text: clubName,
                              ),
                            if (clubName.isNotEmpty) const SizedBox(height: 6),
                            _InfoRow(
                              icon: CupertinoIcons.calendar_today,
                              text: _formatEventDate(eventDate, eventTime),
                            ),
                            const SizedBox(height: 6),
                            _InfoRow(
                              icon: CupertinoIcons.location_solid,
                              text: place,
                            ),

                            if (photosUrls.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              // Фотографии: квадрат, радиус 4, кликабельные — галерея
                              Row(
                                children: [
                                  for (int i = 0;
                                      i < photosUrls.length && i < 3;
                                      i++) ...[
                                    if (i > 0) const SizedBox(width: 10),
                                    _SquarePhoto(
                                      photosUrls[i],
                                      onTap: () => _openGallery(photosUrls, i),
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Кнопки действий
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: Присоединиться к событию
                                    },
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
                                    child: const Text(
                                      'Присоединиться',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                if (clubName.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // TODO: Вступить в клуб
                                      },
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
                                      child: const Text(
                                        'Вступить в клуб',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

              // ───────── Вкладки: Описание и Участники
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
                      // Вкладки
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

                      // Контент активной вкладки
                      if (_tab == 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: _DescriptionContent(
                            description: description,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 0),
                          child: _ParticipantsContent(
                            eventId: event['id'] as int? ?? 0,
                            participantsCount: participantsCount,
                          ),
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

// ──────────────────────────────────────────────────────────────────────────────
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ──────────────────────────────────────────────────────────────────────────────

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

/// Строка информации с иконкой
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

/// Квадратная фотография
class _SquarePhoto extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  const _SquarePhoto(this.url, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: InkWell(
            onTap: onTap,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.border,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.border,
                child: const Icon(
                  Icons.image,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Вкладка (половина ширины)
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

/// Контент вкладки "Описание"
class _DescriptionContent extends StatelessWidget {
  final String description;

  const _DescriptionContent({required this.description});

  @override
  Widget build(BuildContext context) {
    return Text(
      description.isEmpty ? 'Описание отсутствует' : description,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

/// Контент вкладки "Участники"
class _ParticipantsContent extends StatelessWidget {
  final int eventId;
  final int participantsCount;

  const _ParticipantsContent({
    required this.eventId,
    required this.participantsCount,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Загрузить список участников через API
    // Пока показываем заглушку с количеством участников
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Text(
          'Участников: $participantsCount\n\nСписок участников скоро будет доступен',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Полноэкранный просмотрщик галереи
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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.error,
                        color: AppColors.surface,
                        size: 48,
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

