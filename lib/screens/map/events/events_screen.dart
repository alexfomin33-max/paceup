import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../theme/app_theme.dart';
import 'coffeerun/coffeerun_screen.dart';
import 'addevent_screen.dart';

/// Возвращает маркеры для вкладки «События».
List<Map<String, dynamic>> eventsMarkers(BuildContext context) {
  return [
    {
      'point': const LatLng(56.129057, 40.406635),
      'title': 'События во Владимире',
      'count': 2,
      'content': const _VladimirEvents(),
    },
    {
      'point': const LatLng(55.755864, 37.617698),
      'title': 'События в Москве',
      'count': 5,
      'content': const _SimpleText('Москва: подборка событий скоро здесь'),
    },
  ];
}

class _VladimirEvents extends StatelessWidget {
  const _VladimirEvents();

  @override
  Widget build(BuildContext context) {
    // Универсальная строка карточки. Если есть onTap — делаем кликабельной.
    Widget cardRow({
      required String asset,
      required String title,
      required String subtitle,
      VoidCallback? onTap,
    }) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(asset, width: 90, height: 60, fit: BoxFit.cover),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      );

      if (onTap == null) return row;

      // Чтобы у InkWell был нормальный splash — даём ему Material
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: row,
        ),
      );
    }

    return Padding(
      // ⬅️ Отступы карточек от краёв экрана
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 50),
      child: Column(
        children: [
          // Карточка 1 — кликабельная → открывает «Субботний коферан»
          cardRow(
            asset: 'assets/Vlad_event_1.png',
            title: 'Субботний коферан',
            subtitle: '14 июня 2025  ·  Участников: 32',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CoffeerunScreen()),
              );
            },
          ),

          const SizedBox(height: 8),
          // ⬇️ Разделительная линия между карточками
          const Divider(height: 1, thickness: 0.5, color: AppColors.border),
          const SizedBox(height: 8),

          // Карточка 2
          cardRow(
            asset: 'assets/Vlad_event_2.png',
            title: 'Владимирский полумарафон «Золотые ворота»',
            subtitle: '31 августа 2025  ·  Участников: 1426',
          ),
        ],
      ),
    );
  }
}

class _SimpleText extends StatelessWidget {
  final String text;
  const _SimpleText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: AppColors.text),
    );
  }
}

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
              // TODO: открыть экран/шит фильтров
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Фильтры скоро будут')),
              );
            },
          ),
          _SolidPillButton(
            icon: Icons.add_circle_outline,
            label: 'Добавить',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEventScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Локальная копия кнопки-«таблетки» (как было в map_screen.dart)
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
