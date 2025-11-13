import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'create_club_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/transparent_route.dart';
import '../../../service/api_service.dart';

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

/// Возвращает маркеры для вкладки «Клубы».
/// Загружает данные через API и группирует клубы по локациям
Future<List<Map<String, dynamic>>> clubsMarkers(BuildContext context) async {
  try {
    final api = ApiService();

    // Загружаем маркеры с группировкой по локациям
    final data = await api.get(
      '/get_clubs.php',
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
  final VoidCallback? onClubCreated;

  const ClubsFloatingButtons({
    super.key,
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры клубов — скоро')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.group_add_outlined,
            label: 'Создать клуб',
            onTap: () async {
              final result = await Navigator.push(
                context,
                TransparentPageRoute(builder: (_) => const CreateClubScreen()),
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
