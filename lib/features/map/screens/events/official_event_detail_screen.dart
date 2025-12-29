// lib/screens/map/events/official_event_detail_screen.dart
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
import '../../../../core/widgets/transparent_route.dart';
import '../../../../core/widgets/more_menu_overlay.dart';
import '../../../../core/widgets/more_menu_hub.dart';
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
  final GlobalKey _menuKey =
      GlobalKey(); // Ключ для позиционирования попапа меню

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

    // Фоновая картинка для верхнего блока (соотношение сторон 2.1:1)
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
  }

  /// ──────────────────────── Показ меню с действиями ────────────────────────
  void _showMenu(BuildContext context) {
    final items = <MoreMenuItem>[];

    // ── Пункт "Редактировать" (только для создателя события)
    if (_canEdit) {
      items.add(
        MoreMenuItem(
          text: 'Редактировать',
          icon: CupertinoIcons.pencil,
          onTap: () async {
            MoreMenuHub.hide();
            // Переходим на экран редактирования события
            final result = await Navigator.of(context).push<dynamic>(
              TransparentPageRoute(
                builder: (_) =>
                    EditOfficialEventScreen(eventId: widget.eventId),
              ),
            );
            // Если редактирование прошло успешно, обновляем данные
            if (!context.mounted) return;
            // Если событие было удалено, возвращаемся назад
            if (result == 'deleted') {
              Navigator.of(context).pop(true);
              return;
            }
            // Если событие было обновлено, перезагружаем данные и возвращаем сигнал на карту
            if (result == true) {
              await _loadEvent();
              if (!context.mounted) return;
              // ── возвращаем сигнал об обновлении, чтобы карта обновила маркеры
              Navigator.of(context).pop('updated');
            }
          },
        ),
      );
    }

    // ── Пункт "Добавить в избранное / Убрать из избранного"
    items.add(
      MoreMenuItem(
        text: _isBookmarked ? 'Убрать из избранного' : 'Добавить в избранное',
        icon: _isBookmarked
            ? CupertinoIcons.bookmark_fill
            : CupertinoIcons.bookmark,
        iconColor: _isBookmarked ? AppColors.red : null,
        textStyle: _isBookmarked ? const TextStyle(color: AppColors.red) : null,
        onTap: () {
          MoreMenuHub.hide();
          _toggleBookmark();
        },
      ),
    );

    // Показываем попап меню
    MoreMenuOverlay(anchorKey: _menuKey, items: items).show(context);
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

    // ── Форматируем дату с добавлением года, если это не текущий год
    // ── Убираем запятую, если она есть (для официальных событий время не показываем)
    final dateFormattedRaw = _formatDateWithYear(dateFormattedShort);
    final dateFormatted = dateFormattedRaw
        .replaceAll(', ', ' ')
        .replaceAll(',', '');

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

    // ── Форматирование дистанций для отображения
    String formatDistances(List<num> dists) {
      if (dists.isEmpty) return '—';
      if (dists.length == 1) {
        final meters = dists[0].toDouble();
        if (meters >= 1000) {
          final km = meters / 1000;
          if (km == km.roundToDouble()) {
            return '${km.toInt()} км';
          } else {
            return '${km.toStringAsFixed(1).replaceAll('.', ',')} км';
          }
        } else {
          return '${meters.toInt()} м';
        }
      } else {
        // Если несколько дистанций, показываем их через точку
        return dists
            .map((d) {
              final meters = d.toDouble();
              if (meters >= 1000) {
                final km = meters / 1000;
                if (km == km.roundToDouble()) {
                  return '${km.toInt()} км';
                } else {
                  return '${km.toStringAsFixed(1).replaceAll('.', ',')} км';
                }
              } else {
                return '${meters.toInt()} м';
              }
            })
            .join('  ·  ');
      }
    }

    return InteractiveBackSwipe(
      child: Scaffold(
        backgroundColor: AppColors.getBackgroundColor(context),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              // ───────── Скроллируемый контент
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Закрываем попап меню при любом скролле или свайпе
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollStartNotification) {
                    MoreMenuHub.hide();
                  }
                  return false;
                },
                child: CustomScrollView(
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
                                child: backgroundUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: backgroundUrl,
                                        fit: BoxFit.cover,
                                        fadeInDuration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Builder(
                                              builder: (context) => Container(
                                                color: AppColors.getBorderColor(
                                                  context,
                                                ),
                                              ),
                                            ),
                                      )
                                    : Builder(
                                        builder: (context) => Container(
                                          color: AppColors.getBorderColor(
                                            context,
                                          ),
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

                  // ───────── Промежуточный блок: название события и ссылка
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
                            if (registrationLink.isNotEmpty) ...[
                              const SizedBox(height: 12),
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
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // ───────── Промежуточный блок: дата и адрес
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
                          // Блок с адресом
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
                                    'Адрес',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: AppColors.getTextSecondaryColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Text(
                                      place.isNotEmpty ? place : '—',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        color: AppColors.getTextPrimaryColor(
                                          context,
                                        ),
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

                  // ───────── Промежуточный блок: дистанция
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
                              'Дистанция',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.getTextSecondaryColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                formatDistances(distances),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  color: AppColors.getTextPrimaryColor(context),
                                ),
                              ),
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
                                fontSize: 14,
                                height: 1.4,
                                color: AppColors.getTextPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // ───────── Кнопка "Зарегистрироваться" (только если есть ссылка)
                  if (registrationLink.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverToBoxAdapter(
                        child: Material(
                          color: AppColors.brandPrimary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          elevation: 0,
                          child: InkWell(
                            onTap: () => _openEventLink(registrationLink),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: const Text(
                                'Зарегистрироваться',
                                textAlign: TextAlign.center,
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

                  if (registrationLink.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                ),
              ),

              // ───────── Плавающие круглые иконки (назад + действие)
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
                        Container(
                          key: _menuKey,
                          child: _CircleIconBtn(
                            icon: CupertinoIcons.ellipsis_vertical,
                            semantic: 'Меню',
                            onTap: () => _showMenu(context),
                          ),
                        ),
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
  final VoidCallback? onTap;
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    // Цвет иконки светлый
    final iconColor = AppColors.getSurfaceColor(context);

    // Цвет фона темный с прозрачностью
    final backgroundColor = AppColors.getTextPrimaryColor(
      context,
    ).withValues(alpha: 0.5);

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
