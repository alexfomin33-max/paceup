import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'create_club_screen.dart';
import 'clubs_filters_bottom_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/transparent_route.dart';
import '../../../../providers/services/api_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Склоняет название города в предложный падеж для фразы "Клубы в/во [город]"
/// Возвращает строку с правильным предлогом и склонённым названием города
String _formatCityInLocativeCase(String cityName) {
  if (cityName.isEmpty) return cityName;

  final trimmed = cityName.trim();

  // Определяем предлог: "во" для городов, начинающихся с гласных или трудных сочетаний согласных
  final vowels = ['а', 'о', 'у', 'э', 'ю', 'я'];
  final firstTwo = trimmed.toLowerCase().length >= 2
      ? trimmed.toLowerCase().substring(0, 2)
      : '';
  final firstLetter = trimmed.toLowerCase().substring(0, 1);

  // "во" используется для: гласных, сочетаний вл-, вс-, вм-, вн-, фл-, сл- и т.д.
  final difficultConsonants = ['вл', 'вс', 'вм', 'вн', 'фл', 'сл'];
  final useVo =
      vowels.contains(firstLetter) || (difficultConsonants.contains(firstTwo));
  final preposition = useVo ? 'во' : 'в';

  // Словарь исключений для правильного склонения
  final exceptions = <String, String>{
    'Москва': 'Москве',
    'Санкт-Петербург': 'Санкт-Петербурге',
    'Владимир': 'Владимире',
    'Суздаль': 'Суздале',
    'Ярославль': 'Ярославле',
    'Нижний Новгород': 'Нижнем Новгороде',
    'Иваново': 'Иваново',
    'Казань': 'Казани',
    'Рязань': 'Рязани',
    'Тула': 'Туле',
    'Тверь': 'Твери',
    'Орёл': 'Орле',
    'Кострома': 'Костроме',
    'Воронеж': 'Воронеже',
    'Ростов': 'Ростове',
    'Краснодар': 'Краснодаре',
    'Сочи': 'Сочи',
    'Новосибирск': 'Новосибирске',
    'Екатеринбург': 'Екатеринбурге',
    'Челябинск': 'Челябинске',
    'Пермь': 'Перми',
    'Самара': 'Самаре',
    'Уфа': 'Уфе',
    'Омск': 'Омске',
    'Красноярск': 'Красноярске',
    'Владивосток': 'Владивостоке',
    'Хабаровск': 'Хабаровске',
  };

  // Проверяем, есть ли точное совпадение в словаре
  final declinedCity = exceptions[trimmed] ?? _declineCityName(trimmed);

  return '$preposition $declinedCity';
}

/// Склоняет название города по общим правилам (если нет исключения)
String _declineCityName(String cityName) {
  // Города на -а/-я → -е/-е (Казань → Казани, но есть исключения выше)
  if (cityName.endsWith('а') && !cityName.endsWith('ь')) {
    return '${cityName.substring(0, cityName.length - 1)}е';
  }
  if (cityName.endsWith('я')) {
    return '${cityName.substring(0, cityName.length - 1)}е';
  }

  // Города на -ск/-цк → -ске/-цке
  if (cityName.endsWith('ск')) {
    return '$cityNameе';
  }
  if (cityName.endsWith('цк')) {
    return '$cityNameе';
  }

  // Города на -ль/-нь → -ле/-не
  if (cityName.endsWith('ль')) {
    return '${cityName.substring(0, cityName.length - 2)}ле';
  }
  if (cityName.endsWith('нь')) {
    return '${cityName.substring(0, cityName.length - 2)}не';
  }

  // Города на -ь → заменяем на -и
  if (cityName.endsWith('ь')) {
    return '${cityName.substring(0, cityName.length - 1)}и';
  }

  // Города на -о/-е → -е/-е
  if (cityName.endsWith('о') || cityName.endsWith('е')) {
    return cityName;
  }

  // По умолчанию добавляем -е
  if (!cityName.endsWith('е') && !cityName.endsWith('и')) {
    return '$cityNameе';
  }

  return cityName;
}

/// Возвращает маркеры для вкладки «Клубы».
/// Загружает данные через API и группирует клубы по локациям
///
/// [filterParams] - параметры фильтра (опционально)
Future<List<Map<String, dynamic>>> clubsMarkers(
  BuildContext context, {
  ClubsFilterParams? filterParams,
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

    // Добавляем фильтры по типам клубов
    if (filterParams != null && filterParams.clubTypes.isNotEmpty) {
      final clubTypes = filterParams.clubTypes.map((t) => t.apiValue).toList();
      queryParams['club_types'] = clubTypes.join(',');
    }

    // Загружаем маркеры с группировкой по локациям
    final data = await api.get('/get_clubs.php', queryParams: queryParams);

    if (data['success'] != true) {
      return [];
    }

    final markers = data['markers'] as List<dynamic>? ?? [];

    return markers.map<Map<String, dynamic>>((marker) {
      final lat = (marker['latitude'] as num).toDouble();
      final lng = (marker['longitude'] as num).toDouble();
      final count = marker['count'] as int? ?? 0;
      final city = marker['city'] as String? ?? '';
      final clubs = marker['clubs'] as List<dynamic>? ?? [];

      // Формируем заголовок для bottom sheet (только название города с правильным склонением)
      String title = 'Клубы';
      if (city.isNotEmpty) {
        final cityDeclined = _formatCityInLocativeCase(city);
        title = 'Клубы $cityDeclined';
      }

      return {
        'point': LatLng(lat, lng),
        'title': title,
        'count': count,
        'clubs': clubs,
        'latitude': lat,
        'longitude': lng,
      };
    }).toList();
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    debugPrint('Ошибка загрузки клубов: $e');
    return [];
  }
}

// === Нижние кнопки для вкладки «Клубы» ===
class ClubsFloatingButtons extends StatelessWidget {
  /// Callback для применения фильтров
  final Function(ClubsFilterParams)? onApplyFilters;

  /// Текущие параметры фильтра (для восстановления состояния)
  final ClubsFilterParams? currentFilterParams;

  /// Callback для обновления данных после создания клуба
  final VoidCallback? onClubCreated;

  const ClubsFloatingButtons({
    super.key,
    this.onApplyFilters,
    this.currentFilterParams,
    this.onClubCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: kBottomNavigationBarHeight - 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SolidPillButton(
            icon: Icons.tune,
            label: 'Фильтры',
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ClubsFiltersBottomSheet(
                  initialParams: currentFilterParams,
                  onApplyFilters: (params) {
                    // Вызываем callback для применения фильтров
                    onApplyFilters?.call(params);
                  },
                ),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.group_add_outlined,
            label: 'Создать клуб',
            onTap: () async {
              final result = await Navigator.of(
                context,
                rootNavigator: true,
              ).push(
                TransparentPageRoute(
                  builder: (_) => const CreateClubScreen(),
                ),
              );
              // Если клуб был создан, вызываем callback для обновления данных на карте
              if (result == 'created' && context.mounted) {
                onClubCreated?.call();
              }
            },
          ),
        ],
      ),
    );
  }
}

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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
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
