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
  ConsumerState<EventDetailScreen2> createState() => _EventDetailScreen2State();
}

class _EventDetailScreen2State extends ConsumerState<EventDetailScreen2> {
  Map<String, dynamic>? _eventData;
  bool _loading = true;
  String? _error;
  bool _canEdit = false; // Права на редактирование
  String? _currentUserAvatar; // Аватар текущего пользователя из профиля
  bool _isParticipant = false; // Является ли текущий пользователь участником
  bool _isTogglingParticipation = false; // Флаг процесса присоединения/выхода

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
          _isParticipant = isParticipant;
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

  /// ──────────────────────── Присоединение/выход из события ────────────────────────
  Future<void> _toggleParticipation() async {
    if (_isTogglingParticipation || _eventData == null) return;

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
      _isTogglingParticipation = true;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final action = _isParticipant ? 'leave' : 'join';

      final data = await api.post(
        '/join_event.php',
        body: {'event_id': widget.eventId, 'action': action},
      );

      if (data['success'] == true) {
        final isParticipant = data['is_participant'] as bool? ?? false;

        // Обновляем состояние
        setState(() {
          _isParticipant = isParticipant;
          _isTogglingParticipation = false;
        });

        // Перезагружаем событие для обновления списка участников
        await _loadEvent();
      } else {
        final errorMessage = data['message'] as String? ?? 'Неизвестная ошибка';
        setState(() {
          _isTogglingParticipation = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _isTogglingParticipation = false;
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
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.getTextPrimaryColor(context),
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

    final name = _eventData!['name'] as String? ?? '';
    final organizerName = _eventData!['organizer_name'] as String? ?? '';
    final organizerAvatarUrl =
        _eventData!['organizer_avatar_url'] as String? ?? '';
    final dateFormattedShort = _eventData!['date_formatted_short'] as String? ?? '';
    // ─── Форматируем дату с добавлением года, если это не текущий год
    final dateFormatted = _formatDateWithYear(dateFormattedShort);
    final time = _eventData!['event_time'] as String? ?? '';
    // ─── Объединённая дата и время
    final dateTimeValue = dateFormatted.isEmpty
        ? '—'
        : time.isNotEmpty
        ? '$dateFormatted, $time'
        : dateFormatted;
    final place = _eventData!['place'] as String? ?? '';
    final photos = _eventData!['photos'] as List<dynamic>? ?? [];
    final participantsRaw = _eventData!['participants'] as List<dynamic>? ?? [];
    // ─── Сортируем участников: организатор первым
    final eventUserId = _eventData!['user_id'] as int?;
    final participants = List<dynamic>.from(participantsRaw)
      ..sort((a, b) {
        final aIsOrganizer =
            (a['user_id'] as int?) == eventUserId ||
            (a['is_organizer'] as bool?) == true;
        final bIsOrganizer =
            (b['user_id'] as int?) == eventUserId ||
            (b['is_organizer'] as bool?) == true;
        if (aIsOrganizer && !bIsOrganizer) return -1;
        if (!aIsOrganizer && bIsOrganizer) return 1;
        return 0;
      });

    // ─── Получаем аватар организатора: сначала из organizer_avatar_url,
    //      затем из профиля текущего пользователя (если он организатор),
    //      затем из списка участников (организатор всегда первый после сортировки)
    String? organizerAvatarFromParticipants;
    if (participants.isNotEmpty) {
      final firstParticipant = participants[0] as Map<String, dynamic>;
      final isFirstOrganizer = (firstParticipant['user_id'] as int?) ==
              eventUserId ||
          (firstParticipant['is_organizer'] as bool?) == true;
      if (isFirstOrganizer) {
        organizerAvatarFromParticipants =
            firstParticipant['avatar_url'] as String? ?? '';
      }
    }

    final finalOrganizerAvatar = organizerAvatarUrl.isNotEmpty
        ? organizerAvatarUrl
        : (_currentUserAvatar?.isNotEmpty ?? false)
        ? _currentUserAvatar!
        : (organizerAvatarFromParticipants?.isNotEmpty ?? false)
        ? organizerAvatarFromParticipants!
        : '';

    // ─── Извлекаем данные для метрик из базы данных (distance_from и distance_to)
    final distanceFromRaw = _eventData!['distance_from'];
    final distanceToRaw = _eventData!['distance_to'];
    num? distanceFrom;
    num? distanceTo;
    
    if (distanceFromRaw != null) {
      if (distanceFromRaw is num) {
        distanceFrom = distanceFromRaw;
      } else {
        distanceFrom = num.tryParse(distanceFromRaw.toString());
      }
      if (distanceFrom != null && distanceFrom <= 0) {
        distanceFrom = null;
      }
    }
    
    if (distanceToRaw != null) {
      if (distanceToRaw is num) {
        distanceTo = distanceToRaw;
      } else {
        distanceTo = num.tryParse(distanceToRaw.toString());
      }
      if (distanceTo != null && distanceTo <= 0) {
        distanceTo = null;
      }
    }

    // ─── Форматирование метрик на основе distance_from и distance_to
    String formatDistance(num? from, num? to) {
      if (from == null && to == null) return '';
      
      String formatMeters(num meters) {
        if (meters >= 1000) {
          final km = meters / 1000.0;
          if (km.truncateToDouble() == km) {
            return '${km.toInt()} км';
          } else {
            return '${km.toStringAsFixed(1)} км';
          }
        } else {
          return '${meters.toInt()} м';
        }
      }
      
      if (from != null && to != null) {
        return '${formatMeters(from)} - ${formatMeters(to)}';
      } else if (from != null) {
        return formatMeters(from);
      } else if (to != null) {
        return formatMeters(to);
      }
      return '';
    }

    // ─── Подготовка метрик с цветными тинтами
    final metrics = <_EventMetric>[];

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
                  // ───────── Верхний блок с метриками (на всю ширину)
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final screenW = MediaQuery.of(context).size.width;
                        final calculatedHeight =
                            screenW / 2.1; // Соотношение 2.1:1
                        return Container(
                          height: calculatedHeight,
                          decoration: BoxDecoration(
                            color: AppColors.getSurfaceColor(context),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              // ─── Фоновое изображение
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/coffeereun_fon.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),

                              // ─── Метрики поверх фона в нижней части
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: _EventMetricBlock(metrics: metrics),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: название события и организатор
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
                              name,
                              textAlign: TextAlign.left,
                              style: AppTextStyles.h17w6.copyWith(
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ClipOval(
                                  child: Builder(
                                    builder: (context) {
                                      if (finalOrganizerAvatar.isEmpty) {
                                        return Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.getBorderColor(
                                              context,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            size: 24,
                                            color:
                                                AppColors.getIconPrimaryColor(
                                                  context,
                                                ),
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
                                            (
                                              context,
                                              imageUrl,
                                              error,
                                            ) => Container(
                                              width: 40,
                                              height: 40,
                                              color: AppColors.getBorderColor(
                                                context,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                size: 20,
                                                color:
                                                    AppColors.getIconPrimaryColor(
                                                      context,
                                                    ),
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
                                      Text(
                                        'Организатор',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color:
                                              AppColors.getTextSecondaryColor(
                                                context,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        organizerName,
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: адрес
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
                              'Адрес',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.isNotEmpty ? place : '—',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                fontSize: 15,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: дата и дистанция
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          // Блок с датой
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
                                    'Дата',
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
                                    dateTimeValue,
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
                          // Блок с дистанцией
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
                                    'Дистанция',
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
                                    formatDistance(distanceFrom, distanceTo),
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

                  // ───────── Промежуточный блок: фотографии
                  if (photos.isNotEmpty)
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
                          child: Row(
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
                                            onTap: () => _openGallery(index),
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
                        ),
                      ),
                    ),

                  if (photos.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: участники
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
                              'Участники',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (participants.isEmpty)
                              Text(
                                '—',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(participants.length, (
                                  i,
                                ) {
                                  final p =
                                      participants[i] as Map<String, dynamic>;
                                  final avatarUrl =
                                      p['avatar_url'] as String? ?? '';
                                  return ClipOval(
                                    child: avatarUrl.isNotEmpty
                                        ? Builder(
                                            builder: (context) {
                                              final dpr = MediaQuery.of(
                                                context,
                                              ).devicePixelRatio;
                                              final w = (48 * dpr).round();
                                              return CachedNetworkImage(
                                                imageUrl: avatarUrl,
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                fadeInDuration:
                                                    const Duration(
                                                      milliseconds: 120,
                                                    ),
                                                memCacheWidth: w,
                                                maxWidthDiskCache: w,
                                                errorWidget:
                                                    (
                                                      context,
                                                      imageUrl,
                                                      error,
                                                    ) => Container(
                                                      width: 48,
                                                      height: 48,
                                                      color:
                                                          AppColors.getBorderColor(
                                                            context,
                                                          ),
                                                      child: Icon(
                                                        Icons.person,
                                                        size: 28,
                                                        color:
                                                            AppColors.getIconPrimaryColor(
                                                              context,
                                                            ),
                                                      ),
                                                    ),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.getBorderColor(
                                                    context,
                                                  ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              size: 28,
                                              color:
                                                  AppColors.getIconPrimaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: информация
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
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _eventData!['description'] as String? ?? '—',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                                fontSize: 15,
                                height: 1.35,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ───────── Кнопка "Присоединиться"/"Выйти"
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverToBoxAdapter(
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
                              padding: EdgeInsets.symmetric(
                                horizontal: _isParticipant ? 60 : 40,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _isParticipant
                                    ? AppColors.red
                                    : AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xxl,
                                ),
                              ),
                              child: _isTogglingParticipation
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
                                      _isParticipant
                                          ? 'Выйти'
                                          : 'Присоединиться',
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
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        if (_canEdit)
                          _CircleIconBtn(
                            icon: CupertinoIcons.pencil,
                            semantic: 'Редактировать',
                            onTap: _openEditScreen,
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
        color: AppColors.getBorderColor(context),
        child: Icon(
          Icons.person,
          size: 24,
          color: AppColors.getIconPrimaryColor(context),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                  color: AppColors.getBorderColor(context),
                  child: Icon(
                    Icons.image,
                    size: 48,
                    color: AppColors.getIconPrimaryColor(context),
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
                      errorWidget: (context, imageUrl, error) => Container(
                        color: AppColors.getBorderColor(context),
                        child: Icon(
                          Icons.image,
                          size: 48,
                          color: AppColors.getIconPrimaryColor(context),
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
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(
                      context,
                    ).withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.getSurfaceColor(context),
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

/// Контент участников события из API
class EventMembersContent extends StatelessWidget {
  final List<dynamic> participants;
  const EventMembersContent({super.key, required this.participants});

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Участники отсутствуют',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
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
              Divider(
                height: 1,
                thickness: 0.5,
                color: AppColors.getDividerColor(context),
              ),
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
                : Builder(
                    builder: (context) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.getBorderColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.getIconPrimaryColor(context),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // имя + роль
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) => Text(
                    member.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.getTextPrimaryColor(context),
                    ),
                  ),
                ),
                if (member.role != null) ...[
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) => Text(
                      member.role!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.getTextSecondaryColor(context),
                      ),
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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimaryColor(context),
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
