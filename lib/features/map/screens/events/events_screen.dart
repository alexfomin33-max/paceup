import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'add_event_screen.dart';
import 'add_official_event_screen.dart';
import 'events_filters_bottom_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../providers/services/api_provider.dart';
import '../../../../providers/services/auth_provider.dart';


/// Возвращает маркеры для вкладки «События».
/// Загружает данные через API и группирует события по локациям
///
/// [filterParams] - параметры фильтра (опционально)
Future<List<Map<String, dynamic>>> eventsMarkers(
  BuildContext context, {
  EventsFilterParams? filterParams,
}) async {
  try {
    final container = ProviderScope.containerOf(context);
    final api = container.read(apiServiceProvider);

    // Формируем параметры запроса
    final queryParams = <String, String>{'detail': 'false'};

    // Добавляем фильтры по видам спорта
    if (filterParams != null && filterParams.sports.isNotEmpty) {
      final sports = filterParams.sports.map((s) => s.apiValue).toList();
      queryParams['activities'] = sports.join(',');
    }

    // Добавляем фильтры по типам событий
    if (filterParams != null && filterParams.eventTypes.isNotEmpty) {
      final eventTypes = filterParams.eventTypes
          .map((t) => t.apiValue)
          .toList();
      queryParams['event_types'] = eventTypes.join(',');
    }

    // Добавляем фильтры по датам
    // По умолчанию показываем события начиная с сегодняшней даты
    final today = DateTime.now();
    final defaultStartDate = DateTime(today.year, today.month, today.day);

    if (filterParams != null && filterParams.startDate != null) {
      // Если фильтры установлены, используем дату из фильтров
      queryParams['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(filterParams.startDate!);
    } else {
      // Если фильтры не установлены, используем дефолтную дату (сегодня)
      queryParams['start_date'] = DateFormat(
        'yyyy-MM-dd',
      ).format(defaultStartDate);
    }

    // Дата окончания передаем только если она явно установлена пользователем
    if (filterParams != null && filterParams.endDate != null) {
      final defaultEndDate = DateTime(today.year + 1, today.month, today.day);
      // Передаем дату окончания только если она отличается от дефолтной
      if (filterParams.endDate != defaultEndDate) {
        queryParams['end_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(filterParams.endDate!);
      }
    }

    // Загружаем маркеры с группировкой по локациям
    final data = await api.get('/get_events.php', queryParams: queryParams);

    if (data['success'] != true) {
      return [];
    }

    final markers = data['markers'] as List<dynamic>? ?? [];

    return markers.map<Map<String, dynamic>>((marker) {
      final lat = (marker['latitude'] as num).toDouble();
      final lng = (marker['longitude'] as num).toDouble();
      final count = marker['count'] as int? ?? 0;
      final events = marker['events'] as List<dynamic>? ?? [];

      // ────────────────────────────────────────────────────────────────
      // Проверяем, есть ли в маркере официальные события
      // Событие считается официальным, если event_type == 'official'
      // или registration_link не пустой
      // ────────────────────────────────────────────────────────────────
      bool hasOfficialEvent = false;
      for (final event in events) {
        if (event is Map<String, dynamic>) {
          final eventType = event['event_type'] as String? ?? 'amateur';
          final registrationLink = event['registration_link'] as String? ??
              event['event_link'] as String? ??
              '';
          if (eventType == 'official' || registrationLink.isNotEmpty) {
            hasOfficialEvent = true;
            break;
          }
        }
      }

      // Заголовок для bottom sheet всегда "Предстоящие события"
      const String title = 'Предстоящие события';

      return {
        'point': LatLng(lat, lng),
        'title': title,
        'count': count,
        'events': events,
        'latitude': lat,
        'longitude': lng,
        'is_official': hasOfficialEvent, // Флаг наличия официальных событий
      };
    }).toList();
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    return [];
  }
}

/// ——— Кнопки снизу для вкладки «События» ———
class EventsFloatingButtons extends ConsumerWidget {
  /// Callback для применения фильтров
  final Function(EventsFilterParams)? onApplyFilters;

  /// Текущие параметры фильтра (для восстановления состояния)
  final EventsFilterParams? currentFilterParams;

  /// Callback для обновления данных после создания события
  final VoidCallback? onEventCreated;

  const EventsFloatingButtons({
    super.key,
    this.onApplyFilters,
    this.currentFilterParams,
    this.onEventCreated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем ID текущего пользователя
    final userIdAsync = ref.watch(currentUserIdProvider);

    return Positioned(
      left: 12,
      right: 12,
      bottom: kBottomNavigationBarHeight - 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _SolidPillButton(
            icon: Icons.tune,
            label: 'Фильтры',
            onTap: () {
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => EventsFiltersBottomSheet(
                  onApplyFilters: onApplyFilters,
                  initialParams: currentFilterParams,
                ),
              );
            },
          ),
          // Правая сторона: кнопка "Платные" (если ID=1, 16 или 17) и кнопка "Добавить"
          userIdAsync.when(
            data: (userId) {
              // Если ID пользователя равен 1, 16 или 17, показываем обе кнопки в Column
              if (userId == 1 || userId == 16 || userId == 17) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SolidPillButton(
                      icon: Icons.attach_money,
                      label: 'Платные',
                      onTap: () async {
                        final result = await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push(
                          TransparentPageRoute(
                            builder: (_) => const AddOfficialEventScreen(),
                          ),
                        );
                        // Если событие было создано, вызываем callback для обновления данных на карте
                        if (result == 'created' && context.mounted) {
                          onEventCreated?.call();
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _SolidPillButton(
                      icon: Icons.add_circle_outline,
                      label: 'Добавить',
                      onTap: () async {
                        final result = await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push(
                          TransparentPageRoute(
                            builder: (_) => const AddEventScreen(),
                          ),
                        );
                        // Если событие было создано, вызываем callback для обновления данных на карте
                        if (result == 'created' && context.mounted) {
                          onEventCreated?.call();
                        }
                      },
                    ),
                  ],
                );
              } else {
                // Если ID не равен 1, 16 или 17, показываем только кнопку "Добавить"
                return _SolidPillButton(
                  icon: Icons.add_circle_outline,
                  label: 'Добавить',
                  onTap: () async {
                    final result = await Navigator.of(
                      context,
                      rootNavigator: true,
                    ).push(
                      TransparentPageRoute(
                        builder: (_) => const AddEventScreen(),
                      ),
                    );
                    // Если событие было создано, вызываем callback для обновления данных на карте
                    if (result == 'created' && context.mounted) {
                      onEventCreated?.call();
                    }
                  },
                );
              }
            },
            loading: () => _SolidPillButton(
              icon: Icons.add_circle_outline,
              label: 'Добавить',
              onTap: () async {
                final result = await Navigator.of(
                  context,
                  rootNavigator: true,
                ).push(
                  TransparentPageRoute(
                    builder: (_) => const AddEventScreen(),
                  ),
                );
                // Если событие было создано, вызываем callback для обновления данных на карте
                if (result == 'created' && context.mounted) {
                  onEventCreated?.call();
                }
              },
            ),
            error: (error, stackTrace) => _SolidPillButton(
              icon: Icons.add_circle_outline,
              label: 'Добавить',
              onTap: () async {
                final result = await Navigator.of(
                  context,
                  rootNavigator: true,
                ).push(
                  TransparentPageRoute(
                    builder: (_) => const AddEventScreen(),
                  ),
                );
                // Если событие было создано, вызываем callback для обновления данных на карте
                if (result == 'created' && context.mounted) {
                  onEventCreated?.call();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Локальная «таблетка»
class _SolidPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SolidPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ── определяем цвета в зависимости от темы
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    // ── в темной теме убираем тень, чтобы фон был идентичен нижнему меню
    final shadowColor = isDark ? null : AppColors.shadowMedium;

    return Material(
      color: AppColors.getSurfaceColor(context),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: shadowColor != null
                ? [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppColors.getIconPrimaryColor(context),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.h14w4.copyWith(
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
