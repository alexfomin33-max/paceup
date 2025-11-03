// lib/screens/map/events/event_detail_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../service/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  /// Загрузка данных события через API
  Future<void> _loadEvent() async {
    try {
      final api = ApiService();
      final data = await api.get(
        '/get_events.php',
        queryParams: {'event_id': widget.eventId.toString()},
      );

      if (data['success'] == true && data['event'] != null) {
        setState(() {
          _eventData = data['event'] as Map<String, dynamic>;
          _loading = false;
        });
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _eventData == null) {
      return Scaffold(
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
      );
    }

    final logoUrl = _eventData!['logo_url'] as String? ?? '';
    final name = _eventData!['name'] as String? ?? '';
    final organizerName = _eventData!['organizer_name'] as String? ?? '';
    final dateFormatted = _eventData!['date_formatted_short'] as String? ?? '';
    final time = _eventData!['event_time'] as String? ?? '';
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    final participants = _eventData!['participants'] as List<dynamic>? ?? [];
    final participantsCount = _eventData!['participants_count'] as int? ?? 0;

    return Scaffold(
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
                                  child: logoUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            logoUrl,
                                            width: 92,
                                            height: 92,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                  width: 92,
                                                  height: 92,
                                                  color: AppColors.border,
                                                  child: const Icon(
                                                    Icons.image,
                                                    size: 48,
                                                  ),
                                                ),
                                          ),
                                        )
                                      : Container(
                                          width: 92,
                                          height: 92,
                                          decoration: BoxDecoration(
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
                                onTap: () {},
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

                            // Фотографии: квадрат, радиус 4, кликабельные — галерея
                            Row(
                              children: List.generate(
                                photos.length > 3 ? 3 : photos.length,
                                (index) {
                                  final photoUrl = photos[index] as String;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: index < 2 ? 10 : 0,
                                      ),
                                      child: _SquarePhoto(
                                        photoUrl,
                                        onTap: () => _openGallery(index),
                                      ),
                                    ),
                                  );
                                },
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
                              const SizedBox(width: 12),
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ───────── ЕДИНЫЙ нижний блок: вкладки + контент (без анимации)
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

                    // Контент активной вкладки — без AnimatedSwitcher
                    if (_tab == 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: EventDescriptionContent(
                          description:
                              _eventData!['description'] as String? ?? '',
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 0),
                        child: EventMembersContent(participants: participants),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
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

class _SquarePhoto extends StatelessWidget {
  final String url;
  final VoidCallback? onTap;
  const _SquarePhoto(this.url, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: InkWell(
          onTap: onTap,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.border,
              child: const Icon(Icons.image, size: 48),
            ),
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
                    child: Image.network(
                      widget.images[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
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
      return const Text('Описание отсутствует', style: style);
    }

    return Text(description, style: style);
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
                ? Image.network(
                    member.avatar,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      color: AppColors.border,
                      child: const Icon(Icons.person, size: 24),
                    ),
                  )
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
