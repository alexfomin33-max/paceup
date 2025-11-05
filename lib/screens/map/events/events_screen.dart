import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'add_event_screen.dart';
import 'events_filters_bottom_sheet.dart';
import '../../../../../theme/app_theme.dart';
import '../../../widgets/transparent_route.dart';
import '../../../service/api_service.dart';

/// Склоняет название города в предложный падеж для фразы "События в/во [город]"
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
    return cityName.substring(0, cityName.length - 1) + 'е';
  }
  if (cityName.endsWith('я')) {
    return cityName.substring(0, cityName.length - 1) + 'е';
  }

  // Города на -ск/-цк → -ске/-цке
  if (cityName.endsWith('ск')) {
    return cityName + 'е';
  }
  if (cityName.endsWith('цк')) {
    return cityName + 'е';
  }

  // Города на -ль/-нь → -ле/-не
  if (cityName.endsWith('ль')) {
    return cityName.substring(0, cityName.length - 2) + 'ле';
  }
  if (cityName.endsWith('нь')) {
    return cityName.substring(0, cityName.length - 2) + 'не';
  }

  // Города на -ь → заменяем на -и
  if (cityName.endsWith('ь')) {
    return cityName.substring(0, cityName.length - 1) + 'и';
  }

  // Города на -о/-е → -е/-е
  if (cityName.endsWith('о') || cityName.endsWith('е')) {
    return cityName;
  }

  // По умолчанию добавляем -е
  if (!cityName.endsWith('е') && !cityName.endsWith('и')) {
    return cityName + 'е';
  }

  return cityName;
}

/// Возвращает маркеры для вкладки «События».
/// Загружает данные через API и группирует события по локациям
Future<List<Map<String, dynamic>>> eventsMarkers(BuildContext context) async {
  try {
    final api = ApiService();

    // Загружаем маркеры с группировкой по локациям
    final data = await api.get(
      '/get_events.php',
      queryParams: {'detail': 'false'},
    );

    if (data['success'] != true) {
      return [];
    }

    final markers = data['markers'] as List<dynamic>? ?? [];

    return markers.map<Map<String, dynamic>>((marker) {
      final lat = (marker['latitude'] as num).toDouble();
      final lng = (marker['longitude'] as num).toDouble();
      final count = marker['count'] as int? ?? 0;
      final place = marker['place'] as String? ?? '';
      final events = marker['events'] as List<dynamic>? ?? [];

      // Формируем заголовок для bottom sheet (только название города с правильным склонением)
      String title = 'События';
      if (place.isNotEmpty) {
        // Извлекаем только название города (последняя часть после запятой)
        final parts = place.split(',');
        final cityName = parts.isNotEmpty ? parts.last.trim() : place;
        final cityDeclined = _formatCityInLocativeCase(cityName);
        title = 'События $cityDeclined';
      }

      return {
        'point': LatLng(lat, lng),
        'title': title,
        'count': count,
        'events': events,
        'latitude': lat,
        'longitude': lng,
      };
    }).toList();
  } catch (e) {
    // В случае ошибки возвращаем пустой список
    return [];
  }
}

/// ——— Кнопки снизу для вкладки «События» (оставляем как было) ———
class EventsFloatingButtons extends StatelessWidget {
  const EventsFloatingButtons({super.key});

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
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const EventsFiltersBottomSheet(),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.add_circle_outline,
            label: 'Добавить',
            onTap: () {
              Navigator.push(
                context,
                TransparentPageRoute(builder: (_) => const AddEventScreen()),
              );
            },
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
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.iconPrimary),
              const SizedBox(width: 8),
              Text(label, style: AppTextStyles.h14w4),
            ],
          ),
        ),
      ),
    );
  }
}
